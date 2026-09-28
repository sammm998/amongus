extends Node3D
## M1 look-development vista "Sunset Cove" (GAME_SPEC §2, §10 M1): reproduces the
## mood of docs/art/reference.png with procedural geometry and custom shaders.
## Controls: F toggles fly camera (WASD + mouse, Q/E down/up), 1-6 render presets.

const MAP_FILE := "res://data/maps/sunset_cove.json"

var field: HeightField
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var camera: Camera3D
var _map: Dictionary
var _rng := RandomNumberGenerator.new()
var _walkers: Array = []
var _fly := false
var _yaw := 0.0
var _pitch := 0.0
var _time := 0.0
var _hud: Label


func _ready() -> void:
	_map = GameDataRegistry.read_json(MAP_FILE)
	_rng.seed = 4242
	field = HeightField.new(_map["terrain"])
	var to_sun := _vec3(_map["sun_direction"])
	var rig := SunsetEnvironment.build(to_sun)
	world_env = rig["environment"]
	sun = rig["sun"]
	add_child(world_env)
	add_child(sun)
	_build_terrain()
	var sea := WaterFactory.sea(3000.0, to_sun, 160)
	add_child(sea)
	var near: Dictionary = _map["near_terrain"]
	WaterFactory.bake_depth(sea, field, Rect2(_vec2(near["origin"]), _vec2(near["size"])), 1.0)
	_build_landmarks()
	_scatter_vegetation()
	_scatter_rocks()
	_build_foreground_frame()
	_spawn_astronauts()
	_build_camera()
	_build_hud()
	var presets: Dictionary = GameData.table("render_presets")
	var preset: String = GameData.args["preset"]
	apply_preset(preset if not preset.is_empty() else RenderPresets.default_name(presets))
	if GameData.args["measure_fps"] > 0.0:
		_measure_fps(GameData.args["measure_fps"])


func apply_preset(preset_name: String) -> void:
	var presets: Dictionary = GameData.table("render_presets")["presets"]
	if not presets.has(preset_name):
		return
	RenderPresets.apply(presets[preset_name], world_env.environment, sun, get_viewport())
	if _hud != null:
		_hud.set_meta("preset", preset_name)


## Prints the average frame rate over `seconds` (after a 2 s warm-up) and quits.
func _measure_fps(seconds: float) -> void:
	await get_tree().create_timer(2.0).timeout
	var frames := Engine.get_frames_drawn()
	var start := Time.get_ticks_msec()
	await get_tree().create_timer(seconds).timeout
	var fps := (Engine.get_frames_drawn() - frames) / ((Time.get_ticks_msec() - start) / 1000.0)
	print("FPS_RESULT preset=%s avg=%.1f adapter=%s" % [GameData.args["preset"], fps, RenderingServer.get_video_adapter_name()])
	get_tree().quit()


func ground(x: float, z: float) -> float:
	return field.height_at(x, z)


func _build_terrain() -> void:
	var builder := TerrainMeshBuilder.new()
	for key: String in ["near_terrain", "far_terrain"]:
		var t: Dictionary = _map[key]
		var mesh := builder.build_mesh(field, _vec2(t["origin"]), _vec2(t["size"]), int(t["res"]))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)


