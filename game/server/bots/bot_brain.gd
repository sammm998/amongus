class_name BotBrain
extends RefCounted
## Server-side bot. Receives exactly the messages a human in the same seat would
## (MATCH_INFO, ROLE, TASKS, SNAPSHOT, EVENT, ...) and only "sees" other players
## through line-of-sight checks from its own eyes. It never reads other players'
## roles from the server. Output: one PlayerInput per tick + ordinary actions.

var match_ref: WeakRef
var id := 0
var cfg: Dictionary
var rng := RandomNumberGenerator.new()

# Knowledge (only from messages).
var phase := "WAITING"
var role := ""
var allies: Array = []
var tasks: Array = []
var panel: Dictionary = {}
var world: Dictionary = {}
var meeting: Dictionary = {}
var snapshot: Dictionary = {}
var me: Dictionary = {}
var names: Dictionary = {}
var suspicion: Dictionary = {}
var last_hurt_time := -100.0
var last_hurt_dir := Vector3.ZERO
var seen_shooting: Dictionary = {}

# Behaviour state.
var yaw := 0.0
var pitch := 0.0
var goal_kind := ""
var goal_pos := Vector3.ZERO
var goal_ref: Variant = null
var path := PackedVector3Array()
var path_i := 0
var target_id := -1
var target_since := 0.0
var kill_ready_at := 0.0
var linger := 0.0
var stuck_timer := 0.0
var last_pos := Vector3.ZERO
var stuck_count := 0
var vote_delay := 0.0
var voted_phase := ""
var said_phase := ""
var smooth_timer := 0.0
var sidestep := 0.0
var sidestep_dir := 1.0


func _init(match_server: MatchServer, player_id: int) -> void:
	match_ref = weakref(match_server)
	id = player_id
	cfg = GameData.table("bots")
	rng.seed = player_id * 7919 + int(Time.get_ticks_usec() % 100000)
	var k: Array = cfg["traitor_kill_cooldown_seconds"]
	kill_ready_at = rng.randf_range(float(k[0]), float(k[1]))


func _m() -> MatchServer:
	return match_ref.get_ref()


# ------------------------------------------------------------ messages ---

func receive(type: int, p: Dictionary) -> void:
	match type:
		Protocol.Msg.MATCH_INFO:
			phase = p["phase"]
			for e: Dictionary in p["players"]:
				names[e["id"]] = e["name"]
		Protocol.Msg.ROLE:
			goal_kind = ""
			role = p["role"]
			allies = p["allies"].map(func(a: Dictionary) -> int: return a["id"])
		Protocol.Msg.TASKS:
			tasks = p["tasks"]
			if goal_kind == "task":
				goal_kind = ""
		Protocol.Msg.SABOTAGE_PANEL:
			panel = p["panel"]
		Protocol.Msg.WORLD:
			world = p
			for s: Array in p["suspects"]:
				_suspect(int(s[0]), 0.02)
		Protocol.Msg.SNAPSHOT:
			snapshot = p
			me = p["me"]
		Protocol.Msg.EVENT:
			_on_event(p["kind"], p["data"])
		Protocol.Msg.MEETING:
			meeting = p
			if p["phase"] != voted_phase:
				vote_delay = rng.randf_range(0.8, 3.5)
		Protocol.Msg.MEETING_RESULT:
			meeting = {}
			goal_kind = ""
			target_id = -1
		Protocol.Msg.CHAT_MSG:
			for pid: int in names:
				if pid != id and p["from"] != id and String(p["text"]).contains(names[pid]):
					_suspect(pid, 0.3)


func _on_event(kind: String, data: Dictionary) -> void:
	var now := _m().now
	match kind:
		"shot":
			var shooter: int = data["shooter"]
			if shooter > 0 and shooter != id and not shooter in allies:
				var origin: Vector3 = data["origin"]
				if _sees_point(origin):
					seen_shooting[shooter] = now
					_suspect(shooter, 0.6)
		"hurt":
			last_hurt_time = now
			last_hurt_dir = data["dir"]
		"downed", "eliminated", "revived":
			goal_kind = ""
			target_id = -1


func _suspect(pid: int, amount: float) -> void:
	if pid == id or pid in allies:
		return
	suspicion[pid] = float(suspicion.get(pid, 0.0)) + amount


# --------------------------------------------------------------- think ---

