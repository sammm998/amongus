class_name PlayerInput
extends RefCounted
## One input command (client -> server, or bot -> server). Buttons are bit flags.

const FIRE := 1
const AIM := 2
const JUMP := 4
const SPRINT := 8
const CROUCH := 16
const RELOAD := 32
const INTERACT := 64
const FLASHLIGHT := 128
const INSPECT := 256
const VEHICLE := 512  # enter / leave a vehicle (edge-triggered on the server)

var seq := 0
var move := Vector2.ZERO   # x = right, y = forward, length <= 1
var yaw := 0.0
var pitch := 0.0
var buttons := 0
var slot := -1             # requested weapon slot (-1 = keep)
var aim_point := Vector3.ZERO
var view_time := 0.0       # server time the client was rendering (lag compensation)
var dt := 1.0 / 60.0


func has(flag: int) -> bool:
	return buttons & flag != 0


func to_payload() -> Dictionary:
	return {"seq": seq, "move": move, "yaw": yaw, "pitch": pitch, "buttons": buttons, "slot": slot,
		"aim": aim_point, "view": view_time, "dt": dt}


static func from_payload(p: Dictionary) -> PlayerInput:
	var i := PlayerInput.new()
	i.seq = p["seq"]
	var m: Vector2 = p["move"]
	i.move = m.limit_length(1.0) if m.is_finite() else Vector2.ZERO
	i.yaw = wrapf(p["yaw"], -PI, PI) if is_finite(p["yaw"]) else 0.0
	i.pitch = clampf(p["pitch"], -1.5, 1.5) if is_finite(p["pitch"]) else 0.0
	i.buttons = p["buttons"]
	i.slot = p["slot"]
	i.aim_point = p["aim"] if (p["aim"] as Vector3).is_finite() else Vector3.ZERO
	i.view_time = p["view"] if is_finite(p["view"]) else 0.0
	i.dt = clampf(p["dt"], 1.0 / 240.0, 1.0 / 20.0) if is_finite(p["dt"]) else 1.0 / 60.0
	return i
