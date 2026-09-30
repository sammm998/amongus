class_name VehicleMotor
extends RefCounted
## Arcade vehicle physics shared by server and tests: cars drive on the
## terrain, prop planes taxi, take off, fly toward where the pilot looks and
## land. Works on a CharacterBody3D (world collision); numbers from
## data/vehicles.json. `ground` returns the terrain height at (x, z).

const GRAVITY := 18.0

var cfg: Dictionary
var ground: Callable


func _init(type_cfg: Dictionary, ground_height: Callable = Callable()) -> void:
	cfg = type_cfg
	ground = ground_height


## state: {yaw, pitch, speed, airborne} (mutated). Input: move.y throttle,
## move.x steer, yaw/pitch = where the pilot looks (planes), SPRINT = boost (cars).
## Returns {"crash": impact damage taken this step (0 = none)}.
func step(body: CharacterBody3D, state: Dictionary, input: PlayerInput, dt: float) -> Dictionary:
	if cfg["kind"] == "plane":
		return _plane(body, state, input, dt)
	return _car(body, state, input, dt)


func _car(body: CharacterBody3D, state: Dictionary, input: PlayerInput, dt: float) -> Dictionary:
	var speed: float = state["speed"]
	var throttle := input.move.y if input != null else 0.0
	var steer := input.move.x if input != null else 0.0
	var top := float(cfg["max_speed"]) * (float(cfg["boost_multiplier"]) if input != null and input.has(PlayerInput.SPRINT) else 1.0)
	speed = _throttle(speed, throttle, top, float(cfg["reverse_speed"]), dt)
	var grip := clampf(absf(speed) / 6.0, 0.0, 1.0) * signf(speed)
	state["yaw"] = wrapf(float(state["yaw"]) - steer * float(cfg["turn_rate"]) * grip * dt, -PI, PI)
	var fwd := forward(state["yaw"], 0.0)
	# Never drive into deep water.
	var ahead := body.global_position + fwd * signf(speed) * 2.5
	if _ground(ahead) < -0.6:
		speed = 0.0
	body.velocity = fwd * speed
	body.move_and_slide()  # buildings and props only (STRUCTURE layer)
	var crash := 0.0
	if body.get_slide_collision_count() > 0:
		if absf(speed) > float(cfg["crash_speed"]):
			crash = float(cfg["crash_damage"])
		speed *= 0.4
	# Follow the terrain: fall under gravity, never sink below the ground.
	var pos := body.global_position
	var vy := float(state.get("vy", 0.0)) - GRAVITY * dt
	pos.y += vy * dt
	var gh := _ground(pos)
	if pos.y <= gh:
		pos.y = gh
		vy = 0.0
	body.global_position = pos
	state["vy"] = vy
	state["speed"] = speed
	state["pitch"] = 0.0
	state["airborne"] = false
	body.rotation = Vector3(0, state["yaw"], 0)
	return {"crash": crash}


func _plane(body: CharacterBody3D, state: Dictionary, input: PlayerInput, dt: float) -> Dictionary:
	var speed: float = state["speed"]
	var airborne: bool = state["airborne"]
	var throttle := input.move.y if input != null else 0.0
	speed = _throttle(speed, throttle, float(cfg["max_speed"]), 0.0, dt)
	var yaw: float = state["yaw"]
	var pitch: float = state["pitch"]
	var max_pitch := float(cfg["max_pitch"])
	if airborne:
		# Fly toward the pilot's view; A/D add extra yaw.
		var want_yaw := input.yaw if input != null else yaw
		var dyaw := wrapf(want_yaw - yaw, -PI, PI)
		if input != null:
			dyaw -= input.move.x * 0.6
		yaw = wrapf(yaw + clampf(dyaw, -1.0, 1.0) * float(cfg["turn_rate"]) * dt, -PI, PI)
		var want_pitch := clampf((input.pitch + 0.12) if input != null else 0.0, -max_pitch, max_pitch)
		if speed < float(cfg["stall_speed"]):
			want_pitch = -max_pitch * 0.8  # stall: the nose drops
		pitch = move_toward(pitch, want_pitch, float(cfg["pitch_rate"]) * dt)
		if body.global_position.y > float(cfg["ceiling_m"]):
			pitch = minf(pitch, 0.0)
	else:
		var steer := input.move.x if input != null else 0.0
		yaw = wrapf(yaw - steer * float(cfg["ground_turn_rate"]) * clampf(speed / 8.0, 0.0, 1.0) * dt, -PI, PI)
		pitch = 0.0
		if speed >= float(cfg["takeoff_speed"]) and input != null and (input.pitch > 0.05 or throttle > 0.5):
			pitch = 0.18
			airborne = true
	var vel := forward(yaw, pitch) * speed
	if airborne and speed < float(cfg["stall_speed"]):
		vel.y -= GRAVITY * 0.5
	if not airborne:
		vel.y = 0.0
	body.velocity = vel
	body.move_and_slide()  # buildings and props only (STRUCTURE layer)
	var crash := 0.0
	if body.get_slide_collision_count() > 0 and speed > float(cfg["crash_speed"]) * 0.5:
		crash = float(cfg["crash_damage"])
		speed *= 0.2
	var pos := body.global_position
	var gh := _ground(pos)
	if pos.y <= gh:
		pos.y = gh
		if airborne and float(state.get("lift_time", 0.0)) > 1.0:
			# Touchdown: gentle = landing, hard or nose-down = crash.
			if -vel.y > float(cfg["crash_vertical_speed"]) or pitch < -0.3:
				crash = float(cfg["crash_damage"])
			airborne = false
			pitch = 0.0
	body.global_position = pos
	state["lift_time"] = float(state.get("lift_time", 0.0)) + dt if airborne else 0.0
	state["speed"] = speed
	state["yaw"] = yaw
	state["pitch"] = pitch
	state["airborne"] = airborne
	body.rotation = Vector3(pitch, yaw, 0)
	return {"crash": crash}


## Terrain height under a point (sea floor stays below the water surface).
func _ground(p: Vector3) -> float:
	return float(ground.call(p.x, p.z)) if ground.is_valid() else 0.0


func _throttle(speed: float, throttle: float, top: float, reverse_top: float, dt: float) -> float:
	if throttle > 0.05:
		speed = minf(speed + float(cfg["acceleration"]) * throttle * dt, top) if speed >= 0.0 else speed + float(cfg["brake"]) * dt
	elif throttle < -0.05:
		speed = speed - float(cfg["brake"]) * -throttle * dt if speed > 0.0 else maxf(speed - float(cfg["acceleration"]) * -throttle * dt, -reverse_top)
	else:
		speed = move_toward(speed, 0.0, float(cfg["coast_drag"]) * dt)
	return clampf(speed, -reverse_top, top)


static func forward(yaw: float, pitch: float) -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


static func make_body(type_cfg: Dictionary) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 16  # MapBuilder.STRUCTURE_LAYER: buildings, props, boundary
	var s: Array = type_cfg["size"]
	var shape := BoxShape3D.new()
	shape.size = Vector3(s[0], s[1], s[2])
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = float(s[1]) * 0.5 + 0.1
	body.add_child(cs)
	return body