func think(dt: float) -> PlayerInput:
	var inp := PlayerInput.new()
	var m := _m()
	if m == null or me.is_empty():
		inp.yaw = yaw
		return inp
	if phase == "INCIDENT_MEETING":
		_meeting_behaviour(dt)
	if phase in ["ROLE_REVEAL", "INCIDENT_MEETING", "MATCH_END", "RESULTS"] or me.get("spectator", false):
		inp.yaw = yaw
		return inp
	var my_pos: Vector3 = me["pos"]
	if int(me["state"]) != Vitals.State.ALIVE:
		inp.yaw = yaw
		return inp
	var now := m.now
	var visible := _visible_players()
	var playing := phase == "ACTIVE" or phase == "RESUMING"

	# 1. Fight: react to being shot, or hunt as a traitor.
	var fight := -1
	if playing:
		fight = _choose_fight_target(visible, now)
	if fight > 0:
		return _fight(inp, fight, visible, dt)

	# 2. Pick a goal if we have none.
	if playing:
		_choose_goal(visible, now)
		if role == "traitor":
			_maybe_sabotage(dt, now)
	elif goal_kind.is_empty():
		_set_goal("wander", _random_waypoint(), null)

	# 3. Move toward the goal, interact when there.
	var dist := Vector2(goal_pos.x - my_pos.x, goal_pos.z - my_pos.z).length()
	var arrive := 1.4 if goal_kind in ["task", "report", "repair", "loot"] else float(cfg["waypoint_reach_m"]) + 1.0
	if dist <= arrive:
		_face(goal_pos, dt, 6.0)
		if goal_kind in ["task", "report", "repair", "loot"]:
			var prompt: Dictionary = me.get("prompt", {})
			if not prompt.is_empty():
				inp.buttons |= PlayerInput.INTERACT
				linger = rng.randf_range(0.2, 0.8)
			else:
				linger -= dt
				if linger <= 0.0:
					goal_kind = ""
		else:
			linger -= dt
			if linger <= 0.0:
				goal_kind = ""
	else:
		_follow_path(inp, my_pos, dt)
	_pick_weapon(inp)
	inp.yaw = yaw
	inp.pitch = pitch
	return inp


func _set_goal(kind: String, pos: Vector3, ref: Variant) -> void:
	goal_kind = kind
	goal_pos = pos
	goal_ref = ref
	path = _plan(pos)
	path_i = 0
	stuck_timer = 0.0
	stuck_count = 0
	var l: Array = cfg["task_linger_seconds"]
	linger = rng.randf_range(float(l[0]), float(l[1]))


func _choose_goal(visible: Array, now: float) -> void:
	var m := _m()
	var my_pos: Vector3 = me["pos"]
	# Critical sabotage: agents rush to the generators.
	if role == "agent" and not bool(world.get("power", true)):
		var gens: Array = world.get("generators", [])
		var best := ""
		var best_d := INF
		for g: Array in gens:
			if not g[1]:
				var d := my_pos.distance_to(m.map.station_pos(g[0]))
				if d < best_d:
					best_d = d
					best = g[0]
		if not best.is_empty() and (goal_kind != "repair" or goal_ref != best):
			_set_goal("repair", m.map.station_pos(best), best)
			return
	# Bodies: agents always report; traitors sometimes self-report.
	if goal_kind != "report":
		for b: Dictionary in _visible_bodies():
			if role == "agent" or rng.randf() < 0.25:
				_set_goal("report", b["pos"], b["id"])
				for v: Dictionary in visible:
					if v["pos"].distance_to(b["pos"]) < 15.0:
						_suspect(v["id"], 1.0)
				return
	if not goal_kind.is_empty():
		return
	# Blackout repairs for agents in the dark.
	if role == "agent":
		for s: Dictionary in world.get("sabotages", []):
			if s["kind"] == "blackout" and m.map.stations.has("breaker_" + s["district"]) and rng.randf() < 0.5:
				_set_goal("repair", m.map.station_pos("breaker_" + s["district"]), s["kind"])
				return
	# Opportunistic loot pickup while only carrying a pistol.
	var inv: Dictionary = me.get("inv", {})
	var ws: Array = inv.get("weapons", [])
	if ws.size() > 0 and ws[0].is_empty():
		for l: Array in snapshot.get("loot", []):
			if l[1] in ["assault_rifle", "shotgun"] and (l[3] as Vector3).distance_to(my_pos) < 30.0:
				_set_goal("loot", l[3], l[0])
				return
	# Next task (fake for traitors — same behaviour).
	for t: Dictionary in tasks:
		if not t["done"]:
			_set_goal("task", m.map.station_pos(t["station"]), t["id"])
			return
	_set_goal("wander", _random_waypoint(), null)


