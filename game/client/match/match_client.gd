extends Node3D
## Client match scene: renders the world, predicts the local player,
## interpolates everyone else and drives the HUD. All game truth comes from
## the server via NetworkManager.game (ClientGameState).

const INTERP_DELAY := 0.1
const LOBBY_SCENE := "res://client/lobby/dev_lobby.tscn"
const MOVE_PHASES := ["WAITING", "COUNTDOWN", "ACTIVE", "RESUMING"]

var game: ClientGameState
var map: MapData
var world: Node3D
var local: LocalPlayer
var hud: MatchHUD
var touch_state := TouchInputState.new()
var avatars: Dictionary = {}   # id -> RemoteAvatar
var loot_nodes: Dictionary = {}  # loot id -> Node3D
var district_lights: Dictionary = {}
var _tag_timer := 0.0
var _los_cache: Dictionary = {}
var _spectate_index := 0
var _last_ack := 0
var _teleport_pending := true
var _tracers: Array = []  # [MeshInstance3D, life]


func _ready() -> void:
	game = NetworkManager.game
	var map_id: String = game.info.get("map", "slice")
	map = MapData.load_map(map_id)
	var tod := EnvironmentRig.preset(str(game.info.get("time_of_day", "day")))
	var rig := EnvironmentRig.build(tod)
	add_child(rig["environment"])
	add_child(rig["sun"])
	world = MapBuilder.build(map, true)
	add_child(world)
	district_lights = world.get_meta("district_lights")
	var sea: MeshInstance3D = world.get_node_or_null("Sea")
	if sea != null:
		var wm: ShaderMaterial = sea.material_override
		wm.set_shader_parameter("sun_direction", rig["sky_sun"])
		wm.set_shader_parameter("body_glow", float(tod["water_glow"]))
		if str(game.info.get("time_of_day", "day")) != "sunset":
			wm.set_shader_parameter("shallow_color", Color(0.36, 0.8, 0.76))
			wm.set_shader_parameter("mid_color", Color(0.05, 0.48, 0.64))
			wm.set_shader_parameter("deep_color", Color(0.03, 0.2, 0.4))
			wm.set_shader_parameter("glint_color", Color(1.0, 0.98, 0.92))
	var presets: Dictionary = GameData.table("render_presets")
	var preset: String = GameData.args["preset"] if not String(GameData.args["preset"]).is_empty() else RenderPresets.default_name(presets)
	RenderPresets.apply(presets["presets"][preset], rig["environment"].environment, rig["sun"], get_viewport())
	var colors := UIKit.suit_colors(game.player_color(game.my_id()))
	local = LocalPlayer.new()
	local.name = "LocalPlayer"
	add_child(local)
	local.setup(game, map, touch_state, colors[0], colors[1])
	local.remote_hitboxes = _remote_hitboxes
	var spawns := map.spawn_points()
	local.teleport(spawns[0] if not game.me.has("pos") else game.me["pos"])
	hud = MatchHUD.new()
	add_child(hud)
	var ghosts := Node3D.new()
	ghosts.name = "ReplayGhosts"
	add_child(ghosts)
	hud.setup(game, map, touch_state, world.get_meta("camera_points"), get_viewport().world_3d, ghosts, func() -> Vector3: return local.aim_point)
	sound = SoundPlayer.new()
	add_child(sound)
	game.chat_received.connect(_on_chat)
	game.world_changed.connect(_sync_doors)
	hud.leave_requested.connect(_leave)
	game.snapshot_received.connect(_on_snapshot)
	game.event_received.connect(_on_event)
	game.info_changed.connect(_on_info)
	NetworkManager.client_state_changed.connect(_on_connection)
	if NetworkManager.auto_start_requested:
		NetworkManager.auto_start_requested = false
		NetworkManager.send_action("start")
	# The pointer is locked on the first click (browsers require a user gesture).


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_connection(state: int) -> void:
	if state in [ClientSession.State.DISCONNECTED, ClientSession.State.FAILED, ClientSession.State.REJECTED]:
		_leave()


