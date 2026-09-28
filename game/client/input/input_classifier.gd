class_name InputClassifier
extends RefCounted
## Decides which input family an event belongs to (GAME_SPEC §8.1 auto-detect).

enum Mode { NONE = -1, DESKTOP = 0, TOUCH = 1, CONTROLLER = 2 }


static func classify(event: InputEvent, axis_threshold: float) -> int:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return Mode.TOUCH
	if event is InputEventMouse:
		# Mouse events synthesized from touch must not flip a phone to desktop mode.
		return Mode.NONE if event.device == InputEvent.DEVICE_ID_EMULATION else Mode.DESKTOP
	if event is InputEventKey:
		return Mode.DESKTOP
	if event is InputEventJoypadButton:
		return Mode.CONTROLLER if event.pressed else Mode.NONE
	if event is InputEventJoypadMotion:
		return Mode.CONTROLLER if absf(event.axis_value) >= axis_threshold else Mode.NONE
	return Mode.NONE


static func mode_name(mode: int) -> String:
	match mode:
		Mode.DESKTOP:
			return "desktop"
		Mode.TOUCH:
			return "touch"
		Mode.CONTROLLER:
			return "controller"
	return "none"