func _choose_fight_target(visible: Array, now: float) -> int:
	# Keep fighting the current target for a while.
	if target_id > 0:
		var still := visible.filter(func(v: Dictionary) -> bool: return v["id"] == target_id and v["state"] == Vitals.State.ALIVE)
		if not still.is_empty() and now - target_since < float(cfg["chase_give_up_seconds"]):
			return target_id
		target_id = -1
	# Shot at recently: fire back at a visible player in that direction (not always).
	if now - last_hurt_time < 2.5 and (role == "traitor" or rng.randf() < float(cfg["retaliate_chance_per_tick"])):
		var my_pos: Vector3 = me["pos"]
		var best := -1
		var best_dot := 0.6
		for v: Dictionary in visible:
			if v["state"] != Vitals.State.ALIVE or v["id"] in allies:
				continue
			var d: float = (v["pos"] - my_pos).normalized().dot(last_hurt_dir)
			if d > best_dot:
				best_dot = d
				best = v["id"]
		if best > 0:
			_suspect(best, 2.5)
			target_id = best
			target_since = now
			return best
	# Traitor hunting an isolated agent.
	if role == "traitor" and now >= kill_ready_at and _m().phases.elapsed > 20.0:
		var iso := float(cfg["traitor_isolation_radius_m"])
		for v: Dictionary in visible:
			if v["id"] in allies or v["state"] != Vitals.State.ALIVE:
				continue
			if v["pos"].distance_to(me["pos"]) > 30.0:
				continue
			var witnesses := visible.filter(func(o: Dictionary) -> bool:
				return o["id"] != v["id"] and not o["id"] in allies and o["state"] == Vitals.State.ALIVE and o["pos"].distance_to(v["pos"]) < iso)
			if witnesses.is_empty():
				target_id = v["id"]
				target_since = now
				var k: Array = cfg["traitor_kill_cooldown_seconds"]
				kill_ready_at = now + rng.randf_range(float(k[0]), float(k[1]))
				return target_id
	return -1


func _fight(inp: PlayerInput, tid: int, visible: Array, dt: float) -> PlayerInput:
	var t: Dictionary = {}
	for v: Dictionary in visible:
		if v["id"] == tid:
			t = v
	if t.is_empty():
		target_id = -1
		inp.yaw = yaw
		return inp
	var my_pos: Vector3 = me["pos"]
	var chest: Vector3 = t["pos"] + Vector3(0, 1.1 if t["state"] == Vitals.State.ALIVE else 0.3, 0)
	var eye := my_pos + Vector3(0, 1.45, 0)
	var err := deg_to_rad(float(cfg["aim_error_degrees"]))
	var dir := (chest - eye).normalized()
	dir = dir.rotated(Vector3.UP, rng.randf_range(-err, err)).normalized()
	var aim := eye + dir * eye.distance_to(chest)
	_face(chest, dt, 9.0)
	var dist := my_pos.distance_to(t["pos"])
	var engage := float(cfg["engage_range_m"])
	if dist > engage * 0.6:
		inp.move = Vector2(rng.randf_range(-0.3, 0.3), 1.0)
	else:
		inp.move = Vector2(sin(_m().now * 1.7 + id) * 0.8, 0.0)
	var facing := Vector3(-sin(yaw), 0, -cos(yaw)).dot(Vector3(dir.x, 0, dir.z).normalized())
	if dist <= engage and facing > 0.9:
		inp.buttons |= PlayerInput.FIRE
		if dist > 12.0:
			inp.buttons |= PlayerInput.AIM
	inp.aim_point = aim
	inp.view_time = _m().now
	_pick_weapon(inp)
	inp.yaw = yaw
	inp.pitch = pitch
	# Traitors leave downed victims most of the time; sometimes they finish.
	if t["state"] == Vitals.State.DOWNED and role == "traitor":
		if rng.randf() > float(cfg["traitor_finish_chance"]) * dt * 3.0:
			inp.buttons &= ~PlayerInput.FIRE
		if rng.randf() < dt:
			target_id = -1
			_set_goal("task", _random_waypoint(), null)
	elif t["state"] != Vitals.State.ALIVE and role != "traitor":
		target_id = -1
		inp.buttons &= ~PlayerInput.FIRE
	return inp


