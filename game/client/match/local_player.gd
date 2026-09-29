class_name LocalPlayer
extends Node3D
## The player's own character: samples input (desktop, controller, touch),
## predicts movement with the shared PlayerMotor, reconciles with server
## snapshots, and drives the over-the-shoulder camera (GAME_SPEC §4, §8.1).

signal fired

const SHOULDER := Vector3(0.55, 1.55, 0.0)
const AIM_SHOULDER := Vector3(0.62, 1.5, 0.0)
const ARM_LENGTH := 3.3
const AIM_ARM_LENGTH := 1.5
const FOV := 70.0
const AIM_FOV := 50.0
const RECONCILE_ERROR := 0.3

var body: CharacterBody3D
var avatar: Astronaut
var camera: Camera3D
var touch: TouchInputState
var game: ClientGameState
var map: MapData
var motor: PlayerMotor
var movement_cfg: Dictionary
var yaw := 0.0
var pitch := -0.1
var mouse_sensitivity := 0.0025
var stick_sensitivity := 2.6
var _captured_at := 0
var seq := 0
var history: Array = []   # [[seq, PlayerInput, pos_after]]
var slot_request := -1
var flashlight_on := false
var crouch_toggle := false
var input_enabled := true
var aiming := false
var aim_point := Vector3.ZERO
var remote_hitboxes: Callable   # () -> Array of [feet: Vector3, height: float]

var _yaw_pivot: Node3D
var _pitch_pivot: Node3D
var _arm: SpringArm3D
var _flashlight: SpotLight3D
var _aim_blend := 0.0


