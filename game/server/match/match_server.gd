class_name MatchServer
extends Node
## Authoritative match simulation (GAME_SPEC §4, §5). Owns an isolated physics
## world, all ServerPlayers, rules objects and bots. Every outgoing message goes
## through send(), which delivers to humans (ServerSession) or bots (BotBrain)
## and emits `outbound` so tests can audit exactly what each player received.

signal outbound(peer_id: int, type: int, payload: Dictionary)
signal match_ended(result: Dictionary)
signal log_line(text: String)

const INTERACT_REPORT := "report"
const INTERACT_GENERATOR := "generator"
const INTERACT_BREAKER := "breaker"
const INTERACT_CAMERA_RESET := "camera_reset"
const INTERACT_TASK := "task"
const INTERACT_PICKUP := "pickup"
const INTERACT_EMERGENCY := "emergency"
const INTERACT_CAMERAS := "cameras"
const CHAT_MAX := 140
const LOBBY_PHASES := [MatchPhases.Phase.WAITING, MatchPhases.Phase.COUNTDOWN]

var session: ServerSession
var map: MapData
var map_id := "slice"
var mode := "standard"
var settings: Dictionary
var phases: MatchPhases
var players: Dictionary = {}  # id -> ServerPlayer
var bots: Dictionary = {}     # id -> BotBrain
var tasks: TaskBoard
var sabotage: SabotageSystem
var meeting: Meeting
var loot: Array = []
var gunfire: Array = []       # [[time, pos]]
var timeline: Array = []      # server-only until RESULTS
var now := 0.0
var tick_count := 0
var host_id := 0
var auto_bot_fill := true
var critical_expired := false
var result: Dictionary = {}
var emergency_ready_at := 0.0
var rng := RandomNumberGenerator.new()
var motor: PlayerMotor
var world_viewport: SubViewport
var world: Node3D

var weapons_by_id := {}
var combat_cfg: Dictionary
var movement_cfg: Dictionary
var interaction_cfg: Dictionary
var flow_cfg: Dictionary
var items_cfg: Dictionary
var bots_cfg: Dictionary
var net_cfg: Dictionary

var _next_bot_id := 1000
var _next_loot_id := 1
var _snapshot_timer := 0.0
var _slow_timer := 0.0
var _chat_ready: Dictionary = {}
var _bot_names: Array = []


func setup(p_map_id: String = "slice", p_mode: String = "standard", overrides: Dictionary = {}, seed_value: int = -1) -> void:
	map_id = p_map_id
	mode = p_mode
	rng.seed = seed_value if seed_value >= 0 else int(Time.get_ticks_usec())
	for w: Dictionary in GameData.table("weapons")["weapons"]:
		weapons_by_id[w["id"]] = w
	combat_cfg = GameData.table("combat")
	movement_cfg = GameData.table("movement")
	interaction_cfg = GameData.table("interaction")
	flow_cfg = GameData.table("match_flow")
	items_cfg = GameData.table("items")
	bots_cfg = GameData.table("bots")
	net_cfg = GameData.table("network")
	settings = MatchSettings.build(GameData.table("lobby_defaults"), GameData.table("modes"), mode, overrides)
	motor = PlayerMotor.new(movement_cfg)
	map = MapData.load_map(map_id)
	_bot_names = bots_cfg["names"].duplicate()
	_build_world()
	_reset_match_state()


func _build_world() -> void:
	world_viewport = SubViewport.new()
	world_viewport.name = "ServerWorld"
	world_viewport.own_world_3d = true
	world_viewport.size = Vector2i(2, 2)
	world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world_viewport.disable_3d = false
	add_child(world_viewport)
	world = MapBuilder.build(map, false)
	world_viewport.add_child(world)


func _reset_match_state() -> void:
	phases = MatchPhases.new(flow_cfg)
	sabotage = SabotageSystem.new(GameData.table("sabotages"), float(settings["sabotage_cooldown_multiplier"]))
	tasks = TaskBoard.new(GameData.table("tasks"))
	meeting = null
	gunfire.clear()
	timeline.clear()
	critical_expired = false
	result = {}
	emergency_ready_at = 0.0
	loot.clear()
	for l: Dictionary in map.raw.get("loot", []):
		_spawn_loot(l["item"], l.get("rarity", "standard"), int(l.get("amount", 0)), map.ground_point(float(l["x"]), float(l["z"])))


# ---------------------------------------------------------------- players ---

func add_human(peer_id: int, display_name: String) -> void:
	if players.has(peer_id):
		return
	var p := _create_player(peer_id, display_name, false)
	if host_id == 0:
		host_id = peer_id
	if not phases.phase in LOBBY_PHASES:
		# Late joiners watch as spectators (no role).
		p.vitals.eliminate(now)
		p.spectator = true
		p.reported = true
		_hide_body(p)
	_send_match_info_to_all()


