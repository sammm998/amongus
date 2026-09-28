class_name PlayerMotor
extends RefCounted
## Deterministic character movement shared by server simulation and client
## prediction. Works on a CharacterBody3D; numbers from data/movement.json.

var cfg: Dictionary


func _init(movement_cfg: Dictionary) -> void:
	cfg = movement_cfg


## state: {crouching: bool, downed: bool, frozen: bool, stunned: bool, speed_mult: float}
func step(body: CharacterBody3D, input: PlayerInput, state: Dictionary, dt: float) -> void:
	var vel := body.velocity
	var on_floor := body.is_on_floor()
	var frozen: bool = state.get("frozen", false)
	var speed := target_speed(input, state)
	var basis := Basis(Vector3.UP, input.yaw)
	var wish := Vector3.ZERO
	if not frozen:
		wish = basis * Vector3(input.move.x, 0, -input.move.y)
	var accel := float(cfg["acceleration"]) if on_floor else float(cfg["air_acceleration"])
	var horizontal := Vector3(vel.x, 0, vel.z)
	horizontal = horizontal.move_toward(wish * speed, accel * dt)
	vel.x = horizontal.x
	vel.z = horizontal.z
	if on_floor:
		vel.y = minf(vel.y, 0.0)
		if input.has(PlayerInput.JUMP) and not frozen and not state.get("downed", false) and not state.get("stunned", false) and not state.get("crouching", false):
			vel.y = float(cfg["jump_velocity"])
	vel.y -= float(cfg["gravity"]) * dt
	body.velocity = vel
	body.floor_snap_length = 0.35
	body.floor_max_angle = deg_to_rad(50.0)
	body.move_and_slide()
	if not frozen:
		_step_up(body, wish, dt)


func target_speed(input: PlayerInput, state: Dictionary) -> float:
	if state.get("frozen", false) or state.get("stunned", false):
		return 0.0
	if state.get("downed", false):
		return float(cfg["crawl_speed"])
	var mult := float(state.get("speed_mult", 1.0))
	if state.get("crouching", false):
		return float(cfg["crouch_speed"]) * mult
	if input.has(PlayerInput.SPRINT) and input.move.y > 0.3 and not input.has(PlayerInput.AIM):
		return float(cfg["sprint_speed"]) * mult
	var run := float(cfg["run_speed"]) * mult
	return lerpf(float(cfg["walk_speed"]) * mult, run, clampf(input.move.length(), 0.0, 1.0))


## Small ledge step: when blocked on the floor, try stepping up `step_height`.
func _step_up(body: CharacterBody3D, wish: Vector3, dt: float) -> void:
	if wish.length() < 0.1 or not body.is_on_wall() or not body.is_on_floor():
		return
	var step_h := float(cfg["step_height"])
	var motion := wish.normalized() * maxf(0.08, float(cfg["run_speed"]) * dt)
	var up := Transform3D(body.global_basis, body.global_position + Vector3(0, step_h, 0))
	if body.test_move(body.global_transform, Vector3(0, step_h, 0)):
		return
	if body.test_move(up, motion):
		return
	body.global_position += Vector3(0, step_h, 0) + motion
	body.apply_floor_snap()


## Capsule + body used by both sides.
static func make_body(movement_cfg: Dictionary) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = float(movement_cfg["capsule_radius"])
	shape.height = float(movement_cfg["capsule_height"])
	var cs := CollisionShape3D.new()
	cs.name = "Capsule"
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	body.add_child(cs)
	return body
