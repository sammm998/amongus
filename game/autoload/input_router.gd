extends Node
## Autoload: registers input actions and tracks the last-used input family
## (touch / desktop / controller) so UI can switch instantly.

signal mode_changed(mode: int)

var mode: int = InputClassifier.Mode.DESKTOP
var axis_threshold := 0.35


func _ready() -> void:
	var bindings := GameData.table("input_bindings")
	axis_threshold = float(bindings.get("controller_mode_threshold", axis_threshold))
	for error in InputBindings.apply(bindings):
		push_error("Input bindings: %s" % error)
	if OS.has_feature("mobile"):
		mode = InputClassifier.Mode.TOUCH


func _input(event: InputEvent) -> void:
	handle_event(event)


func handle_event(event: InputEvent) -> void:
	var detected := InputClassifier.classify(event, axis_threshold)
	if detected != InputClassifier.Mode.NONE and detected != mode:
		mode = detected
		mode_changed.emit(mode)


func mode_name() -> String:
	return InputClassifier.mode_name(mode)