func _maybe_sabotage(dt: float, now: float) -> void:
	if panel.is_empty() or float(panel.get("team_ready_in", 1.0)) > 0.0 or float(panel.get("grace_left", 1.0)) > 0.0:
		return
	if rng.randf() > float(cfg["traitor_sabotage_chance_per_second"]) * dt:
		return
	var kinds: Dictionary = panel["kinds"]
	var options: Array = []
	for k: String in kinds:
		if float(kinds[k]["ready_in"]) <= 0.0:
			options.append(k)
	if options.is_empty():
		return
	var kind: String = options[rng.randi_range(0, options.size() - 1)]
	if kind == "power_failure" and rng.randf() < 0.5:
		return
	var district := ""
	if kinds[kind]["targets"] == "district":
		var ds: Array = panel.get("districts", [])
		district = ds[rng.randi_range(0, ds.size() - 1)] if not ds.is_empty() else ""
	_act("sabotage", 0, "%s|%s" % [kind, district])


func _meeting_behaviour(dt: float) -> void:
	if meeting.is_empty() or not id in meeting.get("participants", []):
		return
	var p: String = meeting["phase"]
	if p == "DISCUSSION" and said_phase != _meeting_key():
		said_phase = _meeting_key()
		if rng.randf() < 0.6:
			_act("chat", 0, _discussion_line())
	if not p in ["REVIVE_VOTE", "SUSPECT_VOTE"] or voted_phase == _meeting_key() + p:
		return
	vote_delay -= dt
	if vote_delay > 0.0:
		return
	voted_phase = _meeting_key() + p
	var victim: int = meeting["victim"]
	if p == "REVIVE_VOTE":
		var choice := Meeting.Choice.KEEP
		if role == "traitor":
			choice = Meeting.Choice.REVIVE if victim in allies else Meeting.Choice.KEEP
		elif float(suspicion.get(victim, 0.0)) > 1.0:
			choice = Meeting.Choice.KEEP
		elif rng.randf() < float(cfg["revive_base_chance"]):
			choice = Meeting.Choice.REVIVE
		else:
			choice = Meeting.Choice.ABSTAIN
		_act("vote_revive", choice, "")
	else:
		var best := -1
		var best_s := 1.2
		for pid: int in suspicion:
			if pid != id and pid != victim and float(suspicion[pid]) > best_s and not pid in allies:
				best_s = suspicion[pid]
				best = pid
		if best > 0 and rng.randf() < float(cfg["suspect_nominate_chance"]):
			_act("nominate", best, "")
		else:
			_act("skip", 0, "")


func _meeting_key() -> String:
	return "%d:%d" % [meeting.get("victim", -1), meeting.get("reporter", -1)]


func _discussion_line() -> String:
	var m := _m()
	var place := m.map.district_name(m.map.district_at(me["pos"]))
	var best := -1
	var best_s := 1.0
	for pid: int in suspicion:
		if float(suspicion[pid]) > best_s and names.has(pid):
			best = pid
			best_s = suspicion[pid]
	if best > 0:
		var lines := ["I saw %s shooting!", "%s was near the body.", "Where were you, %s?", "I don't trust %s."]
		return lines[rng.randi_range(0, lines.size() - 1)] % names[best]
	var calm := ["I was at %s." % place, "I heard gunshots.", "Check the cameras.", "Stay together.", "I was doing tasks at %s." % place]
	return calm[rng.randi_range(0, calm.size() - 1)]


func _act(kind: String, target: int, text: String) -> void:
	var m := _m()
	if m != null and m.players.has(id):
		m.handle_action(m.players[id], kind, target, text)


# ------------------------------------------------------------ senses ---

func _eye() -> Vector3:
	return (me["pos"] as Vector3) + Vector3(0, 1.45, 0)


func _sees_point(p: Vector3) -> bool:
	var eye := _eye()
	if eye.distance_to(p) > float(cfg["sight_range_m"]) * 1.5:
		return false
	return _m().line_of_sight(eye, p + Vector3(0, 0.2, 0))


func _visible_players() -> Array:
	var out: Array = []
	var eye := _eye()
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var half_fov := deg_to_rad(float(cfg["sight_fov_degrees"]) * 0.5)
	for e: Array in snapshot.get("players", []):
		if e[0] == id:
			continue
		var pos: Vector3 = e[1]
		var to := pos + Vector3(0, 1.2, 0) - eye
		if to.length() > float(cfg["sight_range_m"]):
			continue
		var flat := Vector3(to.x, 0, to.z).normalized()
		if flat.length() > 0.01 and fwd.angle_to(flat) > half_fov and to.length() > 4.0:
			continue
		if _m().line_of_sight(eye, pos + Vector3(0, 1.2, 0)):
			out.append({"id": e[0], "pos": pos, "state": e[4]})
	return out