func _leave() -> void:
	NetworkManager.stop_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(LOBBY_SCENE)


func _on_info() -> void:
	# Match reset to the pre-game lobby, or role reveal -> ACTIVE spawn: resync.
	_teleport_pending = true


# ------------------------------------------------------------- per tick ---

func _physics_process(delta: float) -> void:
	if NetworkManager.client == null or not NetworkManager.client.is_connected_to_server():
		return
	var can_move := game.phase in MOVE_PHASES and not game.is_spectator() and game.my_state() != Vitals.State.ELIMINATED
	local.input_enabled = can_move and not hud.is_blocking_input()
	var inp := local.build_input(delta)
	inp.view_time = game.server_now(NetworkManager.local_time()) - INTERP_DELAY
	local.simulate(inp, not can_move)
	NetworkManager.client.send_game(Protocol.Msg.INPUT, inp.to_payload(), false)


func _on_snapshot(p: Dictionary) -> void:
	var me: Dictionary = p["me"]
	if not me.has("pos"):
		return
	var server_pos: Vector3 = me["pos"]
	var server_air := int(me.get("air", 0))
	var snap_distance := 6.0 if server_air == PlayerMotor.Air.NONE else 30.0
	if _teleport_pending or server_pos.distance_to(local.body.global_position) > snap_distance:
		_teleport_pending = false
		local.teleport(server_pos, me["vel"], server_air)
		return
	var frozen := not (game.phase in MOVE_PHASES) or game.is_spectator()
	local.reconcile(int(p["ack"]), server_pos, me["vel"], frozen, server_air)


const AIRBORNE_FLAGS := 256 | 512 | 1024
var _plane: Node3D


## Transport plane of the opening drop + the jump prompt.
func _update_drop() -> void:
	var d: Dictionary = game.info.get("drop", {})
	var t := game.server_now(NetworkManager.local_time())
	if d.is_empty() or t > float(d["end"]):
		if _plane != null:
			_plane.visible = false
		hud.set_drop_hint("")
		return
	if _plane == null:
		_plane = DropVisuals.plane()
		add_child(_plane)
	var dir: Vector3 = d["dir"]
	var pos: Vector3 = d["from"] + dir * float(d["speed"]) * (t - float(d["start"]))
	_plane.visible = true
	_plane.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), pos + Vector3(0, 1.0, 0))
	var hint := ""
	if local.air == PlayerMotor.Air.PLANE:
		var jump_key := "TAP JUMP" if InputRouter.mode == InputClassifier.Mode.TOUCH else "PRESS SPACE"
		hint = "%s TO JUMP" % jump_key if t >= float(d["t_open"]) else "OVER THE SEA — JUMP OPENS IN %d s" % ceili(float(d["t_open"]) - t)
	elif local.air == PlayerMotor.Air.FREEFALL:
		hint = "FREEFALL — steer with WASD, hold forward to dive"
	elif local.air == PlayerMotor.Air.CHUTE:
		hint = "PARACHUTE OPEN"
	hud.set_drop_hint(hint)


