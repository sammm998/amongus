class_name TouchInputState
extends RefCounted
## Shared state between the on-screen touch controls and the LocalPlayer.

var move := Vector2.ZERO
var sprint := false
var slot_request := -1
var _look := Vector2.ZERO
var _held: Dictionary = {}
var _pressed: Dictionary = {}


func add_look(delta: Vector2) -> void:
	_look += delta


func consume_look() -> Vector2:
	var d := _look
	_look = Vector2.ZERO
	return d


func set_held(action: String, held: bool) -> void:
	if held and not _held.get(action, false):
		_pressed[action] = true
	_held[action] = held


func is_held(action: String) -> bool:
	return _held.get(action, false)


## True once per press (toggles like crouch / flashlight).
func take_pressed(action: String) -> bool:
	if _pressed.get(action, false):
		_pressed[action] = false
		return true
	return false


func release_all() -> void:
	_held.clear()
	_pressed.clear()
	move = Vector2.ZERO
	sprint = false
