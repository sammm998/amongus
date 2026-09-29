extends GdUnitTestSuite
## Uses the InputRouter autoload directly.

var _saved_mode: int


func before_test() -> void:
	_saved_mode = InputRouter.mode


func after_test() -> void:
	InputRouter.mode = _saved_mode


func test_switches_mode_and_emits_once() -> void:
	InputRouter.mode = InputClassifier.Mode.DESKTOP
	var seen: Array = []
	var cb := func(m: int) -> void: seen.append(m)
	InputRouter.mode_changed.connect(cb)
	InputRouter.handle_event(InputEventScreenTouch.new())
	InputRouter.handle_event(InputEventScreenDrag.new())
	var press := InputEventJoypadButton.new()
	press.pressed = true
	InputRouter.handle_event(press)
	InputRouter.handle_event(InputEventKey.new())
	InputRouter.mode_changed.disconnect(cb)
	assert_array(seen).contains_exactly([InputClassifier.Mode.TOUCH, InputClassifier.Mode.CONTROLLER, InputClassifier.Mode.DESKTOP])


func test_emulated_mouse_keeps_touch_mode() -> void:
	InputRouter.mode = InputClassifier.Mode.TOUCH
	var e := InputEventMouseMotion.new()
	e.device = InputEvent.DEVICE_ID_EMULATION
	InputRouter.handle_event(e)
	assert_int(InputRouter.mode).is_equal(InputClassifier.Mode.TOUCH)


func test_bindings_registered_from_data() -> void:
	var bindings: Dictionary = GameData.table("input_bindings")
	for action: String in bindings["actions"]:
		assert_bool(InputMap.has_action(action)).override_failure_message(action).is_true()
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	assert_bool(InputMap.event_is_action(w, "move_forward")).is_true()
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	assert_bool(InputMap.event_is_action(lmb, "fire")).is_true()
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	assert_bool(InputMap.event_is_action(rt, "fire")).is_true()


func test_spec_desktop_keys() -> void:
	var expected := {
		KEY_SPACE: "jump", KEY_SHIFT: "sprint", KEY_CTRL: "crouch", KEY_R: "reload", KEY_E: "interact",
		KEY_F: "vehicle", KEY_T: "flashlight", KEY_TAB: "scoreboard", KEY_M: "full_map", KEY_ENTER: "chat", KEY_ESCAPE: "menu",
	}
	for key: int in expected:
		var e := InputEventKey.new()
		e.physical_keycode = key
		assert_bool(InputMap.event_is_action(e, expected[key])).override_failure_message(expected[key]).is_true()


func test_unknown_key_reports_error() -> void:
	var errors := InputBindings.apply({"actions": {"test_bogus_action": {"keys": ["NotAKey"]}}})
	assert_str("\n".join(errors)).contains("NotAKey")
	InputMap.erase_action("test_bogus_action")