func _process(delta: float) -> void:
	var render_time := game.server_now(NetworkManager.local_time()) - INTERP_DELAY
	var sampled := game.sample_players(render_time)
	var latest := game.latest()
	var seen := {}
	for id: int in sampled:
		if id == game.my_id():
			continue
		var s: Array = sampled[id]
		var av := _avatar(id)
		av.apply(s[0], s[1], s[3], s[5], delta)
		av.set_emote(s[6], delta)
		if int(s[5]) & AIRBORNE_FLAGS == 0:
			_footsteps(av, s[0], delta)
		seen[id] = true
	for b: Array in latest.get("bodies", []):
		if b[0] == game.my_id():
			continue
		_avatar(b[0]).apply(b[1], b[2], Vitals.State.ELIMINATED, 0, delta)
		seen[b[0]] = true
	for id: int in avatars.keys():
		if not seen.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
	_update_loot(latest.get("loot", []), delta)
	_update_tags(delta)
	_update_lights()
	_update_tracers(delta)
	_update_evidence()
	_update_pings(delta)
	_update_drop()
	var spectating := game.is_spectator() or game.my_state() == Vitals.State.ELIMINATED
	local.avatar.visible = not game.is_spectator() and local.air != PlayerMotor.Air.PLANE
	var target := Vector3.INF
	if spectating and not avatars.is_empty():
		var living: Array = avatars.values().filter(func(a: RemoteAvatar) -> bool: return a.state == Vitals.State.ALIVE)
		if not living.is_empty():
			target = living[_spectate_index % living.size()].feet
	local.update_camera(delta, target)
	hud.set_meta("camera_yaw", local.yaw)
	var here := map.district_at(local.body.global_position)
	hud.update_hud(delta, local.body.global_position, local.yaw, game.district_dark(here))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not hud.cameras.visible:
		hud.toggle_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("chat") and not hud.is_blocking_input():
		hud.open_chat()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fire") and (game.is_spectator() or game.my_state() == Vitals.State.ELIMINATED):
		_spectate_index += 1
	elif event.is_action_pressed("full_map") and not hud.comms.visible and not hud.meeting_panel.visible:
		hud.toggle_map()
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("quick_chat") or event.is_action_pressed("emote")) and not hud.is_blocking_input():
		hud.open_comms()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ping") and not hud.is_blocking_input() and game.phase in MOVE_PHASES:
		var p := local.aim_point
		NetworkManager.send_action("ping", 0, "location|%f|%f|%f" % [p.x, p.y, p.z])
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------- visuals ---

func _avatar(id: int) -> RemoteAvatar:
	if avatars.has(id):
		return avatars[id]
	var a := RemoteAvatar.new()
	var colors := UIKit.suit_colors(game.player_color(id))
	add_child(a)
	a.setup(id, game.player_name(id), colors[0], colors[1])
	avatars[id] = a
	return a


func _remote_hitboxes() -> Array:
	var out: Array = []
	for a: RemoteAvatar in avatars.values():
		if a.state != Vitals.State.ELIMINATED:
			out.append([a.feet, a.hitbox_height()])
	return out


func _update_tags(delta: float) -> void:
	_tag_timer -= delta
	var eye := local.camera.global_position
	var max_d := 30.0
	if _tag_timer <= 0.0:
		_tag_timer = 0.2
		var space := get_world_3d().direct_space_state
		for a: RemoteAvatar in avatars.values():
			if eye.distance_to(a.feet) > max_d:
				_los_cache[a.player_id] = false
				continue
			var q := PhysicsRayQueryParameters3D.create(eye, a.feet + Vector3(0, 1.6, 0), MapBuilder.WORLD_LAYER)
			_los_cache[a.player_id] = space.intersect_ray(q).is_empty()
	for a: RemoteAvatar in avatars.values():
		a.update_tag(eye, max_d, _los_cache.get(a.player_id, false) and a.avatar.visible, game.is_suspect(a.player_id))


func _update_lights() -> void:
	for district: String in district_lights:
		var on := not game.district_dark(district)
		for l: Light3D in district_lights[district]:
			l.visible = on


func _update_loot(list: Array, delta: float) -> void:
	var seen := {}
	for l: Array in list:
		var id: int = l[0]
		seen[id] = true
		if not loot_nodes.has(id):
			var node := _loot_visual(l[1], l[2])
			node.position = l[3]
			add_child(node)
			loot_nodes[id] = node
		var n: Node3D = loot_nodes[id]
		n.rotation.y += delta * 1.2
	for id: int in loot_nodes.keys():
		if not seen.has(id):
			loot_nodes[id].queue_free()
			loot_nodes.erase(id)


