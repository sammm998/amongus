extends Node
## M0 client front end: host a local server, join one, see who is connected.
## Launch flags: --host, --connect ADDR[:PORT], --name NAME, --transport enet|ws,
## --expect-roster N and --quit-after S (used by the automated smoke test).

var _name_edit: LineEdit
var _address_edit: LineEdit
var _host_button: Button
var _play_button: Button
var _join_button: Button
var _leave_button: Button
var _status_label: Label
var _account_label: Label
var _input_label: Label
var _roster_panel: PanelContainer
var _roster_list: VBoxContainer
var _elapsed := 0.0
var _expect_roster := -1
var _quit_after := -1.0
var _done := false
var _auto_start := false


func _ready() -> void:
	add_child(LobbyBackdrop.new())
	_build_ui()
	NetworkManager.client_state_changed.connect(_on_client_state)
	NetworkManager.roster_changed.connect(_on_roster)
	InputRouter.mode_changed.connect(_on_input_mode)
	Backend.login_finished.connect(_on_login)
	_on_input_mode(InputRouter.mode)
	if Backend.service.is_authenticated() or not Backend.last_error.is_empty():
		_on_login(Backend.service.is_authenticated())
	_refresh()
	var args := GameData.args
	_expect_roster = args["expect_roster"]
	_quit_after = args["quit_after"]
	if not args["name"].is_empty():
		_name_edit.text = args["name"]
	if args["play"]:
		_play_vs_bots()
	elif args["host"]:
		_host()
	elif not args["connect"].is_empty():
		_address_edit.text = args["connect"]
		_join()


func _process(delta: float) -> void:
	_elapsed += delta
	if _quit_after > 0.0 and _elapsed >= _quit_after and not _done:
		_done = true
		var ok := _expect_roster < 0
		print("CLIENT_TIMEOUT roster=%d" % _roster_size() if not ok else "CLIENT_QUIT")
		_finish(0 if ok else 1)


func _host() -> void:
	var err := NetworkManager.host_and_join(_player_name(), GameData.args["port"], GameData.args["transport"])
	if err != OK:
		_status_label.text = "Could not host: %s (port in use?)" % error_string(err)
	_refresh()


## On the web build the game server lives on the same host under /ws.
static func web_server_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var loc: Variant = JavaScriptBridge.eval("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws'", true)
	return str(loc) if loc != null else ""


func _join() -> void:
	var address := _address_edit.text.strip_edges()
	var port: int = GameData.args["port"]
	if address.begins_with("ws://") or address.begins_with("wss://"):
		var err_ws := NetworkManager.start_client(address, port, "ws", _player_name())
		if err_ws != OK:
			_status_label.text = "Could not connect: %s" % error_string(err_ws)
		_refresh()
		return
	if address.count(":") == 1:
		port = address.get_slice(":", 1).to_int()
		address = address.get_slice(":", 0)
	if address.is_empty():
		_status_label.text = "Enter a server address."
		return
	var err := NetworkManager.start_client(address, port, GameData.args["transport"], _player_name())
	if err != OK:
		_status_label.text = "Could not connect: %s" % error_string(err)
	_refresh()


func _leave() -> void:
	NetworkManager.stop_all()
	_refresh()


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if not n.is_empty() else "Player"


func _roster_size() -> int:
	return 0 if NetworkManager.client == null else NetworkManager.client.roster.size()


func _finish(code: int) -> void:
	NetworkManager.stop_all()
	get_tree().quit(code)


func _on_client_state(state: int) -> void:
	_refresh()
	if state == ClientSession.State.CONNECTED and _expect_roster < 0:
		_enter_match.call_deferred()


func _enter_match() -> void:
	# Wait for the first MATCH_INFO so the match scene knows the map.
	var tries := 0
	while NetworkManager.game.info.is_empty() and tries < 120:
		await get_tree().process_frame
		tries += 1
	if NetworkManager.client != null and NetworkManager.client.is_connected_to_server():
		get_tree().change_scene_to_file("res://client/match/match_client.tscn")


func _play_vs_bots() -> void:
	NetworkManager.auto_start_requested = true
	var err := NetworkManager.play_offline(_player_name())
	if err != OK:
		_status_label.text = "Could not start: %s" % error_string(err)
	_refresh()


func _on_roster(players: Array) -> void:
	for child in _roster_list.get_children():
		child.queue_free()
	for p: Dictionary in players:
		var label := Label.new()
		var me: bool = NetworkManager.client != null and p["id"] == NetworkManager.client.peer_id
		label.text = ("▸ " if me else "   ") + p["name"]
		if me:
			label.add_theme_color_override("font_color", UITheme.CYAN)
		_roster_list.add_child(label)
	_roster_panel.visible = not players.is_empty()
	if _expect_roster > 0 and players.size() >= _expect_roster and not _done:
		_done = true
		print("CLIENT_ROSTER_OK count=%d names=%s" % [players.size(), ",".join(players.map(func(p: Dictionary) -> String: return p["name"]))])
		_finish(0)


func _on_input_mode(mode: int) -> void:
	_input_label.text = "INPUT  %s" % InputClassifier.mode_name(mode).to_upper()