func _build_landmarks() -> void:
	# Airfield: runway, two curved-roof hangars, small jets.
	var runway := StructureBuilder.airstrip(150.0, 18.0)
	runway.position = Vector3(95, ground(95, -95) + 0.02, -95)
	add_child(runway)
	for h: Array in [[62.0, -132.0], [98.0, -136.0], [134.0, -132.0]]:
		var hangar := StructureBuilder.hangar(22.0, 26.0, 4.5)
		hangar.position = Vector3(h[0], ground(h[0], h[1]), h[1])
		add_child(hangar)
	for j: Array in [[70.0, -97.0, 1.3], [92.0, -93.0, 1.5], [118.0, -98.0, 1.2]]:
		var jet := VehicleProps.small_jet()
		jet.position = Vector3(j[0], ground(j[0], j[1]), j[1])
		jet.rotation.y = j[2]
		add_child(jet)
	# Base buildings on the rise behind the beach.
	var accents := [StructureBuilder.NAVY, Color(0.2, 0.55, 0.55), Color(0.45, 0.45, 0.3)]
	var buildings := [[-2.0, -96.0, 0.2, 2], [18.0, -104.0, -0.3, 1], [-18.0, -110.0, 0.5, 3], [30.0, -88.0, 0.1, 1]]
	for i in buildings.size():
		var b: Array = buildings[i]
		var node := StructureBuilder.command_building(14.0 - i, 10.0, b[3], accents[i % accents.size()])
		node.position = Vector3(b[0], ground(b[0], b[1]) - 0.3, b[1])
		node.rotation.y = b[2]
		add_child(node)
	# Radio tower on the promontory.
	var tower := StructureBuilder.radio_tower(44.0)
	tower.position = Vector3(20, ground(20, -180), -180)
	add_child(tower)
	# Pier into the cove with the boat moored at its end.
	var pier := StructureBuilder.pier(40.0, 3.4)
	pier.position = Vector3(44, -0.2, -26)
	pier.rotation.y = deg_to_rad(100.0)
	add_child(pier)
	var boat := VehicleProps.boat()
	boat.position = Vector3(72, 0.05, -24)
	boat.rotation.y = deg_to_rad(15.0)
	add_child(boat)
	# Lamps along the beach path.
	for l: Array in [[12.0, -38.0], [24.0, -58.0], [36.0, -76.0], [-4.0, -60.0]]:
		var lamp := StructureBuilder.lamp_post()
		lamp.position = Vector3(l[0], ground(l[0], l[1]), l[1])
		add_child(lamp)
	# Waterfall down the jungle cliff + volcano smoke + sea stacks.
	var fall := WaterFactory.waterfall(7.0, 28.0)
	fall.position = Vector3(-70, ground(-70, -96) + 12.0, -96)
	fall.rotation.y = deg_to_rad(25.0)
	add_child(fall)
	var smoke := SmokePlume.create(9.0, Color(0.72, 0.62, 0.66, 0.7))
	smoke.position = Vector3(-20, ground(-20, -560) - 10.0, -560)
	add_child(smoke)
	for s: Array in [[190.0, -230.0, 9.0, 30.0], [230.0, -280.0, 7.0, 22.0], [160.0, -300.0, 6.0, 18.0], [260.0, -200.0, 5.0, 12.0]]:
		var stack := MeshInstance3D.new()
		stack.mesh = RockBuilder.rock(_rng, Vector3(s[2], s[3], s[2]), 0.7)
		stack.position = Vector3(s[0], -2.0, s[1])
		add_child(stack)