func _loot_visual(item: String, rarity: String) -> Node3D:
	var kit := MeshKit.new()
	var rarities: Dictionary = GameData.table("combat")["rarities"]
	var rc := Color(rarities.get(rarity, rarities["standard"])["color"])
	var root := Node3D.new()
	if item.begins_with("ammo_"):
		kit.add_box(Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(0.5, 0.35, 0.35), Color(0.35, 0.45, 0.25))
		kit.add_box(Transform3D(Basis(), Vector3(0, 0.44, 0)), Vector3(0.52, 0.06, 0.37), Color(1.0, 0.8, 0.2))
	elif item in ["med_patch", "med_kit", "trauma_kit"]:
		kit.add_box(Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(0.45, 0.3, 0.3), Color.WHITE, MeshKit.SLOT_GLOSS)
		kit.add_box(Transform3D(Basis(), Vector3(0, 0.25, 0.16)), Vector3(0.2, 0.06, 0.02), Color.RED)
		kit.add_box(Transform3D(Basis(), Vector3(0, 0.25, 0.16)), Vector3(0.06, 0.2, 0.02), Color.RED)
	elif item == "shield_cell":
		kit.add_cylinder(Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.13, 0.13, 0.45, Color(0.3, 0.7, 1.0), 12, MeshKit.SLOT_GLOW_CYAN)
	else:
		kit.add_box(Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.9, 0.18, 0.12), Color(0.2, 0.22, 0.26), MeshKit.SLOT_METAL)
		kit.add_box(Transform3D(Basis(), Vector3(-0.15, 0.33, 0)), Vector3(0.14, 0.22, 0.1), Color(0.2, 0.22, 0.26))
		kit.add_box(Transform3D(Basis(), Vector3(0.1, 0.45, 0)), Vector3(0.5, 0.2, 0.14), rc, MeshKit.SLOT_GLOSS)
		var light := OmniLight3D.new()
		light.light_color = rc
		light.omni_range = 2.5
		light.light_energy = 1.2
		light.position = Vector3(0, 0.6, 0)
		root.add_child(light)
	var ring := MeshKit.new()
	ring.add_cylinder(Transform3D(Basis(), Vector3(0, 0.02, 0)), 0.55, 0.55, 0.02, rc, 20, MeshKit.SLOT_GLOW)
	root.add_child(ring.to_instance())
	root.add_child(kit.to_instance())
	return root


func _on_event(kind: String, data: Dictionary) -> void:
	match kind:
		"ping":
			_add_ping(data)
			sound.play("ping", -6.0)
			return
		"alert":
			sound.play("horn" if String(data["text"]).contains("MEETING") or String(data["text"]).contains("INCIDENT") else "alert", -4.0)
			return
		"hit":
			sound.play("hit", -8.0)
			return
		"task_step":
			sound.play("task", -6.0)
			return
		"downed", "eliminated":
			sound.play("down", -2.0)
			return
		"shot":
			pass
		_:
			return
	var shooter: int = data["shooter"]
	var family: String = data["family"]
	var origin: Vector3 = data["origin"]
	var audible := 400.0 if family == "sniper" else 250.0
	sound.play_at(SoundBank.shot_for_family(family), origin, audible, 0.0, randf_range(0.94, 1.06))
	if shooter > 0 and avatars.has(shooter):
		avatars[shooter].muzzle_flash()
	_tracer(data["origin"], data["end"], data["family"])


# ------------------------------------------------------------- M3 visuals ---

var sound: SoundPlayer
var _evidence_nodes: Dictionary = {}   # id -> Node3D
var _ping_nodes: Array = []            # [Node3D, time_left]
var _step_accum: Dictionary = {}       # player id -> metres since last footstep
var _local_step := 0.0
var _last_local := Vector3.ZERO


func _footsteps(av: RemoteAvatar, pos: Vector3, delta: float) -> void:
	var moved: float = Vector2(pos.x - av.get_meta("last_step_pos", pos).x, pos.z - av.get_meta("last_step_pos", pos).z).length()
	av.set_meta("last_step_pos", pos)
	if av.state != Vitals.State.ALIVE or moved > 3.0:
		return
	var acc := float(_step_accum.get(av.player_id, 0.0)) + moved
	if acc > 1.6:
		acc = 0.0
		if local.camera.global_position.distance_to(pos) < 30.0:
			sound.play_at("footstep", pos, 30.0, -10.0, randf_range(0.85, 1.15))
	_step_accum[av.player_id] = acc


