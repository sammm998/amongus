class_name InputBindings
extends RefCounted
## Registers InputMap actions from data/input_bindings.json.
## Keys use physical keycodes so WASD keeps its position on every layout.


static func apply(bindings: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var deadzone := float(bindings.get("deadzone_default", 0.2))
	var actions: Dictionary = bindings.get("actions", {})
	for action: String in actions:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			InputMap.action_set_deadzone(action, deadzone)
		else:
			InputMap.add_action(action, deadzone)
		var spec: Dictionary = actions[action]
		for key_name: String in spec.get("keys", []):
			var code := OS.find_keycode_from_string(key_name)
			if code == KEY_NONE:
				errors.append("%s: unknown key '%s'" % [action, key_name])
				continue
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
		for button: Variant in spec.get("mouse", []):
			var mb := InputEventMouseButton.new()
			mb.button_index = int(button) as MouseButton
			InputMap.action_add_event(action, mb)
		for button: Variant in spec.get("joy_buttons", []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(button) as JoyButton
			InputMap.action_add_event(action, jb)
		for axis: Variant in spec.get("joy_axes", []):
			var jm := InputEventJoypadMotion.new()
			jm.axis = int(axis[0]) as JoyAxis
			jm.axis_value = float(axis[1])
			InputMap.action_add_event(action, jm)
	return errors