func _scatter_vegetation() -> void:
	var palm_variants: Array[Node3D] = []
	for i in 4:
		palm_variants.append(VegetationBuilder.palm(_rng, 8.0 + i * 1.6))
	var bush_meshes := [VegetationBuilder.bush(_rng, 1.6), VegetationBuilder.bush(_rng, 2.4)]
	var fern_mesh := VegetationBuilder.fern(_rng, 1.2)
	var bushes := MultiMesh.new()
	bushes.transform_format = MultiMesh.TRANSFORM_3D
	bushes.mesh = bush_meshes[0]
	var big_bushes := MultiMesh.new()
	big_bushes.transform_format = MultiMesh.TRANSFORM_3D
	big_bushes.mesh = bush_meshes[1]
	var ferns := MultiMesh.new()
	ferns.transform_format = MultiMesh.TRANSFORM_3D
	ferns.mesh = fern_mesh
	var bush_xf: Array[Transform3D] = []
	var big_xf: Array[Transform3D] = []
	var fern_xf: Array[Transform3D] = []
	var palms := 0
	var area := Rect2(-200, -260, 420, 330)
	for i in 9000:
		var x := area.position.x + _rng.randf() * area.size.x
		var z := area.position.y + _rng.randf() * area.size.y
		if _near_structures(x, z):
			continue
		var h := ground(x, z)
		var n := field.normal_at(x, z, 1.0)
		if h < 1.0 or n.y < 0.72:
			continue
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.4)), Vector3(x, h - 0.1, z))
		var beach := h < 2.4
		var r := _rng.randf()
		if (beach and h > 1.4 and r < 0.025) or (not beach and r < 0.035):
			if palms < 170:
				var palm := palm_variants[palms % palm_variants.size()].duplicate()
				palm.position = Vector3(x, h - 0.2, z)
				palm.rotation.y = _rng.randf() * TAU
				palm.scale = Vector3.ONE * _rng.randf_range(0.85, 1.2)
				add_child(palm)
				palms += 1
		elif not beach and r < 0.52:
			bush_xf.append(xf)
		elif not beach and r < 0.7:
			big_xf.append(xf.scaled_local(Vector3.ONE * _rng.randf_range(1.2, 2.2)))
		elif not beach and r < 0.8:
			fern_xf.append(xf)
	_fill(bushes, bush_xf)
	_fill(big_bushes, big_xf)
	_fill(ferns, fern_xf)
	for mm: MultiMesh in [bushes, big_bushes, ferns]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	for v in palm_variants:
		v.free()


func _scatter_rocks() -> void:
	var meshes: Array[ArrayMesh] = []
	for i in 6:
		meshes.append(RockBuilder.rock(_rng, Vector3(1.0, 0.75, 1.0)))
	var placed := 0
	var tries := 0
	while placed < 140 and tries < 6000:
		tries += 1
		var x := _rng.randf_range(-160.0, 200.0)
		var z := _rng.randf_range(-230.0, 60.0)
		var h := ground(x, z)
		var n := field.normal_at(x, z)
		# Rocks gather along the shoreline, on steep slopes and underwater reefs.
		var shoreline := h > -2.5 and h < 1.2
		if not (shoreline or n.y < 0.8) or _near_structures(x, z):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[placed % meshes.size()]
		var s := _rng.randf_range(0.8, 3.2) * (1.6 if shoreline and _rng.randf() < 0.2 else 1.0)
		mi.scale = Vector3(s, s * _rng.randf_range(0.7, 1.1), s)
		mi.rotation.y = _rng.randf() * TAU
		mi.position = Vector3(x, h - 0.3 * s, z)
		add_child(mi)
		placed += 1


## Big foreground palm trunk + leaves framing the left of the shot, like the reference.
func _build_foreground_frame() -> void:
	var cam: Dictionary = _map["camera"]
	var pos := _vec3(cam["position"])
	var yaw := deg_to_rad(float(cam["yaw_degrees"]))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var trunk_at := pos + fwd * 6.5 - right * 4.2
	var palm := VegetationBuilder.palm(_rng, 14.0)
	palm.position = Vector3(trunk_at.x, ground(trunk_at.x, trunk_at.z) - 0.5, trunk_at.z)
	add_child(palm)
	for i in 7:
		var at := pos + fwd * (4.0 + i * 0.9) - right * (3.5 - i * 0.45)
		var b := MeshInstance3D.new()
		b.mesh = VegetationBuilder.bush(_rng, 2.2 + _rng.randf() * 0.8)
		b.position = Vector3(at.x, ground(at.x, at.z) - 0.2, at.z)
		b.rotation.y = _rng.randf() * TAU
		add_child(b)


