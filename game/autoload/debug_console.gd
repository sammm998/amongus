extends CanvasLayer
## Autoload: in-game debug console (backquote / F1) and FPS overlay.
## Available in debug builds, or in release builds launched with --console.

var registry := ConsoleCommandRegistry.new()
var enabled := false
var _panel: PanelContainer
var _output: RichTextLabel
var _input: LineEdit
var _fps_label: Label
var _fps_timer := 0.0
var _fps_refresh := 0.25
var _max_lines := 200
var _history: PackedStringArray = []
var _history_index := -1


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = (OS.is_debug_build() or GameData.args["console"]) and not GameData.is_headless()
	var cfg := GameData.table("debug")
	_fps_refresh = float(cfg.get("fps_overlay_refresh_seconds", _fps_refresh))
	_max_lines = int(cfg.get("console_max_lines", _max_lines))
	_register_commands()
	if enabled:
		_build_ui()
	set_process(enabled)
	set_process_unhandled_input(enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel != null and _panel.visible


func toggle() -> void:
	if _panel == null:
		return
	_panel.visible = not _panel.visible
	if _panel.visible:
		_input.clear()
		_input.grab_focus.call_deferred()


func run(line: String) -> String:
	var output := registry.execute(line)
	if _output != null:
		print_line("> " + line)
		if not output.is_empty():
			print_line(output)
	return output


func print_line(text: String) -> void:
	if _output == null:
		return
	_output.add_text(text + "\n")
	while _output.get_paragraph_count() > _max_lines:
		_output.remove_paragraph(0)


func set_fps_visible(show: bool) -> void:
	if _fps_label != null:
		_fps_label.visible = show


func _process(delta: float) -> void:
	if _fps_label == null or not _fps_label.visible:
		return
	_fps_timer += delta
	if _fps_timer >= _fps_refresh:
		_fps_timer = 0.0
		_fps_label.text = "%d FPS  %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second())]


func _register_commands() -> void:
	registry.register("help", "List commands.", func(_a: PackedStringArray) -> String: return registry.help_text())
	registry.register("clear", "Clear the console.", func(_a: PackedStringArray) -> String:
		if _output != null:
			_output.clear()
		return "")
	registry.register("echo", "Print the arguments.", func(a: PackedStringArray) -> String: return " ".join(a))
	registry.register("fps", "Toggle the FPS overlay.", func(_a: PackedStringArray) -> String:
		if _fps_label == null:
			return "No overlay in this build."
		set_fps_visible(not _fps_label.visible)
		return "FPS overlay %s." % ("on" if _fps_label.visible else "off"))
	registry.register("net", "Network status.", func(_a: PackedStringArray) -> String: return NetworkManager.status_text())
	registry.register("roster", "Players on the server.", func(_a: PackedStringArray) -> String:
		if NetworkManager.client == null or NetworkManager.client.roster.is_empty():
			return "Not connected."
		var lines := PackedStringArray()
		for p: Dictionary in NetworkManager.client.roster:
			lines.append("%d  %s" % [p["id"], p["name"]])
		return "\n".join(lines))
	registry.register("input", "Current input mode.", func(_a: PackedStringArray) -> String: return InputRouter.mode_name())
	registry.register("data", "List data tables.", func(_a: PackedStringArray) -> String:
		return ", ".join(GameData.registry.table_names()))
	registry.register("backend", "Backend login status.", func(_a: PackedStringArray) -> String: return Backend.status_text())
	registry.register("screenshot", "screenshot [path] — save a PNG.", func(a: PackedStringArray) -> String:
		var path := a[0] if a.size() > 0 else "user://screenshots/shot_%d.png" % Time.get_unix_time_from_system()
		Screenshotter.capture(path)
		return "Capturing %s ..." % Screenshotter.resolve_path(path))
	registry.register("quit", "Quit the game.", func(_a: PackedStringArray) -> String:
		get_tree().quit()
		return "")


func _build_ui() -> void:
	var theme := UITheme.build()
	_fps_label = Label.new()
	_fps_label.theme = theme
	_fps_label.add_theme_color_override("font_color", UITheme.CYAN)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 6)
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -220
	_fps_label.offset_top = 8
	_fps_label.offset_right = -12
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.visible = false
	add_child(_fps_label)

	_panel = PanelContainer.new()
	_panel.theme = theme
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_bottom = 320
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.scroll_following = true
	_output.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(_output)
	_input = LineEdit.new()
	_input.placeholder_text = "command (help)"
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_gui)
	box.add_child(_input)
	print_line("Traitor Island debug console. Type 'help'.")


func _on_submit(line: String) -> void:
	_input.clear()
	if line.strip_edges().is_empty():
		return
	_history.append(line)
	_history_index = -1
	run(line)


func _on_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_UP:
			if not _history.is_empty():
				_history_index = _history.size() - 1 if _history_index < 0 else maxi(0, _history_index - 1)
				_input.text = _history[_history_index]
				_input.caret_column = _input.text.length()
			_input.accept_event()
		KEY_TAB:
			var matches := registry.complete(_input.text.strip_edges())
			if matches.size() == 1:
				_input.text = matches[0] + " "
				_input.caret_column = _input.text.length()
			elif matches.size() > 1:
				print_line("  ".join(matches))
			_input.accept_event()
		KEY_QUOTELEFT, KEY_F1, KEY_ESCAPE:
			toggle()
			_input.accept_event()
