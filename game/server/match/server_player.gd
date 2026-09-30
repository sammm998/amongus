class_name ServerPlayer
extends RefCounted
## Everything the server tracks about one participant (human or bot).
## `role` never leaves the server except through RoleVisibility-approved messages.

var id := 0
var name := ""
var color := 0
var is_bot := false
var connected := true
var role := RoleAssigner.Role.AGENT
var vitals: Vitals
var inventory: Inventory
var body: CharacterBody3D
var yaw := 0.0
var pitch := 0.0
var crouching := false
var aiming := false
var sprinting := false
var flashlight := false
var last_input := PlayerInput.new()
var input_queue: Array = []
var inputs_this_second := 0
var ack_seq := 0
var interact_target := ""   # "kind:id"
var interact_held := 0.0
var healing_item := ""
var healing_left := 0.0
var history: Array = []     # [[time, feet: Vector3, crouch: bool, downed: bool]]
var emergency_uses := 0
var suspect_until := -1.0
var incident: Dictionary = {}  # last damage info (for incident review)
var reported := false          # body already reported
var spectator := false
var carrying := ""            # delivery item being carried ("" = none)
var emote := ""
var emote_until := -1.0
var inspect_target := ""
var inspect_held := 0.0
var ping_ready_at := 0.0
var vehicle := -1             # ServerVehicle id while seated
var seat := -1
var vehicle_button := false    # previous VEHICLE button state (edge detection)
var air := 0                  # PlayerMotor.Air (opening drop)
var bot_jump_at := -1.0
var stats := {"shots": 0, "hits": 0, "downs": 0, "tasks": 0, "reports": 0, "repairs": 0, "sabotages": 0, "revived": 0, "distance": 0.0}


func feet() -> Vector3:
	return body.global_position if body != null else Vector3.ZERO


func eye(movement: Dictionary) -> Vector3:
	var h := float(movement["eye_height"])
	if crouching:
		h *= float(movement["crouch_height"]) / float(movement["capsule_height"])
	if vitals.state == Vitals.State.DOWNED:
		h = 0.4
	return feet() + Vector3(0, h, 0)


func forward() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func is_living() -> bool:
	return vitals.is_living()


func record_history(now: float, keep: float) -> void:
	history.append([now, feet(), crouching, vitals.state == Vitals.State.DOWNED])
	while history.size() > 2 and float(history[0][0]) < now - keep:
		history.pop_front()


## Feet position (and pose) at a past server time, for lag compensation.
func pose_at(t: float) -> Array:
	if history.is_empty():
		return [feet(), crouching, vitals.state == Vitals.State.DOWNED]
	if t >= float(history[-1][0]):
		return [history[-1][1], history[-1][2], history[-1][3]]
	for i in range(history.size() - 1, 0, -1):
		var a: Array = history[i - 1]
		var b: Array = history[i]
		if float(a[0]) <= t:
			var f := clampf((t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
			return [(a[1] as Vector3).lerp(b[1], f), b[2], b[3]]
	return [history[0][1], history[0][2], history[0][3]]