func _spawn_astronauts() -> void:
	var looks := [
		[Color(0.96, 0.96, 0.98), Color(1.0, 0.45, 0.72)],
		[Color(1.0, 0.7, 0.1), Color(1.0, 0.48, 0.12)],
		[Color(0.95, 0.95, 0.98), Color(0.35, 0.75, 1.0)],
	]
	var base := _vec3(_map["astronaut_area"])
	var starts := [base + Vector3(0.0, 0, 1.5), base + Vector3(2.2, 0, -0.8), base + Vector3(-1.8, 0, -3.0)]
	for i in looks.size():
		var a := Astronaut.new()
		a.suit_color = looks[i][0]
		a.accent_color = looks[i][1]
		a.phase_offset = i * 1.3
		add_child(a)
		_walkers.append({"node": a, "start": starts[i], "speed": 1.2 + i * 0.25, "t": i * 3.0})


func _build_camera() -> void:
	var cam: Dictionary = _map["camera"]
	camera = Camera3D.new()
	camera.fov = float(cam["fov"])
	camera.far = 3000.0
	add_child(camera)
	var pos := _vec3(cam["position"])
	pos.y = ground(pos.x, pos.z) + float(cam["height_above_ground"])
	camera.position = pos
	_yaw = deg_to_rad(float(cam["yaw_degrees"]))
	_pitch = deg_to_rad(float(cam["pitch_degrees"]))
	camera.rotation = Vector3(_pitch, _yaw, 0)
	camera.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud.add_theme_constant_override("outline_size", 5)
	_hud.visible = GameData.args["screenshot"].is_empty()
	_hud.text = "SUNSET COVE  ·  F: fly camera  ·  1 ultra 2 high 3 medium 4 mobile 5 low 6 battery  ·  Esc: back"
	layer.add_child(_hud)


func _process(delta: float) -> void:
	_time += delta
	for w: Dictionary in _walkers:
		var a: Astronaut = w["node"]
		w["t"] += delta
		# Stroll back and forth along the beach toward the water.
		var span := 5.0
		var phase: float = fmod(w["t"] * w["speed"] / span, 2.0)
		var forward := phase < 1.0
		var s := phase if forward else 2.0 - phase
		var dir := Vector3(0.6, 0, -0.8).normalized()
		var p: Vector3 = w["start"] + dir * s * span
		var pause := smoothstep(0.0, 0.08, s) * smoothstep(1.0, 0.92, s)
		a.move_blend = 0.45 * pause
		a.position = Vector3(p.x, ground(p.x, p.z), p.z)
		a.rotation.y = atan2(dir.x, dir.z) + (0.0 if forward else PI)
	if _fly:
		var input := Vector3(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			(1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0),
			Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
		var speed := 60.0 if Input.is_action_pressed("sprint") else 18.0
		camera.position += camera.global_basis * input * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				_fly = not _fly
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _fly else Input.MOUSE_MODE_VISIBLE
			KEY_1:
				apply_preset("ultra")
			KEY_2:
				apply_preset("high")
			KEY_3:
				apply_preset("medium")
			KEY_4:
				apply_preset("mobile")
			KEY_5:
				apply_preset("low")
			KEY_6:
				apply_preset("battery_saver")
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().change_scene_to_file("res://client/lobby/dev_lobby.tscn")
	if _fly and event is InputEventMouseMotion:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.4, 1.4)
		camera.rotation = Vector3(_pitch, _yaw, 0)


func _near_structures(x: float, z: float) -> bool:
	# Keep plants and rocks off the runway, hangars, base, pier and the astronauts' stroll.
	var stroll := _vec3(_map["astronaut_area"])
	if Vector2(x - stroll.x - 2.0, z - stroll.z + 2.0).length() < 9.0:
		return true
	if x > 25 and x < 175 and z > -150 and z < -80:
		return true
	if x > -30 and x < 45 and z > -120 and z < -80:
		return true
	if absf(x - 20) < 10 and absf(z + 180) < 10:
		return true
	return false


static func _fill(mm: MultiMesh, xfs: Array[Transform3D]) -> void:
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])


static func _vec3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _vec2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
