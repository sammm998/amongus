extends GdUnitTestSuite

const T := 0.35
const M := InputClassifier.Mode


func test_touch_events() -> void:
	assert_int(InputClassifier.classify(InputEventScreenTouch.new(), T)).is_equal(M.TOUCH)
	assert_int(InputClassifier.classify(InputEventScreenDrag.new(), T)).is_equal(M.TOUCH)


func test_mouse_and_keyboard_are_desktop() -> void:
	assert_int(InputClassifier.classify(InputEventMouseMotion.new(), T)).is_equal(M.DESKTOP)
	assert_int(InputClassifier.classify(InputEventMouseButton.new(), T)).is_equal(M.DESKTOP)
	assert_int(InputClassifier.classify(InputEventKey.new(), T)).is_equal(M.DESKTOP)


func test_touch_emulated_mouse_is_ignored() -> void:
	var e := InputEventMouseButton.new()
	e.device = InputEvent.DEVICE_ID_EMULATION
	assert_int(InputClassifier.classify(e, T)).is_equal(M.NONE)


func test_controller_button_press_only() -> void:
	var press := InputEventJoypadButton.new()
	press.pressed = true
	var release := InputEventJoypadButton.new()
	assert_int(InputClassifier.classify(press, T)).is_equal(M.CONTROLLER)
	assert_int(InputClassifier.classify(release, T)).is_equal(M.NONE)


func test_stick_noise_below_threshold_ignored() -> void:
	var drift := InputEventJoypadMotion.new()
	drift.axis_value = 0.1
	var push := InputEventJoypadMotion.new()
	push.axis_value = -0.8
	assert_int(InputClassifier.classify(drift, T)).is_equal(M.NONE)
	assert_int(InputClassifier.classify(push, T)).is_equal(M.CONTROLLER)


func test_mode_names() -> void:
	assert_str(InputClassifier.mode_name(M.TOUCH)).is_equal("touch")
	assert_str(InputClassifier.mode_name(M.NONE)).is_equal("none")