func _on_login(_ok: bool) -> void:
	_account_label.text = "Signed in: %s" % Backend.status_text()
	if GameData.args["name"].is_empty() and _name_edit.text.is_empty():
		_name_edit.text = Backend.display_name


func _refresh() -> void:
	var client := NetworkManager.client
	var active := client != null and client.state in [ClientSession.State.CONNECTING, ClientSession.State.HANDSHAKING, ClientSession.State.CONNECTED]
	# Browsers cannot open a listening socket, so hosting is hidden on the web build.
	_host_button.visible = not active and not OS.has_feature("web")
	_play_button.visible = not active
	_join_button.visible = not active
	_leave_button.visible = active or NetworkManager.server != null
	_name_edit.editable = not active
	_address_edit.editable = not active
	_status_label.text = _status_text()
	if not active:
		_roster_panel.visible = false


func _status_text() -> String:
	var client := NetworkManager.client
	var lines := PackedStringArray()
	if NetworkManager.server != null:
		var port: int = GameData.args["port"]
		lines.append("Hosting on port %d" % (port if port > 0 else NetworkManager.default_port()))
	if client == null:
		lines.append("Offline")
		return "\n".join(lines)
	match client.state:
		ClientSession.State.CONNECTING, ClientSession.State.HANDSHAKING:
			lines.append("Connecting…")
		ClientSession.State.CONNECTED:
			lines.append("Connected as %s" % client.display_name)
		ClientSession.State.REJECTED:
			lines.append("Rejected by server: %s" % client.reject_reason.replace("_", " "))
		ClientSession.State.FAILED:
			lines.append("Connection failed")
		_:
			lines.append("Disconnected")
	return "\n".join(lines)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.theme = UITheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := _safe_margins()
	root.add_theme_constant_override("margin_left", safe.x)
	root.add_theme_constant_override("margin_top", safe.y)
	root.add_theme_constant_override("margin_right", safe.x)
	root.add_theme_constant_override("margin_bottom", safe.y)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = "TRAITOR ISLAND"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.2))
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	var tagline := Label.new()
	tagline.text = "TRUST NOBODY."
	tagline.add_theme_color_override("font_color", UITheme.AMBER)
	tagline.add_theme_font_size_override("font_size", 22)
	col.add_child(tagline)
	_account_label = _dim_label("Signing in…")
	col.add_child(_account_label)

	col.add_child(_dim_label("NAME"))
	_name_edit = LineEdit.new()
	_name_edit.max_length = int(GameData.table("network")["max_name_length"])
	_name_edit.placeholder_text = "Your name"
	col.add_child(_name_edit)
	col.add_child(_dim_label("SERVER"))
	_address_edit = LineEdit.new()
	_address_edit.text = web_server_url() if OS.has_feature("web") else "127.0.0.1"
	_address_edit.placeholder_text = "address[:port]"
	col.add_child(_address_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	_host_button = _button("HOST LOCAL", _host)
	_join_button = _button("JOIN", _join)
	buttons.add_child(_host_button)
	buttons.add_child(_join_button)
	_play_button = _button("PLAY VS BOTS", _play_vs_bots)
	col.add_child(_play_button)
	_leave_button = _button("LEAVE", _leave)
	col.add_child(_leave_button)
	col.add_child(_button("SUNSET COVE", func() -> void:
		NetworkManager.stop_all()
		get_tree().change_scene_to_file("res://world/sunset_cove/sunset_cove.tscn")))
	if not (OS.has_feature("mobile") or OS.has_feature("web")):
		col.add_child(_button("QUIT", func() -> void: _finish(0)))

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", UITheme.CYAN)
	col.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size = Vector2(280, 0)
	row.add_child(right)
	_roster_panel = PanelContainer.new()
	_roster_panel.visible = false
	right.add_child(_roster_panel)
	var roster_col := VBoxContainer.new()
	_roster_panel.add_child(roster_col)
	var roster_title := Label.new()
	roster_title.text = "PLAYERS"
	roster_title.add_theme_color_override("font_color", UITheme.AMBER)
	roster_col.add_child(roster_title)
	_roster_list = VBoxContainer.new()
	roster_col.add_child(_roster_list)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(fill)
	_input_label = Label.new()
	_input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_input_label.add_theme_color_override("font_color", UITheme.TEXT)
	_input_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.9))
	_input_label.add_theme_constant_override("outline_size", 6)
	_input_label.add_theme_font_size_override("font_size", 16)
	right.add_child(_input_label)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	return b


func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	l.add_theme_font_size_override("font_size", 16)
	return l


## Margins that keep UI clear of notches and rounded corners (GAME_SPEC §8.2).
func _safe_margins() -> Vector2i:
	var base := Vector2i(24, 24)
	if not (OS.has_feature("mobile")):
		return base
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return base
	var scale := get_viewport().get_visible_rect().size.x / float(screen.x)
	var inset_x := maxi(safe.position.x, screen.x - safe.end.x)
	var inset_y := maxi(safe.position.y, screen.y - safe.end.y)
	return base + Vector2i(int(inset_x * scale), int(inset_y * scale))