func _visible_bodies() -> Array:
	var out: Array = []
	var eye := _eye()
	var candidates: Array = []
	for e: Array in snapshot.get("players", []):
		if e[4] == Vitals.State.DOWNED and e[0] != id:
			candidates.append({"id": e[0], "pos": e[1]})
	for b: Array in snapshot.get("bodies", []):
		candidates.append({"id": b[0], "pos": b[1]})
	for c: Dictionary in candidates:
		if eye.distance_to(c["pos"]) <= float(cfg["sight_range_m"]) and _m().line_of_sight(eye, c["pos"] + Vector3(0, 0.4, 0)):
			out.append(c)
	return out


# ---------------------------------------------------------- movement ---

func _follow_path(inp: PlayerInput, my_pos: Vector3, dt: float) -> void:
	if path.is_empty():
		path = _plan(goal_pos)
		path_i = 0
	if sidestep > 0.0:
		sidestep -= dt
		inp.move = Vector2(sidestep_dir, 0.3)
		return
	# Path smoothing: skip a waypoint when the one after it is directly visible.
	smooth_timer -= dt
	if smooth_timer <= 0.0:
		smooth_timer = 0.3
		if path_i + 1 < path.size() and my_pos.distance_to(path[path_i + 1]) < 30.0 and _clear(my_pos, path[path_i + 1]):
			path_i += 1
	while path_i < path.size() - 1 and Vector2(path[path_i].x - my_pos.x, path[path_i].z - my_pos.z).length() < float(cfg["waypoint_reach_m"]):
		path_i += 1
	var next: Vector3 = path[mini(path_i, path.size() - 1)]
	_face(next, dt, 8.0)
	inp.move = Vector2(0, 1)
	if goal_kind in ["report", "repair"] or (role == "traitor" and target_id > 0):
		inp.buttons |= PlayerInput.SPRINT
	# Stuck detection: jump, then skip ahead / re-path.
	stuck_timer += dt
	if stuck_timer >= float(cfg["stuck_seconds"]):
		if my_pos.distance_to(last_pos) < 0.8:
			stuck_count += 1
			inp.buttons |= PlayerInput.JUMP
			sidestep = 0.6
			sidestep_dir = -1.0 if rng.randf() < 0.5 else 1.0
			path = _plan(goal_pos)
			path_i = 0
			if stuck_count >= 4:
				goal_kind = ""
		else:
			stuck_count = 0
		stuck_timer = 0.0
		last_pos = my_pos


## Plans from a waypoint the bot can actually see (not one behind a wall).
func _plan(to: Vector3) -> PackedVector3Array:
	var m := _m()
	var my_pos: Vector3 = me["pos"]
	if _clear(my_pos, to) and my_pos.distance_to(to) < 25.0:
		return PackedVector3Array([to])
	for wp: String in m.map.nearest_waypoints(my_pos, 6):
		if _clear(my_pos, m.map.waypoint_position(wp)):
			return m.map.path_via(wp, to)
	return m.map.path(my_pos, to)


## Walkable straight line (knee and chest height rays).
func _clear(a: Vector3, b: Vector3) -> bool:
	var m := _m()
	return m.line_of_sight(a + Vector3(0, 0.5, 0), b + Vector3(0, 0.5, 0)) and m.line_of_sight(a + Vector3(0, 1.3, 0), b + Vector3(0, 1.3, 0))


func _face(point: Vector3, dt: float, speed: float) -> void:
	var my_pos: Vector3 = me["pos"]
	var to := point - my_pos
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var want := atan2(-to.x, -to.z)
	yaw = lerp_angle(yaw, want, clampf(dt * speed, 0.0, 1.0))
	var eye_h := 1.45
	var flat := Vector2(to.x, to.z).length()
	pitch = lerpf(pitch, clampf(atan2(to.y - eye_h + 1.1, flat), -0.8, 0.8), clampf(dt * speed, 0.0, 1.0))


func _pick_weapon(inp: PlayerInput) -> void:
	var inv: Dictionary = me.get("inv", {})
	var ws: Array = inv.get("weapons", [])
	var active: int = inv.get("active", Inventory.SIDEARM)
	var want := Inventory.SIDEARM
	if ws.size() > 0 and not ws[0].is_empty():
		want = Inventory.PRIMARY
	elif ws.size() > 1 and not ws[1].is_empty():
		want = Inventory.SECONDARY
	if want != active:
		inp.slot = want


func _random_waypoint() -> Vector3:
	var names_list := _m().map.waypoint_names()
	return _m().map.waypoint_position(names_list[rng.randi_range(0, names_list.size() - 1)])