func remove_human(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var p: ServerPlayer = players[peer_id]
	if phases.phase in LOBBY_PHASES or phases.phase == MatchPhases.Phase.RESULTS or p.spectator:
		_remove_player(peer_id)
	else:
		# Mid-match: a bot quietly takes over so the role is never revealed.
		p.connected = false
		p.is_bot = true
		bots[peer_id] = BotBrain.new(self, peer_id)
		_replay_private_state_to_bot(p)
		_log("player %d left; bot takeover" % peer_id)
	if host_id == peer_id:
		host_id = 0
		for other: ServerPlayer in players.values():
			if not other.is_bot:
				host_id = other.id
				break
	_send_match_info_to_all()


func add_bot() -> int:
	var id := _next_bot_id
	_next_bot_id += 1
	var bot_name: String = _bot_names.pop_front() if not _bot_names.is_empty() else "Bot %d" % id
	_create_player(id, bot_name, true)
	bots[id] = BotBrain.new(self, id)
	return id


func fill_bots(total: int) -> void:
	while players.size() < total:
		add_bot()


func _create_player(id: int, display_name: String, bot: bool) -> ServerPlayer:
	var p := ServerPlayer.new()
	p.id = id
	p.name = display_name
	p.is_bot = bot
	p.color = _free_color()
	p.vitals = Vitals.new(float(combat_cfg["max_health"]), float(combat_cfg["max_shield"]), float(settings["bleed_out_seconds"]), bool(settings["bleed_out_enabled"]))
	p.inventory = Inventory.new(combat_cfg, items_cfg)
	p.inventory.reset_loadout(weapons_by_id[interaction_cfg["start_weapon"]], int(interaction_cfg["start_light_ammo"]))
	p.body = PlayerMotor.make_body(movement_cfg)
	p.body.name = "P%d" % id
	world.add_child(p.body)
	var spawns := map.spawn_points()
	p.body.global_position = spawns[players.size() % spawns.size()]
	players[id] = p
	return p


func _remove_player(id: int) -> void:
	var p: ServerPlayer = players[id]
	if p.body != null:
		p.body.queue_free()
	players.erase(id)
	bots.erase(id)


func _free_color() -> int:
	var used := {}
	for p: ServerPlayer in players.values():
		used[p.color] = true
	for c in 12:
		if not used.has(c):
			return c
	return players.size() % 12


func _hide_body(p: ServerPlayer) -> void:
	p.body.collision_layer = 0
	p.body.collision_mask = 0
	p.body.global_position = Vector3(0, -500, 0)
	p.body.velocity = Vector3.ZERO


# ------------------------------------------------------------- messaging ---

func send(pid: int, type: int, payload: Dictionary, reliable: bool = true) -> void:
	outbound.emit(pid, type, payload)
	if bots.has(pid):
		bots[pid].receive(type, payload)
	elif session != null and session.is_ready(pid):
		session.send_to(pid, type, payload, reliable)


func broadcast(type: int, payload: Dictionary, reliable: bool = true) -> void:
	for pid: int in players:
		send(pid, type, payload, reliable)


func handle_message(peer_id: int, type: int, payload: Dictionary) -> void:
	if not players.has(peer_id) or bots.has(peer_id):
		return
	var p: ServerPlayer = players[peer_id]
	match type:
		Protocol.Msg.INPUT:
			p.input_queue.append(PlayerInput.from_payload(payload))
			if p.input_queue.size() > 30:
				p.input_queue.pop_front()
		Protocol.Msg.ACTION:
			handle_action(p, payload["kind"], payload["target"], payload["text"])


func handle_action(p: ServerPlayer, kind: String, target: int, text: String) -> void:
	match kind:
		"start":
			if p.id == host_id or p.is_bot:
				request_start()
		"vote_revive":
			if meeting != null and meeting.cast_revive(p.id, target):
				_broadcast_meeting()
		"nominate":
			var targets := _nominatable()
			if meeting != null and meeting.nominate(p.id, target, targets):
				_broadcast_meeting()
		"skip":
			if meeting != null and meeting.skip_nomination(p.id):
				_broadcast_meeting()
		"sabotage":
			_try_sabotage(p, text)
		"chat":
			_chat(p, text)


func request_start() -> bool:
	if phases.phase != MatchPhases.Phase.WAITING:
		return false
	var humans := players.values().filter(func(q: ServerPlayer) -> bool: return not q.is_bot).size()
	if auto_bot_fill:
		fill_bots(maxi(int(flow_cfg["bot_fill_to"]), humans))
	if players.size() < int(flow_cfg["min_players_to_start"]):
		return false
	phases.start()
	_log("match starting with %d players" % players.size())
	_send_match_info_to_all()
	return true


# ------------------------------------------------------------------ tick ---

func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	now += delta
	tick_count += 1
	var before := phases.phase
	if phases.tick(delta):
		_on_phase_changed(before)
	_process_players(delta)
	if phases.is_playing():
		_process_playing(delta)
	elif phases.in_meeting():
		_process_meeting(delta)
	elif phases.phase == MatchPhases.Phase.RESULTS and phases.time_left <= 0.0:
		_back_to_lobby()
	_snapshot_timer += delta
	if _snapshot_timer >= 1.0 / float(flow_cfg["snapshot_rate"]):
		_snapshot_timer = 0.0
		_send_snapshots()
	_slow_timer += delta
	if _slow_timer >= float(flow_cfg["state_broadcast_seconds"]):
		_slow_timer = 0.0
		_send_match_info_to_all()
		if phases.is_playing() or phases.in_meeting():
			_broadcast_world()
			_send_panels()
		if meeting != null:
			_broadcast_meeting()


func _on_phase_changed(before: int) -> void:
	match phases.phase:
		MatchPhases.Phase.ROLE_REVEAL:
			_assign_roles()
		MatchPhases.Phase.ACTIVE:
			if before == MatchPhases.Phase.ROLE_REVEAL:
				_spawn_all()
				_timeline("Match started — %d players" % players.size())
		MatchPhases.Phase.RESULTS:
			pass
	_send_match_info_to_all()


func _assign_roles() -> void:
	var ids: Array = players.keys()
	ids.sort()
	var count := RoleAssigner.traitor_count(ids.size(), settings, int(settings.get("traitor_override", -1)))
	var roles := RoleAssigner.assign(ids, count, rng)
	var agents: Array = []
	var traitors: Array = []
	for id: int in ids:
		players[id].role = roles[id]
		(traitors if roles[id] == RoleAssigner.Role.TRAITOR else agents).append(id)
	tasks.assign(agents, traitors, int(settings["tasks_per_agent"]), map.station_districts(), rng)
	for id: int in ids:
		_send_private_state(players[id])
	_log("roles assigned: %d traitors" % traitors.size())


## Own role, fellow traitors (traitors only), own tasks, sabotage panel (traitors only).
func _send_private_state(p: ServerPlayer) -> void:
	var allies: Array = []
	if p.role == RoleAssigner.Role.TRAITOR:
		for q: ServerPlayer in players.values():
			if q.id != p.id and q.role == RoleAssigner.Role.TRAITOR:
				allies.append({"id": q.id, "name": q.name, "color": q.color})
	send(p.id, Protocol.Msg.ROLE, {"role": RoleAssigner.role_name(p.role), "allies": allies})
	send(p.id, Protocol.Msg.TASKS, {"tasks": tasks.view_for(p.id)})
	if p.role == RoleAssigner.Role.TRAITOR:
		send(p.id, Protocol.Msg.SABOTAGE_PANEL, {"panel": _panel_payload()})


func _replay_private_state_to_bot(p: ServerPlayer) -> void:
	if not phases.phase in LOBBY_PHASES:
		_send_private_state(p)
		if meeting != null:
			_broadcast_meeting()


func _spawn_all() -> void:
	var spawns := map.spawn_points()
	var order: Array = range(spawns.size())
	order.shuffle()
	var i := 0
	for p: ServerPlayer in players.values():
		if p.spectator:
			continue
		p.body.global_position = spawns[order[i % order.size()]]
		p.body.velocity = Vector3.ZERO
		p.vitals.revive(float(combat_cfg["max_health"]), 0.0, 0.0)
		p.inventory.reset_loadout(weapons_by_id[interaction_cfg["start_weapon"]], int(interaction_cfg["start_light_ammo"]))
		i += 1


func _process_players(delta: float) -> void:
	for p: ServerPlayer in players.values():
		if p.spectator:
			continue
		var inputs: Array = []
		if bots.has(p.id):
			var bi: PlayerInput = bots[p.id].think(delta)
			bi.dt = delta
			inputs.append(bi)
		else:
			var budget := delta * 1.25 + 0.02
			while not p.input_queue.is_empty() and budget > 0.0:
				var inp: PlayerInput = p.input_queue.pop_front()
				budget -= inp.dt
				inputs.append(inp)
			if inputs.is_empty():
				var idle := PlayerInput.new()
				idle.seq = p.ack_seq
				idle.yaw = p.yaw
				idle.pitch = p.pitch
				idle.dt = delta
				idle.buttons = p.last_input.buttons & (PlayerInput.INTERACT | PlayerInput.CROUCH | PlayerInput.FLASHLIGHT)
				inputs.append(idle)
		for inp: PlayerInput in inputs:
			_apply_input(p, inp)
		_process_interaction(p, delta)
		_process_items(p, delta)
		p.record_history(now, float(flow_cfg["history_seconds"]))


func _movement_allowed(p: ServerPlayer) -> bool:
	if p.spectator or p.vitals.state == Vitals.State.ELIMINATED:
		return false
	return phases.phase in [MatchPhases.Phase.WAITING, MatchPhases.Phase.COUNTDOWN, MatchPhases.Phase.ACTIVE, MatchPhases.Phase.RESUMING]


func _apply_input(p: ServerPlayer, inp: PlayerInput) -> void:
	p.ack_seq = maxi(p.ack_seq, inp.seq)
	p.last_input = inp
	var allowed := _movement_allowed(p)
	var downed := p.vitals.state == Vitals.State.DOWNED
	if allowed:
		p.yaw = inp.yaw
		p.pitch = inp.pitch
		p.crouching = inp.has(PlayerInput.CROUCH) and not downed
		p.aiming = inp.has(PlayerInput.AIM) and not downed
		p.sprinting = inp.has(PlayerInput.SPRINT)
		p.flashlight = inp.has(PlayerInput.FLASHLIGHT)
	var before := p.feet()
	var state := {"frozen": not allowed, "downed": downed, "stunned": p.vitals.is_stunned(), "crouching": p.crouching}
	motor.step(p.body, inp, state, inp.dt)
	p.stats["distance"] += Vector2(p.feet().x - before.x, p.feet().z - before.z).length()
	if not phases.is_playing() or not p.is_living() or p.vitals.is_stunned():
		return
	var inv := p.inventory
	if inp.slot >= 0 and inp.slot != inv.active:
		if inv.select(inp.slot):
			_cancel_healing(p)
	var w := inv.active_weapon() if inv.active != Inventory.HEALING else null
	if w != null:
		w.set_trigger(inp.has(PlayerInput.FIRE), now)
		if inp.has(PlayerInput.RELOAD):
			w.start_reload(now, inv.reserve_for(w))
	if inp.has(PlayerInput.FIRE):
		if inv.active == Inventory.HEALING:
			_start_healing(p)
		elif w != null:
			_try_fire(p, w, inp)


func _process_items(p: ServerPlayer, delta: float) -> void:
	var w := p.inventory.active_weapon() if p.inventory.active != Inventory.HEALING else null
	if w != null:
		var used := w.update(now, p.inventory.reserve_for(w))
		if used > 0:
			p.inventory.take_ammo(w.ammo_type(), used)
		if w.mag == 0 and not w.is_reloading() and p.is_living() and phases.is_playing():
			w.start_reload(now, p.inventory.reserve_for(w))  # auto reload
	if p.healing_left > 0.0:
		p.healing_left -= delta
		if p.healing_left <= 0.0:
			var def := p.inventory.use_consumable(p.healing_item)
			if not def.is_empty():
				if bool(def.get("to_full", false)):
					p.vitals.heal(p.vitals.max_health)
				else:
					p.vitals.heal(float(def["heal"]))
				p.vitals.add_shield(float(def["shield"]))
			p.healing_item = ""


func _start_healing(p: ServerPlayer) -> void:
	if p.healing_left > 0.0:
		return
	var item := p.inventory.pick_consumable(p.vitals.health, p.vitals.max_health, p.vitals.shield, p.vitals.max_shield)
	if item.is_empty():
		return
	p.healing_item = item
	p.healing_left = float(p.inventory.consumable_defs[item]["use_seconds"])


func _cancel_healing(p: ServerPlayer) -> void:
	p.healing_left = 0.0
	p.healing_item = ""


# ---------------------------------------------------------------- combat ---

func _try_fire(p: ServerPlayer, w: WeaponInstance, inp: PlayerInput) -> void:
	var pellets := w.fire(now)
	if pellets <= 0:
		return
	_cancel_healing(p)
	p.stats["shots"] += 1
	var origin := p.eye(movement_cfg)
	var aim := inp.aim_point
	if aim == Vector3.ZERO or aim.distance_to(origin) > 1000.0 or aim.distance_to(origin) < 0.5:
		aim = origin + p.forward() * 100.0
	var dir := (aim - origin).normalized()
	var view_time := clampf(inp.view_time, now - float(net_cfg["lag_compensation_max_ms"]) / 1000.0, now)
	var moving := Vector2(p.body.velocity.x, p.body.velocity.z).length() > 1.0
	var spread := w.spread_degrees(p.aiming, moving)
	var weapon_range := float(w.def.get("range_m", 200.0))
	var space := world.get_world_3d().direct_space_state
	var best_end := origin + dir * weapon_range
	var family: String = w.def["family"]
	for i in pellets:
		var d := HitscanMath.apply_spread(dir, spread, rng.randf(), rng.randf())
		var to := origin + d * weapon_range
		var q := PhysicsRayQueryParameters3D.create(origin, to, MapBuilder.WORLD_LAYER)
		var hit := space.intersect_ray(q)
		var world_dist := origin.distance_to(hit["position"]) if not hit.is_empty() else weapon_range
		var target: ServerPlayer = null
		var target_dist := world_dist
		var headshot := false
		for other: ServerPlayer in players.values():
			if other.id == p.id or other.spectator or other.vitals.state == Vitals.State.ELIMINATED:
				continue
			var pose := other.pose_at(view_time)
			var height := float(movement_cfg["capsule_height"])
			if pose[1]:
				height = float(movement_cfg["crouch_height"])
			if pose[2]:
				height = 0.7
			var head_h := height - float(movement_cfg["capsule_height"]) + float(movement_cfg["head_center_height"])
			var r := HitscanMath.test_player(origin, d, pose[0], height, float(movement_cfg["capsule_radius"]), head_h, float(movement_cfg["head_radius"]))
			if r["hit"] and float(r["distance"]) < target_dist:
				target = other
				target_dist = r["distance"]
				headshot = r["headshot"]
		if target != null:
			var dmg := w.damage_at(target_dist, headshot, combat_cfg) * float(settings["friendly_fire_multiplier"])
			var stun := float(w.def.get("stun_seconds", 0.0))
			if stun > 0.0:
				target.vitals.stun(stun)
			_damage(target, dmg, p, family, target_dist, origin, headshot)
			best_end = origin + d * target_dist
		elif i == 0:
			best_end = origin + d * world_dist
	gunfire.append([now, origin])
	_emit_shot(p, origin, best_end, family)


func _emit_shot(shooter: ServerPlayer, origin: Vector3, end: Vector3, family: String) -> void:
	var audible := 400.0 if family == "sniper" else 250.0
	for q: ServerPlayer in players.values():
		var dist := q.feet().distance_to(origin)
		if q.spectator or dist <= audible:
			# Shooter identity only for players close enough to see the muzzle flash.
			var who := shooter.id if (dist <= 80.0 or q.spectator or q.id == shooter.id) else -1
			send(q.id, Protocol.Msg.EVENT, {"kind": "shot", "data": {"shooter": who, "origin": origin, "end": end, "family": family}}, false)


func _damage(target: ServerPlayer, amount: float, attacker: ServerPlayer, family: String, distance: float, origin: Vector3, headshot: bool) -> void:
	if not phases.is_playing():
		return
	var res := target.vitals.apply_damage(amount, now)
	if res["result"] == Vitals.RESULT_NONE:
		return
	var to_attacker := origin - target.feet()
	target.incident = {
		"time": now, "district": map.district_at(target.feet()), "damage_type": "gunfire",
		"weapon_family": family, "range": _range_band(distance), "direction": _direction_name(target, to_attacker),
	}
	_cancel_healing(target)
	if attacker != null:
		attacker.stats["hits"] += 1
		send(attacker.id, Protocol.Msg.EVENT, {"kind": "hit", "data": {"head": headshot, "shield": float(res["shield_damage"]) > 0.0, "down": res["result"] == Vitals.RESULT_DOWNED}})
	send(target.id, Protocol.Msg.EVENT, {"kind": "hurt", "data": {"dir": to_attacker.normalized(), "amount": amount}})
	match res["result"]:
		Vitals.RESULT_DOWNED:
			if attacker != null:
				attacker.stats["downs"] += 1
			target.interact_target = ""
			send(target.id, Protocol.Msg.EVENT, {"kind": "downed", "data": {}})
			_timeline("%s downed %s (%s)" % [attacker.name if attacker else "?", target.name, map.district_name(target.incident["district"])])
			_check_win()
		Vitals.RESULT_FINISHED:
			send(target.id, Protocol.Msg.EVENT, {"kind": "eliminated", "data": {}})
			_timeline("%s finished %s" % [attacker.name if attacker else "?", target.name])
			_check_win()


static func _range_band(d: float) -> String:
	if d < 10.0:
		return "close"
	return "mid" if d < 40.0 else "long"


func _direction_name(target: ServerPlayer, to_attacker: Vector3) -> String:
	var local := Basis(Vector3.UP, target.yaw).inverse() * to_attacker
	var ang := rad_to_deg(atan2(local.x, -local.z))
	var names := ["front", "front-right", "right", "back-right", "back", "back-left", "left", "front-left"]
	return names[int(round(wrapf(ang, 0.0, 360.0) / 45.0)) % 8]


# ----------------------------------------------------------- interaction ---

func _process_interaction(p: ServerPlayer, delta: float) -> void:
	var holding := p.last_input.has(PlayerInput.INTERACT)
	if not phases.is_playing() or not p.is_living():
		p.interact_target = ""
		p.interact_held = 0.0
		p.set_meta("prompt", {})
		return
	var target := find_interaction(p)
	p.set_meta("prompt", target)
	if holding and not target.is_empty() and p.get_meta("interact_lock", "") != target["key"]:
		if p.interact_target != target["key"]:
			p.interact_target = target["key"]
			p.interact_held = 0.0
		p.interact_held += delta
		if p.interact_held + 0.0001 >= float(target["hold"]):
			var held := p.interact_held
			p.interact_target = ""
			p.interact_held = 0.0
			p.set_meta("interact_lock", target["key"])
			_execute_interaction(p, target, held)
	else:
		p.interact_target = ""
		p.interact_held = 0.0
		if not holding:
			p.set_meta("interact_lock", "")


## Best interaction in range: {key, kind, verb, label, hold, ref}.
func find_interaction(p: ServerPlayer) -> Dictionary:
	var pos := p.feet()
	var reach := float(interaction_cfg["range_m"])
	# 1. Report a body.
	for q: ServerPlayer in players.values():
		if q.id == p.id or q.spectator or q.reported:
			continue
		if q.vitals.state != Vitals.State.ALIVE and q.feet().distance_to(pos) <= reach + 0.6:
			return _prompt("report:%d" % q.id, INTERACT_REPORT, "REPORT", "Report %s" % q.name, float(interaction_cfg["report_hold_seconds"]), q.id)
	# 2. Repairs.
	var sab_def: Dictionary = GameData.table("sabotages")["sabotages"]
	if sabotage.power_out():
		var restored := _restored_generators()
		for gen_id: String in map.raw.get("generators", []):
			if not restored.has(gen_id) and map.station_pos(gen_id).distance_to(pos) <= reach + 0.8:
				return _prompt("gen:" + gen_id, INTERACT_GENERATOR, "REPAIR", "Restore %s" % map.station(gen_id)["label"], float(sab_def["power_failure"]["repair_hold_seconds"]), gen_id)
	for district: String in sabotage.blackout_districts():
		var breaker := "breaker_%s" % district
		if map.stations.has(breaker) and map.station_pos(breaker).distance_to(pos) <= reach:
			return _prompt("breaker:" + district, INTERACT_BREAKER, "REPAIR", "Reset breaker", float(sab_def["blackout"]["repair_hold_seconds"]), district)
	var reset_pos := map.station_pos("security_reset")
	var near_security := map.stations.has("security_reset") and reset_pos.distance_to(pos) <= reach
	if near_security and sabotage.is_active("camera_jam"):
		return _prompt("camreset", INTERACT_CAMERA_RESET, "RESET", "Reset camera network", float(sab_def["camera_jam"]["repair_hold_seconds"]), "")
	# 3. Tasks (fake tasks look identical).
	var list := tasks.tasks_for(p.id)
	for i in list.size():
		var station := tasks.current_station(p.id, i)
		if not station.is_empty() and map.station_pos(station).distance_to(pos) <= reach:
			var t: Dictionary = list[i]
			var step: Dictionary = t["steps"][t["step"]]
			var hold := maxf(0.6, float(step["hold"]))
			return _prompt("task:%d" % i, INTERACT_TASK, "START TASK", step["label"], hold, i)
	# 4. Pick up loot.
	for l: Dictionary in loot:
		if not l["taken"] and (l["pos"] as Vector3).distance_to(pos) <= reach:
			return _prompt("loot:%d" % l["id"], INTERACT_PICKUP, "PICK UP", _loot_label(l), float(items_cfg["pickup_hold_seconds"]), l["id"])
	# 5. Emergency button.
	if map.stations.has("emergency_button") and map.station_pos("emergency_button").distance_to(pos) <= float(interaction_cfg["emergency_range_m"]):
		if p.emergency_uses < int(settings["emergency_meeting_uses_per_player"]) and now >= emergency_ready_at:
			return _prompt("emergency", INTERACT_EMERGENCY, "EMERGENCY", "Call emergency meeting", 1.0, 0)
	# 6. Security cameras.
	if near_security and bool(settings.get("cameras_enabled", true)):
		return _prompt("cameras", INTERACT_CAMERAS, "USE TERMINAL", "Security cameras", 0.3, 0)
	return {}


static func _prompt(key: String, kind: String, verb: String, label: String, hold: float, ref: Variant) -> Dictionary:
	return {"key": key, "kind": kind, "verb": verb, "label": label, "hold": hold, "ref": ref}


func _execute_interaction(p: ServerPlayer, target: Dictionary, held: float) -> void:
	match target["kind"]:
		INTERACT_REPORT:
			p.stats["reports"] += 1
			_start_meeting(Meeting.KIND_REPORT, p.id, int(target["ref"]))
		INTERACT_GENERATOR:
			var r := sabotage.repair("power_failure", "", target["ref"])
			p.stats["repairs"] += 1
			_timeline("%s restored %s" % [p.name, map.station(target["ref"])["label"]])
			if r["repaired"]:
				_alert("POWER RESTORED", "", false)
			_broadcast_world()
		INTERACT_BREAKER:
			if sabotage.repair("blackout", target["ref"])["repaired"]:
				p.stats["repairs"] += 1
				_alert("LIGHTS RESTORED", target["ref"], false)
				_broadcast_world()
		INTERACT_CAMERA_RESET:
			while sabotage.is_active("camera_jam"):
				var jam: Dictionary = sabotage.active.filter(func(a: Dictionary) -> bool: return a["kind"] == "camera_jam")[0]
				sabotage.repair("camera_jam", jam["district"])
			p.stats["repairs"] += 1
			_alert("CAMERAS ONLINE", "", false)
			_broadcast_world()
		INTERACT_TASK:
			var idx := int(target["ref"])
			var r := tasks.complete_step(p.id, idx, tasks.current_station(p.id, idx), held)
			if r["ok"]:
				if r["task_done"]:
					p.stats["tasks"] += 1
				send(p.id, Protocol.Msg.TASKS, {"tasks": tasks.view_for(p.id)})
				send(p.id, Protocol.Msg.EVENT, {"kind": "task_step", "data": {"done": r["task_done"]}})
				if r["progress"] > 0.0:
					_broadcast_world()
					_check_win()
		INTERACT_PICKUP:
			_pickup(p, int(target["ref"]))
		INTERACT_EMERGENCY:
			p.emergency_uses += 1
			_start_meeting(Meeting.KIND_EMERGENCY, p.id, -1)
		INTERACT_CAMERAS:
			send(p.id, Protocol.Msg.EVENT, {"kind": "open_cameras", "data": {}})


func _restored_generators() -> Dictionary:
	for a: Dictionary in sabotage.active:
		if a["kind"] == "power_failure":
			return a["generators"]
	return {}


# ------------------------------------------------------------------ loot ---

func _spawn_loot(item: String, rarity: String, amount: int, pos: Vector3, mag: int = -1) -> void:
	loot.append({"id": _next_loot_id, "item": item, "rarity": rarity, "amount": amount, "pos": pos + Vector3(0, 0.05, 0), "taken": false, "mag": mag})
	_next_loot_id += 1


func _loot_label(l: Dictionary) -> String:
	if weapons_by_id.has(l["item"]):
		return "%s (%s)" % [weapons_by_id[l["item"]]["display_name"], combat_cfg["rarities"][l["rarity"]]["display_name"]]
	if items_cfg["consumables"].has(l["item"]):
		return items_cfg["consumables"][l["item"]]["display_name"]
	return "%s ammo" % str(items_cfg["ammo_pickups"].get(l["item"], "")).capitalize()


func _pickup(p: ServerPlayer, loot_id: int) -> void:
	for l: Dictionary in loot:
		if l["id"] != loot_id or l["taken"]:
			continue
		var item: String = l["item"]
		if weapons_by_id.has(item):
			var w := WeaponInstance.create(weapons_by_id[item], l["rarity"])
			if int(l.get("mag", -1)) >= 0:
				w.mag = int(l["mag"])
			var old := p.inventory.add_weapon(w)
			p.inventory.select(Inventory.slot_index(w.def["slot"]))
			var reserve: Dictionary = items_cfg["weapon_starting_reserve"]
			p.inventory.add_ammo(w.ammo_type(), int(reserve.get(w.ammo_type(), 0)) if l.get("mag", -1) < 0 else 0)
			if old != null:
				_spawn_loot(old.id, old.rarity, 0, p.feet(), old.mag)
		elif items_cfg["consumables"].has(item):
			var left := p.inventory.add_consumable(item, int(l["amount"]))
			if left == int(l["amount"]):
				return
		elif items_cfg["ammo_pickups"].has(item):
			var left := p.inventory.add_ammo(items_cfg["ammo_pickups"][item], int(l["amount"]))
			if left == int(l["amount"]):
				return
		l["taken"] = true
		return


# --------------------------------------------------------------- meeting ---

func _start_meeting(kind: String, reporter: int, victim: int) -> void:
	if not phases.begin_meeting():
		return
	for p: ServerPlayer in players.values():
		p.interact_target = ""
		p.interact_held = 0.0
		_cancel_healing(p)
		p.body.velocity = Vector3.ZERO
	var participants: Array = []
	for p: ServerPlayer in players.values():
		if p.is_living() and not p.spectator:
			participants.append(p.id)
	participants.sort()
	var victim_downed := false
	var info := {"power": not sabotage.power_out()}
	if victim >= 0 and players.has(victim):
		var v: ServerPlayer = players[victim]
		v.reported = true
		victim_downed = v.vitals.state == Vitals.State.DOWNED
		info.merge(_incident_review(v))
	else:
		info["caller"] = players[reporter].name
	meeting = Meeting.new(kind, reporter, victim, victim_downed, participants, settings["meeting"])
	meeting.info = info
	_timeline("%s called a meeting (%s)" % [players[reporter].name, "body report" if kind == Meeting.KIND_REPORT else "emergency"])
	_alert("INCIDENT REPORTED" if kind == Meeting.KIND_REPORT else "EMERGENCY MEETING", "", true)
	_broadcast_meeting()


## Public incident review: never names the attacker (GAME_SPEC §5.4, §5.8).
func _incident_review(v: ServerPlayer) -> Dictionary:
	var inc := v.incident
	var district: String = inc.get("district", map.district_at(v.feet()))
	var out := {
		"victim_name": v.name, "district": map.district_name(district),
		"cameras": "jammed" if sabotage.camera_jammed(district) else "online",
		"damage_type": inc.get("damage_type", "unknown"), "weapon_family": inc.get("weapon_family", "unknown"),
		"range": inc.get("range", "unknown"), "direction": inc.get("direction", "unknown"),
		"victim_state": "downed" if v.vitals.state == Vitals.State.DOWNED else "eliminated",
	}
	if inc.has("time"):
		# Estimated time (±15 s), rounded to 5 s.
		var ago := now - float(inc["time"]) + rng.randf_range(-15.0, 15.0)
		out["seconds_ago"] = float(maxi(5, int(round(ago / 5.0)) * 5))
	return out


func _process_meeting(delta: float) -> void:
	if meeting == null:
		phases.end_meeting()
		return
	if meeting.tick(delta):
		_broadcast_meeting()
	if meeting.is_done():
		_finish_meeting()


func _nominatable() -> Array:
	var out: Array = []
	for p: ServerPlayer in players.values():
		if not p.spectator and p.vitals.state != Vitals.State.ELIMINATED:
			out.append(p.id)
	return out


func _broadcast_meeting() -> void:
	if meeting == null:
		return
	var voted: Array = []
	if meeting.phase == Meeting.Phase.REVIVE_VOTE:
		voted = meeting.revive_votes.keys()
	elif meeting.phase == Meeting.Phase.SUSPECT_VOTE:
		voted = meeting.nominations.keys()
	broadcast(Protocol.Msg.MEETING, {
		"phase": Meeting.phase_name(meeting.phase), "time_left": maxf(0.0, meeting.time_left), "kind": meeting.kind,
		"victim": meeting.victim, "reporter": meeting.reporter, "info": meeting.info,
		"participants": meeting.participants, "voted": voted, "revive_vote": meeting.has_revive_vote(),
	})


func _finish_meeting() -> void:
	var m := meeting
	meeting = null
	var revived := false
	if m.victim >= 0 and players.has(m.victim):
		var v: ServerPlayer = players[m.victim]
		if m.has_revive_vote() and m.revive_result() and v.vitals.state == Vitals.State.DOWNED:
			_revive(v)
			revived = true
		else:
			v.vitals.eliminate(now)
			v.spectator = true
			_hide_body(v)
		_timeline("%s was %s" % [v.name, "revived" if revived else "kept eliminated"])
	var suspects := m.suspects()
	var marker := float(settings["meeting"]["suspect_marker_seconds"])
	for sid: int in suspects:
		if players.has(sid):
			players[sid].suspect_until = now + marker
			_timeline("%s marked SUSPECT" % players[sid].name)
	broadcast(Protocol.Msg.MEETING_RESULT, {"victim": m.victim, "revived": revived, "had_vote": m.has_revive_vote(), "tally": m.revive_tally(), "suspects": suspects})
	emergency_ready_at = now + float(settings["emergency_meeting_global_cooldown"])
	phases.end_meeting()
	_broadcast_world()
	_check_win()


func _revive(v: ServerPlayer) -> void:
	v.vitals.revive(float(interaction_cfg["revive_health"]), float(interaction_cfg["revive_shield"]), float(interaction_cfg["spawn_protection_seconds"]))
	v.inventory.reset_loadout(weapons_by_id[interaction_cfg["start_weapon"]], int(interaction_cfg["revive_light_ammo"]))
	v.reported = false
	v.stats["revived"] += 1
	var candidates: Array = []
	for pod: String in map.raw.get("medical_respawn", []):
		candidates.append(map.station_pos(pod) + Vector3(0, 0.1, 1.2))
	var recent: Array = []
	for g: Array in gunfire:
		if now - float(g[0]) <= float(interaction_cfg["gunfire_memory_seconds"]):
			recent.append(g[1])
	var pos := RespawnRules.choose(candidates, recent, float(interaction_cfg["revive_gunfire_exclusion_m"]), map.spawn_points())
	v.body.global_position = pos
	v.body.velocity = Vector3.ZERO
	send(v.id, Protocol.Msg.EVENT, {"kind": "revived", "data": {}})


# -------------------------------------------------------------- sabotage ---

func _try_sabotage(p: ServerPlayer, text: String) -> void:
	if p.role != RoleAssigner.Role.TRAITOR or not p.is_living():
		return  # agents never learn the panel exists; no reply
	var parts := text.split("|")
	var kind := parts[0]
	var district := parts[1] if parts.size() > 1 else ""
	if not district.is_empty() and not district in map.district_ids():
		district = ""
	var reason := sabotage.can_trigger(kind, district, now, phases.elapsed, phases.in_meeting(), float(flow_cfg["sabotage_grace_seconds"]))
	if not reason.is_empty():
		send(p.id, Protocol.Msg.EVENT, {"kind": "denied", "data": {"reason": reason}})
		return
	sabotage.trigger(kind, district, now)
	p.stats["sabotages"] += 1
	var def: Dictionary = GameData.table("sabotages")["sabotages"][kind]
	_timeline("%s triggered %s%s" % [p.name, def["display_name"], (" at " + map.district_name(district)) if not district.is_empty() else ""])
	_alert(def["alert"], district, bool(def["critical"]))
	_broadcast_world()
	_send_panels()


func _panel_payload() -> Dictionary:
	var panel := sabotage.panel(now)
	panel["districts"] = map.district_ids()
	panel["grace_left"] = maxf(0.0, float(flow_cfg["sabotage_grace_seconds"]) - phases.elapsed)
	return panel


func _send_panels() -> void:
	var panel := _panel_payload()
	for p: ServerPlayer in players.values():
		if p.role == RoleAssigner.Role.TRAITOR and not p.spectator:
			send(p.id, Protocol.Msg.SABOTAGE_PANEL, {"panel": panel})


## Everyone sees the alert; nobody learns who triggered it.
func _alert(text: String, district: String, critical: bool) -> void:
	broadcast(Protocol.Msg.EVENT, {"kind": "alert", "data": {"text": text, "district": map.district_name(district) if not district.is_empty() else "", "critical": critical}})


func _broadcast_world() -> void:
	var suspects: Array = []
	for p: ServerPlayer in players.values():
		if p.suspect_until > now:
			suspects.append([p.id, p.suspect_until - now])
	var gens: Array = []
	if sabotage.power_out():
		var restored := _restored_generators()
		for g: String in map.raw.get("generators", []):
			gens.append([g, restored.has(g)])
	broadcast(Protocol.Msg.WORLD, {"security": tasks.security_percent(), "sabotages": sabotage.public_state(), "power": not sabotage.power_out(), "suspects": suspects, "generators": gens})


# ------------------------------------------------------------- playing ---

func _process_playing(delta: float) -> void:
	for p: ServerPlayer in players.values():
		if p.spectator:
			continue
		if p.vitals.tick(delta, false, now) == "bled_out":
			send(p.id, Protocol.Msg.EVENT, {"kind": "eliminated", "data": {}})
			_timeline("%s bled out" % p.name)
			_check_win()
	for ev: Dictionary in sabotage.tick(delta, false):
		if ev["type"] == "critical_expired":
			critical_expired = true
			_timeline("Power failure countdown expired")
		else:
			var def: Dictionary = GameData.table("sabotages")["sabotages"][ev["kind"]]
			_alert("%s ENDED" % def["alert"], ev["district"], false)
		_broadcast_world()
	var keep := float(interaction_cfg["gunfire_memory_seconds"])
	while not gunfire.is_empty() and now - float(gunfire[0][0]) > keep:
		gunfire.pop_front()
	_check_win()


func _check_win() -> void:
	if not phases.is_playing():
		return
	var list: Array = []
	for p: ServerPlayer in players.values():
		list.append({"role": p.role, "state": p.vitals.state})
	var r := WinRules.evaluate(list, tasks.security_percent(), critical_expired, phases.elapsed, float(settings["match_time_limit_seconds"]))
	if r["winner"] != WinRules.Winner.NONE:
		_end_match(r)


func _end_match(r: Dictionary) -> void:
	phases.end_match()
	var winner := WinRules.winner_name(r["winner"])
	_timeline("%s win (%s)" % [winner.capitalize(), r["reason"]])
	var list: Array = []
	for p: ServerPlayer in players.values():
		var state := "alive"
		if p.vitals.state == Vitals.State.DOWNED:
			state = "downed"
		elif p.vitals.state == Vitals.State.ELIMINATED:
			state = "eliminated"
		list.append({"id": p.id, "name": p.name, "color": p.color, "bot": p.is_bot, "role": RoleAssigner.role_name(p.role), "state": state, "stats": p.stats.duplicate()})
	result = {"winner": winner, "reason": r["reason"], "players": list, "timeline": timeline.duplicate(), "duration": phases.elapsed, "security": tasks.security_percent()}
	broadcast(Protocol.Msg.RESULTS, {"winner": winner, "reason": r["reason"], "players": list, "timeline": timeline.duplicate()})
	_log("match over: %s (%s) after %.0f s" % [winner, r["reason"], phases.elapsed])
	match_ended.emit(result)


func _back_to_lobby() -> void:
	for id: int in bots.keys():
		if players.has(id) and not players[id].connected:
			_remove_player(id)
	for id: int in bots.keys():
		_remove_player(id)
	_bot_names = bots_cfg["names"].duplicate()
	_reset_match_state()
	var spawns := map.spawn_points()
	var i := 0
	for p: ServerPlayer in players.values():
		p.spectator = false
		p.reported = false
		p.role = RoleAssigner.Role.AGENT
		p.vitals = Vitals.new(float(combat_cfg["max_health"]), float(combat_cfg["max_shield"]), float(settings["bleed_out_seconds"]), bool(settings["bleed_out_enabled"]))
		p.inventory.reset_loadout(weapons_by_id[interaction_cfg["start_weapon"]], int(interaction_cfg["start_light_ammo"]))
		p.body.collision_layer = 2
		p.body.collision_mask = 1
		p.body.global_position = spawns[i % spawns.size()]
		p.emergency_uses = 0
		p.suspect_until = -1.0
		for k: String in p.stats:
			p.stats[k] = 0
		i += 1
	_send_match_info_to_all()


# ------------------------------------------------------------ snapshots ---

func _send_snapshots() -> void:
	var others: Array = []
	var bodies: Array = []
	for q: ServerPlayer in players.values():
		if q.spectator:
			continue
		var w := q.inventory.active_weapon() if q.inventory.active != Inventory.HEALING else null
		var flags := 0
		flags |= 1 if q.crouching else 0
		flags |= 2 if q.aiming else 0
		flags |= 4 if q.sprinting else 0
		flags |= 8 if (w != null and w.is_reloading()) else 0
		flags |= 16 if q.flashlight else 0
		flags |= 32 if q.vitals.protection_left > 0.0 else 0
		flags |= 64 if q.healing_left > 0.0 else 0
		var entry := [q.id, q.feet(), q.yaw, q.pitch, int(q.vitals.state), w.id if w != null else "", flags]
		if q.vitals.state == Vitals.State.ELIMINATED:
			bodies.append([q.id, q.feet(), q.yaw])
		else:
			others.append(entry)
	var loot_view: Array = []
	for l: Dictionary in loot:
		if not l["taken"]:
			loot_view.append([l["id"], l["item"], l["rarity"], l["pos"]])
	for p: ServerPlayer in players.values():
		send(p.id, Protocol.Msg.SNAPSHOT, {"tick": tick_count, "time": now, "ack": p.ack_seq, "players": others, "bodies": bodies, "loot": loot_view, "me": _me_block(p)}, false)


func _me_block(p: ServerPlayer) -> Dictionary:
	var prompt: Dictionary = p.get_meta("prompt", {})
	var prompt_view := {}
	if not prompt.is_empty():
		prompt_view = {"verb": prompt["verb"], "label": prompt["label"], "hold": prompt["hold"], "progress": p.interact_held if p.interact_target == prompt["key"] else 0.0}
	var w := p.inventory.active_weapon() if p.inventory.active != Inventory.HEALING else null
	return {
		"id": p.id, "state": int(p.vitals.state), "spectator": p.spectator, "health": p.vitals.health, "shield": p.vitals.shield,
		"bleed": p.vitals.bleed_left, "protect": p.vitals.protection_left, "stun": p.vitals.stun_left,
		"pos": p.feet(), "vel": p.body.velocity, "crouch": p.crouching,
		"inv": p.inventory.view(), "reloading": w != null and w.is_reloading(),
		"healing": p.healing_left, "prompt": prompt_view,
		"emergency_left": int(settings["emergency_meeting_uses_per_player"]) - p.emergency_uses,
	}


func _send_match_info_to_all() -> void:
	var list: Array = []
	for p: ServerPlayer in players.values():
		list.append({"id": p.id, "name": p.name, "color": p.color, "bot": p.is_bot})
	var payload := {"map": map_id, "phase": phases.phase_name(), "time_left": maxf(0.0, phases.time_left), "elapsed": phases.elapsed,
		"time_limit": float(settings["match_time_limit_seconds"]), "players": list, "host": host_id, "mode": mode}
	broadcast(Protocol.Msg.MATCH_INFO, payload)


# ----------------------------------------------------------------- chat ---

func _chat(p: ServerPlayer, text: String) -> void:
	var clean := text.strip_edges().left(CHAT_MAX)
	if clean.is_empty() or now < float(_chat_ready.get(p.id, 0.0)):
		return
	_chat_ready[p.id] = now + 0.7
	var is_victim := meeting != null and meeting.victim == p.id
	var channel := CommsRules.sender_channel(p.vitals.state if not p.spectator else Vitals.State.ELIMINATED, phases.in_meeting(), is_victim)
	if channel.is_empty():
		return
	var prox := float(settings.get("name_display_distance", 30.0))
	for q: ServerPlayer in players.values():
		var state := Vitals.State.ELIMINATED if q.spectator else q.vitals.state
		if CommsRules.can_receive(channel, state, q.feet().distance_to(p.feet()), prox):
			send(q.id, Protocol.Msg.CHAT_MSG, {"from": p.id, "name": p.name, "text": clean, "channel": channel})


# --------------------------------------------------------------- helpers ---

## Line of sight test for bot perception (same eyes as a human would have).
func line_of_sight(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, MapBuilder.WORLD_LAYER)
	return world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _timeline(text: String) -> void:
	timeline.append({"t": phases.elapsed, "text": text})


func _log(text: String) -> void:
	log_line.emit(text)
	print("[match] ", text)
