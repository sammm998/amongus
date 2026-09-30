extends GdUnitTestSuite
## Drivable vehicles on the island: enter with the vehicle button, drive a
## buggy, take off in a prop plane and bail out with a parachute.

const DT := 1.0 / 30.0

var _m: MatchServer
var _p: ServerPlayer
var _seq := 0


func before_test() -> void:
	_m = MatchServer.new()
	add_child(_m)
	_m.set_physics_process(false)
	_m.setup("island", "standard", {}, 7)
	_p = _m._create_player(100, "Tester", false)


func after_test() -> void:
	_m.queue_free()


func _vehicle_of_type(type_id: String) -> ServerVehicle:
	for v: ServerVehicle in _m.vehicles.values():
		if v.type_id == type_id:
			return v
	return null


func _tick(move: Vector2, buttons: int, frames: int, pitch: float = 0.0, yaw: float = NAN) -> void:
	for i in frames:
		var inp := PlayerInput.new()
		_seq += 1
		inp.seq = _seq
		inp.move = move
		inp.buttons = buttons
		inp.pitch = pitch
		inp.yaw = _p.yaw if is_nan(yaw) else yaw
		inp.dt = DT
		_p.input_queue.append(inp)
		_m.tick(DT)


func _board(v: ServerVehicle) -> void:
	await get_tree().physics_frame
	_p.body.global_position = v.body.global_position + Vector3(2.0, 0.5, 0)
	_tick(Vector2.ZERO, 0, 10)
	_tick(Vector2.ZERO, PlayerInput.VEHICLE, 1)
	_tick(Vector2.ZERO, 0, 1)


func test_drive_a_buggy() -> void:
	var v := _vehicle_of_type("buggy")
	await _board(v)
	assert_int(_p.vehicle).is_equal(v.id)
	var start := v.body.global_position
	_tick(Vector2(0, 1), 0, 120)
	assert_float(v.body.global_position.distance_to(start)).is_greater(15.0)
	assert_float(_p.feet().distance_to(v.body.global_position)).is_less(3.0)
	_tick(Vector2.ZERO, PlayerInput.VEHICLE, 1)
	assert_int(_p.vehicle).is_equal(-1)
	assert_int(_p.body.collision_layer).is_equal(2)
	assert_int(v.driver()).is_equal(-1)


func test_fly_a_plane_and_bail_out() -> void:
	var v := _vehicle_of_type("prop_plane")
	await _board(v)
	assert_int(_p.vehicle).is_equal(v.id)
	var yaw := float(v.state["yaw"])
	_tick(Vector2(0, 1), 0, 30 * 12, 0.35, yaw)
	assert_bool(v.state["airborne"]).override_failure_message("plane never took off").is_true()
	var ground := _m.map.height(v.body.global_position.x, v.body.global_position.z)
	assert_float(v.body.global_position.y - ground).is_greater(15.0)
	_tick(Vector2.ZERO, PlayerInput.VEHICLE, 1, 0.0, yaw)
	assert_int(_p.vehicle).is_equal(-1)
	assert_int(_p.air).is_equal(PlayerMotor.Air.FREEFALL)