func setup(p_game: ClientGameState, p_map: MapData, p_touch: TouchInputState, suit: Color, accent: Color) -> void:
	game = p_game
	map = p_map
	touch = p_touch
	movement_cfg = GameData.table("movement")
	motor = PlayerMotor.new(movement_cfg)
	body = PlayerMotor.make_body(movement_cfg)
	body.name = "LocalBody"
	add_child(body)
	avatar = Astronaut.new()
	avatar.suit_color = suit
	avatar.accent_color = accent
	body.add_child(avatar)
	_flashlight = SpotLight3D.new()
	_flashlight.spot_range = 28.0
	_flashlight.spot_angle = 28.0
	_flashlight.light_energy = 4.0
	_flashlight.light_color = Color(1.0, 0.95, 0.85)
	_flashlight.position = Vector3(0.2, 1.4, -0.3)
	_flashlight.visible = false
	body.add_child(_flashlight)
	_yaw_pivot = Node3D.new()
	add_child(_yaw_pivot)
	_pitch_pivot = Node3D.new()
	_yaw_pivot.add_child(_pitch_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = ARM_LENGTH
	_arm.collision_mask = MapBuilder.WORLD_LAYER
	_arm.margin = 0.2
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	_arm.shape = shape
	_pitch_pivot.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 2500.0
	camera.cull_mask = 0xFFFFF
	_arm.add_child(camera)
	camera.make_current()


func teleport(pos: Vector3) -> void:
	body.global_position = pos
	body.velocity = Vector3.ZERO
	history.clear()


# ----------------------------------------------------------------- input ---

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Capturing the pointer (and browsers' pointer lock) can emit one huge
		# jump; ignore implausible deltas so the camera doesn't flip.
		if event.relative.length() > 250.0 or Time.get_ticks_msec() - _captured_at < 150:
			return
		var sens := mouse_sensitivity * (0.6 if aiming else 1.0)
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens, -1.3, 0.9)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and InputRouter.mode == InputClassifier.Mode.DESKTOP:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_captured_at = Time.get_ticks_msec()
		get_viewport().set_input_as_handled()
	for i in 5:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			slot_request = i
	if event.is_action_pressed("swap_weapon"):
		slot_request = _next_slot()
	if event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on


func _next_slot() -> int:
	var inv: Dictionary = game.me.get("inv", {})
	var ws: Array = inv.get("weapons", [])
	var active: int = inv.get("active", Inventory.SIDEARM)
	for step in range(1, 5):
		var s := (active + step) % 5
		if s == Inventory.HEALING or (s < ws.size() and not ws[s].is_empty()):
			return s
	return active


func build_input(dt: float) -> PlayerInput:
	var inp := PlayerInput.new()
	seq += 1
	inp.seq = seq
	inp.dt = dt
	if input_enabled:
		var move := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		if touch != null and touch.move.length() > 0.05:
			move = touch.move
		inp.move = move.limit_length(1.0)
		var look := Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
		if look.length() > 0.1:
			yaw -= look.x * stick_sensitivity * dt * (0.5 if aiming else 1.0)
			pitch = clampf(pitch - look.y * stick_sensitivity * 0.7 * dt, -1.3, 1.1)
		if touch != null:
			var d := touch.consume_look()
			yaw -= d.x * 0.006 * (0.55 if aiming else 1.0)
			pitch = clampf(pitch - d.y * 0.006, -1.3, 1.1)
			_apply_aim_assist(dt)
		var b := 0
		b |= PlayerInput.FIRE if (Input.is_action_pressed("fire") or _touch("fire")) else 0
		aiming = Input.is_action_pressed("aim") or _touch("aim")
		b |= PlayerInput.AIM if aiming else 0
		b |= PlayerInput.JUMP if (Input.is_action_pressed("jump") or _touch("jump")) else 0
		var sprint := Input.is_action_pressed("sprint") or (touch != null and touch.sprint)
		b |= PlayerInput.SPRINT if sprint else 0
		if touch != null and touch.take_pressed("crouch"):
			crouch_toggle = not crouch_toggle
		var crouch := Input.is_action_pressed("crouch") or crouch_toggle
		b |= PlayerInput.CROUCH if crouch else 0
		b |= PlayerInput.RELOAD if (Input.is_action_pressed("reload") or _touch("reload")) else 0
		b |= PlayerInput.INTERACT if (Input.is_action_pressed("interact") or _touch("interact")) else 0
		if touch != null and touch.take_pressed("flashlight"):
			flashlight_on = not flashlight_on
		b |= PlayerInput.FLASHLIGHT if flashlight_on else 0
		inp.buttons = b
		if touch != null and touch.slot_request >= 0:
			slot_request = touch.slot_request
			touch.slot_request = -1
		inp.slot = slot_request
		slot_request = -1
	inp.yaw = yaw
	inp.pitch = pitch
	inp.aim_point = aim_point
	return inp


func _touch(action: String) -> bool:
	return touch != null and touch.is_held(action)


## Touch aim assist: slow the look near targets and pull gently — never a hard lock.
func _apply_aim_assist(dt: float) -> void:
	if not remote_hitboxes.is_valid():
		return
	var best_angle := deg_to_rad(6.0)
	var best_yaw := 0.0
	var found := false
	var eye := camera.global_position
	var fwd := -camera.global_basis.z
	for hb: Array in remote_hitboxes.call():
		var chest: Vector3 = hb[0] + Vector3(0, float(hb[1]) * 0.6, 0)
		var to := chest - eye
		if to.length() > 60.0:
			continue
		var ang := fwd.angle_to(to.normalized())
		if ang < best_angle:
			best_angle = ang
			best_yaw = atan2(-to.x, -to.z)
			found = true
	if found:
		yaw = lerp_angle(yaw, best_yaw, clampf(dt * 1.5, 0.0, 0.08))


# ------------------------------------------------------------ simulation ---

func simulate(inp: PlayerInput, frozen: bool) -> void:
	var state_id := game.my_state()
	var downed := state_id == Vitals.State.DOWNED
	var state := {"frozen": frozen, "downed": downed, "stunned": float(game.me.get("stun", 0.0)) > 0.0, "crouching": inp.has(PlayerInput.CROUCH) and not downed}
	motor.step(body, inp, state, inp.dt)
	history.append([inp.seq, inp, body.global_position])
	if history.size() > 180:
		history.pop_front()
	var v := Vector2(body.velocity.x, body.velocity.z)
	avatar.move_blend = clampf(v.length() / float(movement_cfg["sprint_speed"]), 0.0, 1.0)
	avatar.downed = downed
	avatar.rotation.y = lerp_angle(avatar.rotation.y, yaw + PI, 0.35)
	_flashlight.visible = flashlight_on


## Server correction: rewind to the acknowledged state and replay newer inputs.
func reconcile(ack: int, server_pos: Vector3, server_vel: Vector3, frozen: bool) -> void:
	while not history.is_empty() and int(history[0][0]) < ack:
		history.pop_front()
	var predicted := server_pos
	if not history.is_empty() and int(history[0][0]) == ack:
		predicted = history[0][2]
		history.pop_front()
	elif history.is_empty():
		predicted = body.global_position
	if predicted.distance_to(server_pos) <= RECONCILE_ERROR:
		return
	body.global_position = server_pos
	body.velocity = server_vel
	var downed := game.my_state() == Vitals.State.DOWNED
	for h: Array in history:
		var inp: PlayerInput = h[1]
		motor.step(body, inp, {"frozen": frozen, "downed": downed, "crouching": inp.has(PlayerInput.CROUCH)}, inp.dt)
		h[2] = body.global_position


func update_camera(delta: float, spectate_target: Vector3 = Vector3.INF) -> void:
	_aim_blend = move_toward(_aim_blend, 1.0 if aiming else 0.0, delta * 6.0)
	var anchor := body.global_position if spectate_target == Vector3.INF else spectate_target
	var crouch := 0.35 if (int(game.me.get("state", 0)) == Vitals.State.ALIVE and bool(game.me.get("crouch", false))) else 0.0
	var shoulder := SHOULDER.lerp(AIM_SHOULDER, _aim_blend) - Vector3(0, crouch, 0)
	_yaw_pivot.global_position = anchor + Basis(Vector3.UP, yaw) * Vector3(shoulder.x, 0, 0) + Vector3(0, shoulder.y, 0)
	_yaw_pivot.rotation = Vector3(0, yaw, 0)
	_pitch_pivot.rotation = Vector3(pitch, 0, 0)
	_arm.spring_length = lerpf(ARM_LENGTH, AIM_ARM_LENGTH, _aim_blend)
	_arm.add_excluded_object(body.get_rid())
	camera.fov = lerpf(FOV, AIM_FOV, _aim_blend)
	_update_aim_point()


## Point under the crosshair. The ray starts at the player's depth so walls
## between the camera and the character never block shots (GAME_SPEC §12).
func _update_aim_point() -> void:
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var start := from + dir * maxf(0.0, (body.global_position + Vector3(0, 1.4, 0) - from).dot(dir))
	var to := start + dir * 300.0
	var q := PhysicsRayQueryParameters3D.create(start, to, MapBuilder.WORLD_LAYER)
	q.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var best := to
	var best_d := start.distance_to(to)
	if not hit.is_empty():
		best = hit["position"]
		best_d = start.distance_to(best)
	if remote_hitboxes.is_valid():
		for hb: Array in remote_hitboxes.call():
			var r := HitscanMath.ray_capsule(start, dir, hb[0], hb[1], 0.4)
			if r >= 0.0 and r < best_d:
				best_d = r
				best = start + dir * r
	aim_point = best


func eye_position() -> Vector3:
	return body.global_position + Vector3(0, 1.45, 0)