func _update_evidence() -> void:
	var seen := {}
	for e: Array in game.evidence:
		var id: int = e[0]
		seen[id] = true
		if _evidence_nodes.has(id):
			continue
		var mi := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		if e[1] == "casing":
			var m := CylinderMesh.new()
			m.top_radius = 0.025
			m.bottom_radius = 0.025
			m.height = 0.08
			mat.albedo_color = Color(0.85, 0.65, 0.25)
			mat.metallic = 0.8
			mat.roughness = 0.3
			m.material = mat
			mi.mesh = m
			mi.rotation = Vector3(PI * 0.5, randf() * TAU, 0)
		else:
			var m := CylinderMesh.new()
			m.top_radius = 0.09
			m.bottom_radius = 0.09
			m.height = 0.01
			mat.albedo_color = Color(0.08, 0.08, 0.08, 0.8)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.material = mat
			mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = e[2]
		_evidence_nodes[id] = mi
	for id: int in _evidence_nodes.keys():
		if not seen.has(id):
			_evidence_nodes[id].queue_free()
			_evidence_nodes.erase(id)


func _add_ping(data: Dictionary) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = data["pos"]
	var colors := {"danger": UITheme.DANGER, "suspicious": UITheme.AMBER}
	var col: Color = colors.get(data["ping"], UITheme.CYAN)
	var l := Label3D.new()
	l.text = "%s\n%s" % [String(data["ping"]).to_upper(), data["name"]]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = 28
	l.modulate = col
	l.outline_size = 8
	l.position = Vector3(0, 1.6, 0)
	root.add_child(l)
	var beam := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.05
	m.bottom_radius = 0.05
	m.height = 3.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	beam.mesh = m
	beam.position = Vector3(0, 1.5, 0)
	root.add_child(beam)
	var life := float(GameData.table("info_systems")["ping_lifetime_seconds"])
	_ping_nodes.append([root, life])
	hud.full_map.pings.append([data["pos"], data["ping"], data["name"], life])


func _update_pings(delta: float) -> void:
	for p: Array in _ping_nodes.duplicate():
		p[1] -= delta
		if p[1] <= 0.0:
			(p[0] as Node).queue_free()
			_ping_nodes.erase(p)
	for p: Array in hud.full_map.pings.duplicate():
		p[3] -= delta
		if p[3] <= 0.0:
			hud.full_map.pings.erase(p)
	# Local footsteps.
	var pos := local.body.global_position
	var moved := Vector2(pos.x - _last_local.x, pos.z - _last_local.z).length()
	_last_local = pos
	if moved < 3.0 and local.body.is_on_floor():
		_local_step += moved
		if _local_step > 1.7:
			_local_step = 0.0
			sound.play("footstep", -14.0, randf_range(0.9, 1.1))


func _on_chat(p: Dictionary) -> void:
	if p["channel"] == CommsRules.PROXIMITY and avatars.has(p["from"]):
		avatars[p["from"]].say(p["text"], float(GameData.table("info_systems")["bubble_seconds"]))


func _sync_doors() -> void:
	var locked: Array = game.world.get("doors", [])
	for b: String in map.raw.get("lockable_buildings", []):
		MapBuilder.set_doors_locked(world, b, b in locked)


func _tracer(from: Vector3, to: Vector3, family: String) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, length)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.8) if family != "sniper" else Color(1.0, 0.4, 0.3, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)
	_tracers.append([mi, 0.08 if family != "sniper" else 0.4])


func _update_tracers(delta: float) -> void:
	for t: Array in _tracers.duplicate():
		t[1] -= delta
		if t[1] <= 0.0:
			(t[0] as Node).queue_free()
			_tracers.erase(t)
