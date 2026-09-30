class_name ServerVehicle
extends RefCounted
## A drivable vehicle on the server: body, motor state, occupants, health.

var id := 0
var type_id := ""
var cfg: Dictionary
var body: CharacterBody3D
var motor: VehicleMotor
var state := {"yaw": 0.0, "pitch": 0.0, "speed": 0.0, "airborne": false}
var seats: Array = []          # player id per seat (-1 = free); seat 0 drives
var health := 0.0
var destroyed_at := -1.0
var spawn_pos := Vector3.ZERO
var spawn_yaw := 0.0


func driver() -> int:
	return seats[0] if not seats.is_empty() else -1


func free_seat() -> int:
	return seats.find(-1)


func occupants() -> Array:
	return seats.filter(func(s: int) -> bool: return s >= 0)


func is_destroyed() -> bool:
	return destroyed_at >= 0.0


func seat_position(seat: int) -> Vector3:
	var o: Array = cfg["seat_offsets"][mini(seat, cfg["seat_offsets"].size() - 1)]
	return body.global_transform * Vector3(o[0], o[1], o[2])


func reset() -> void:
	body.global_position = spawn_pos
	body.velocity = Vector3.ZERO
	state = {"yaw": spawn_yaw, "pitch": 0.0, "speed": 0.0, "airborne": false, "vy": 0.0}
	body.rotation = Vector3(0, spawn_yaw, 0)
	seats.fill(-1)
	health = float(cfg["health"])
	destroyed_at = -1.0


## Public snapshot entry: [id, type, pos, yaw, pitch, driver, health 0..1, destroyed, speed, airborne].
func view() -> Array:
	return [id, type_id, body.global_position, float(state["yaw"]), float(state["pitch"]), driver(), health / float(cfg["health"]), is_destroyed(), float(state["speed"]), bool(state["airborne"])]
