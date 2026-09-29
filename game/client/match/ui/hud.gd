class_name MatchHUD
extends CanvasLayer
## In-match HUD (GAME_SPEC §8.2): minimap top-left, objective + Island Security
## top-centre, time/network/alerts top-right, health+shield bottom-left,
## weapons/ammo bottom-right, crosshair + context prompt centre. Overlays:
## pre-game, countdown, role reveal, downed, meeting, results, cameras, menu.

signal leave_requested

var game: ClientGameState
var map: MapData
var touch_state: TouchInputState
var camera_points: Dictionary
var world_3d: World3D

var root: Control
var minimap: Minimap
var touch: TouchControls
var meeting_panel: MeetingPanel
var results_panel: ResultsPanel
var role_reveal: RoleReveal
var sabotage_panel: SabotagePanel
var cameras: CameraTerminal
var comms: CommsPanel
var full_map: FullMap
var ghost_root: Node3D
var aim_point_provider: Callable
var _inspect_label: Label
var _inspect_bar: ProgressBar
var _inspect_panel: PanelContainer
var _info_panel: PanelContainer
var _info_label: Label
var _info_time := 0.0
var _comms_button: Button
var _hud: Control
var _objective: Label
var _security_bar: ProgressBar
var _security_label: Label
var _time_label: Label
var _net_label: Label
var _alerts: VBoxContainer
var _health_bar: ProgressBar
var _shield_bar: ProgressBar
var _health_label: Label
var _status_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _slots_label: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _prompt_bar: ProgressBar
var _tasks_panel: PanelContainer
var _tasks_box: VBoxContainer
var _crosshair: Control
var _critical: Label
var _banner: Label
var _banner_time := 0.0
var _pregame: PanelContainer
var _pregame_label: Label
var _start_button: Button
var _countdown: Label
var _downed: Control
var _downed_timer: Label
var _spectate: Label
var _menu: PanelContainer
var _sabotage_button: Button
var _chat_panel: VBoxContainer
var _chat_input: LineEdit
var _rotate: Control
var _hit_time := 0.0
var _hurt: Array = []  # [[dir_angle, time]]


func setup(p_game: ClientGameState, p_map: MapData, p_touch: TouchInputState, p_camera_points: Dictionary, p_world: World3D, p_ghost_root: Node3D = null, p_aim: Callable = Callable()) -> void:
	ghost_root = p_ghost_root
	aim_point_provider = p_aim
	game = p_game
	map = p_map
	touch_state = p_touch
	camera_points = p_camera_points
	world_3d = p_world
	layer = 10
	root = Control.new()
	root.theme = UITheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	_build_overlays()
	game.event_received.connect(_on_event)
	game.meeting_changed.connect(_on_meeting_changed)
	game.results_received.connect(_on_results)
	game.role_changed.connect(_on_role)
	game.tasks_changed.connect(_refresh_tasks)
	game.chat_received.connect(_on_chat)
	game.info_changed.connect(_on_info)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)
	# Top-left: minimap + task list.
	minimap = Minimap.new()
	minimap.map = map
	minimap.game = game
	minimap.position = Vector2(18, 18)
	minimap.size = Vector2(170, 170)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(minimap)
	_tasks_panel = UIKit.panel(Vector2(260, 0), 0.7)
	_tasks_panel.position = Vector2(18, 200)
	_hud.add_child(_tasks_panel)
	_tasks_box = VBoxContainer.new()
	_tasks_panel.add_child(_tasks_box)
	# Top-centre: objective + security.
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-220, 14)
	top.custom_minimum_size = Vector2(440, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top)
	_objective = UIKit.label("", 18)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_objective)
	_security_bar = UIKit.bar(UITheme.CYAN, Vector2(440, 14))
	top.add_child(_security_bar)
	_security_label = UIKit.label("ISLAND SECURITY 0%", 14, UITheme.TEXT_DIM)
	_security_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_security_label)
	_critical = UIKit.label("", 28, UITheme.DANGER)
	_critical.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_critical)
	# Top-right: time, network, alerts.
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-300, 14)
	tr.custom_minimum_size = Vector2(282, 0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(tr)
	_time_label = UIKit.label("", 24)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_time_label)
	_net_label = UIKit.label("", 13, UITheme.TEXT_DIM)
	_net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_net_label)
	_alerts = VBoxContainer.new()
	_alerts.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(_alerts)
	# Bottom-left: health + shield + status.
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(18, -120)
	bl.custom_minimum_size = Vector2(300, 0)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(bl)
	_status_label = UIKit.label("", 15, UITheme.AMBER)
	bl.add_child(_status_label)
	_shield_bar = UIKit.bar(Color(0.3, 0.7, 1.0), Vector2(300, 12))
	_shield_bar.max_value = 50.0
	bl.add_child(_shield_bar)
	_health_bar = UIKit.bar(Color(0.35, 0.95, 0.5), Vector2(300, 20))
	bl.add_child(_health_bar)
	_health_label = UIKit.label("", 18)
	bl.add_child(_health_label)
	_sabotage_button = UIKit.button("SABOTAGE", func() -> void: sabotage_panel.visible = not sabotage_panel.visible, 18, Vector2(160, 44))
	_sabotage_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_sabotage_button.position = Vector2(330, -64)
	_sabotage_button.visible = false
	_hud.add_child(_sabotage_button)
	# Chat log (proximity / dead channel) above health.
	_chat_panel = VBoxContainer.new()
	_chat_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_chat_panel.position = Vector2(18, -300)
	_chat_panel.custom_minimum_size = Vector2(420, 150)
	_chat_panel.alignment = BoxContainer.ALIGNMENT_END
	_chat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_chat_panel)
	_chat_input = LineEdit.new()
	_chat_input.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_chat_input.position = Vector2(18, -150)
	_chat_input.custom_minimum_size = Vector2(420, 0)
	_chat_input.placeholder_text = "Say (nearby players hear you)"
	_chat_input.visible = false
	_chat_input.max_length = 140
	_chat_input.text_submitted.connect(func(t: String) -> void:
		if not t.strip_edges().is_empty():
			NetworkManager.send_action("chat", 0, t)
		_chat_input.clear()
		_chat_input.visible = false
		_chat_input.release_focus())
	_hud.add_child(_chat_input)
	# Bottom-right: weapon + ammo.
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-320, -110)
	br.custom_minimum_size = Vector2(300, 0)
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(br)
	_weapon_label = UIKit.label("", 20)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_weapon_label)
	_ammo_label = UIKit.label("", 36)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_ammo_label)
	_slots_label = UIKit.label("", 14, UITheme.TEXT_DIM)
	_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_slots_label)
	# Centre: crosshair + prompt.
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	_hud.add_child(_crosshair)
	_prompt_panel = UIKit.panel(Vector2(320, 0))
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_panel.position = Vector2(-160, 60)
	_hud.add_child(_prompt_panel)
	var pcol := VBoxContainer.new()
	_prompt_panel.add_child(pcol)
	_prompt_label = UIKit.label("", 18)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pcol.add_child(_prompt_label)
	_prompt_bar = UIKit.bar(UITheme.CYAN, Vector2(290, 8))
	pcol.add_child(_prompt_bar)
	_inspect_panel = UIKit.panel(Vector2(320, 0))
	_inspect_panel.set_anchors_preset(Control.PRESET_CENTER)
	_inspect_panel.position = Vector2(-160, 120)
	_hud.add_child(_inspect_panel)
	var icol := VBoxContainer.new()
	_inspect_panel.add_child(icol)
	_inspect_label = UIKit.label("", 16, UITheme.AMBER)
	_inspect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icol.add_child(_inspect_label)
	_inspect_bar = UIKit.bar(UITheme.AMBER, Vector2(290, 6))
	icol.add_child(_inspect_bar)
	_info_panel = UIKit.panel(Vector2(360, 0), 0.9)
	_info_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_info_panel.position = Vector2(-390, -60)
	_info_panel.visible = false
	_hud.add_child(_info_panel)
	_info_label = UIKit.label("", 16)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(330, 0)
	_info_panel.add_child(_info_label)
	_comms_button = UIKit.button("COMMS", func() -> void: comms.open(), 16, Vector2(110, 44))
	_comms_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_comms_button.position = Vector2(-130, 150)
	_comms_button.visible = false
	_hud.add_child(_comms_button)
	var map_button := UIKit.button("MAP", func() -> void: toggle_map(), 16, Vector2(110, 44))
	map_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_button.position = Vector2(196, 18)
	map_button.set_meta("touch_only", true)
	map_button.visible = false
	_hud.add_child(map_button)
	_hud.set_meta("map_button", map_button)
	_banner = UIKit.label("", 36, UITheme.AMBER)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-400, 150)
	_banner.custom_minimum_size = Vector2(800, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_banner)
	# Touch controls.
	touch = TouchControls.new()
	touch.state = touch_state
	root.add_child(touch)


func _build_overlays() -> void:
	_pregame = UIKit.panel(Vector2(420, 0), 0.85)
	_pregame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pregame.position = Vector2(-210, 90)
	_pregame.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_pregame)
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 8)
	_pregame.add_child(pc)
	pc.add_child(UIKit.label("PRE-GAME LOBBY", 28, UITheme.CYAN))
	_pregame_label = UIKit.label("", 17)
	_pregame_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(_pregame_label)
	_start_button = UIKit.button("START MATCH", func() -> void: NetworkManager.send_action("start"), 24, Vector2(0, 58))
	pc.add_child(_start_button)
	_countdown = UIKit.label("", 96, Color.WHITE)
	_countdown.set_anchors_preset(Control.PRESET_CENTER)
	_countdown.position = Vector2(-200, -80)
	_countdown.custom_minimum_size = Vector2(400, 0)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_countdown)
	_downed = Control.new()
	_downed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_downed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var red := ColorRect.new()
	red.color = Color(0.35, 0.0, 0.02, 0.45)
	red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_downed.add_child(red)
	var dcol := VBoxContainer.new()
	dcol.set_anchors_preset(Control.PRESET_CENTER)
	dcol.position = Vector2(-250, -60)
	dcol.custom_minimum_size = Vector2(500, 0)
	_downed.add_child(dcol)
	var dl := UIKit.label("YOU ARE DOWN", 60, UITheme.DANGER)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dcol.add_child(dl)
	_downed_timer = UIKit.label("", 32)
	_downed_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dcol.add_child(_downed_timer)
	root.add_child(_downed)
	_spectate = UIKit.label("", 22, UITheme.TEXT_DIM)
	_spectate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_spectate.position = Vector2(-300, -80)
	_spectate.custom_minimum_size = Vector2(600, 0)
	_spectate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_spectate)
	sabotage_panel = SabotagePanel.new()
	sabotage_panel.game = game
	sabotage_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sabotage_panel.position = Vector2(330, -330)
	sabotage_panel.visible = false
	root.add_child(sabotage_panel)
	role_reveal = RoleReveal.new()
	role_reveal.game = game
	role_reveal.visible = false
	root.add_child(role_reveal)
	meeting_panel = MeetingPanel.new()
	meeting_panel.game = game
	meeting_panel.visible = false
	root.add_child(meeting_panel)
	cameras = CameraTerminal.new()
	cameras.game = game
	cameras.map = map
	cameras.camera_points = camera_points
	cameras.world_3d = world_3d
	cameras.ghost_root = ghost_root
	root.add_child(cameras)
	full_map = FullMap.new()
	full_map.map = map
	full_map.game = game
	root.add_child(full_map)
	comms = CommsPanel.new()
	comms.game = game
	comms.aim_point_provider = aim_point_provider
	comms.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	comms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comms.closed.connect(func() -> void:
		if InputRouter.mode == InputClassifier.Mode.DESKTOP and not is_blocking_input():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	root.add_child(comms)
	results_panel = ResultsPanel.new()
	results_panel.game = game
	results_panel.visible = false
	results_panel.leave_pressed.connect(func() -> void: leave_requested.emit())
	root.add_child(results_panel)
	_menu = UIKit.panel(Vector2(340, 0), 0.95)
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.position = Vector2(-170, -110)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.visible = false
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", 10)
	_menu.add_child(mcol)
	mcol.add_child(UIKit.label("MENU", 28, UITheme.CYAN))
	mcol.add_child(UIKit.button("RESUME", func() -> void: toggle_menu(), 22))
	mcol.add_child(UIKit.button("LEAVE MATCH", func() -> void: leave_requested.emit(), 22))
	root.add_child(_menu)
	_rotate = ColorRect.new()
	(_rotate as ColorRect).color = Color(0.02, 0.03, 0.08, 0.96)
	_rotate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rl := UIKit.label("ROTATE YOUR DEVICE", 40, UITheme.CYAN)
	rl.set_anchors_preset(Control.PRESET_CENTER)
	rl.position = Vector2(-220, -30)
	_rotate.add_child(rl)
	_rotate.visible = false
	root.add_child(_rotate)


# ---------------------------------------------------------------- update ---

func toggle_map() -> void:
	full_map.visible = not full_map.visible


func open_comms() -> void:
	if game.my_state() == Vitals.State.DOWNED or game.phase == "INCIDENT_MEETING":
		return
	comms.open()


func is_blocking_input() -> bool:
	return comms.visible or full_map.visible or _menu.visible or meeting_panel.visible or results_panel.visible or cameras.visible or _chat_input.visible or (role_reveal.visible and game.phase == "ROLE_REVEAL")


func toggle_menu() -> void:
	_menu.visible = not _menu.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _menu.visible else Input.MOUSE_MODE_CAPTURED


func open_chat() -> void:
	if game.phase == "INCIDENT_MEETING" or game.my_state() == Vitals.State.DOWNED:
		return
	_chat_input.visible = true
	_chat_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func update_hud(delta: float, local_pos: Vector3, heading: float, dark_here: bool) -> void:
	var phase := game.phase
	var me := game.me
	var state := game.my_state()
	var downed := state == Vitals.State.DOWNED and not game.is_spectator()
	var spectating := game.is_spectator() or state == Vitals.State.ELIMINATED
	var in_match := phase in ["ACTIVE", "RESUMING", "INCIDENT_MEETING", "MATCH_END"]
	var touch_mode := InputRouter.mode == InputClassifier.Mode.TOUCH
	var vp := root.get_viewport_rect().size
	_rotate.visible = touch_mode and vp.y > vp.x and in_match
	# The downed player sees ONLY "YOU ARE DOWN" and the bleed-out timer.
	_downed.visible = downed and phase != "INCIDENT_MEETING"
	_hud.visible = not downed and phase != "ROLE_REVEAL"
	_downed_timer.text = "Bleeding out: %s" % UIKit.fmt_time(float(me.get("bleed", 0.0))) if float(me.get("bleed", 0.0)) > 0.0 else ""
	_spectate.visible = spectating and in_match and not meeting_panel.visible
	_spectate.text = "ELIMINATED — spectating. You can only talk to other eliminated players."
	_pregame.visible = phase in ["WAITING", "COUNTDOWN"]
	var humans := game.players.values().filter(func(p: Dictionary) -> bool: return not p["bot"]).size()
	_pregame_label.text = "%d player(s) connected. Run, jump and test your controls — no damage here.\n%s" % [humans,
		"Press START MATCH: empty seats are filled with bots (8 players)." if game.host == game.my_id() else "Waiting for the host to start…"]
	_start_button.visible = phase == "WAITING" and game.host == game.my_id()
	_countdown.visible = phase == "COUNTDOWN"
	_countdown.text = str(int(ceil(float(game.info.get("time_left", 0.0)))))
	touch.visible = touch_mode and not is_blocking_input() and not spectating and phase in ["WAITING", "COUNTDOWN", "ACTIVE", "RESUMING"]
	# Objective + security.
	var traitor := game.role == "traitor"
	_objective.text = "" if game.role.is_empty() else ("TRAITOR — Blend in · Sabotage · Eliminate" if traitor else "AGENT — Complete tasks · Find the Traitors")
	_objective.add_theme_color_override("font_color", UITheme.DANGER if traitor else UITheme.CYAN)
	var sec := float(game.world.get("security", 0.0))
	_security_bar.value = sec
	_security_label.text = "ISLAND SECURITY %d%%" % int(sec)
	_security_bar.visible = in_match
	_security_label.visible = in_match
	var crit := ""
	for s: Dictionary in game.world.get("sabotages", []):
		if s["critical"]:
			crit = "POWER FAILURE — ISLAND CONTROL LOST IN %s  ·  generators %d/2" % [UIKit.fmt_time(float(s["time_left"])), int(s["progress"])]
	_critical.text = crit
	# Time + network.
	var limit := float(game.info.get("time_limit", 0.0))
	_time_label.text = UIKit.fmt_time(limit - float(game.info.get("elapsed", 0.0))) if in_match and limit > 0.0 else ""
	var rtt := NetworkManager.client.rtt_ms if NetworkManager.client != null else -1
	_net_label.text = "%d ms · %s" % [rtt, InputRouter.mode_name()]
	# Vitals.
	_health_bar.value = float(me.get("health", 100.0))
	_shield_bar.value = float(me.get("shield", 0.0))
	_health_label.text = "%d HP  ·  %d SHIELD" % [int(me.get("health", 100.0)), int(me.get("shield", 0.0))]
	var status := PackedStringArray()
	if float(me.get("protect", 0.0)) > 0.0:
		status.append("SPAWN PROTECTION")
	if float(me.get("stun", 0.0)) > 0.0:
		status.append("STUNNED")
	if float(me.get("healing", 0.0)) > 0.0:
		status.append("HEALING %.1fs" % float(me["healing"]))
	if game.is_suspect(game.my_id()):
		status.append("⚠ YOU ARE MARKED SUSPECT")
	_status_label.text = "  ".join(status)
	_sabotage_button.visible = traitor and in_match and state == Vitals.State.ALIVE
	if not _sabotage_button.visible:
		sabotage_panel.visible = false
	_update_weapon(me)
	_update_prompt(me)
	_update_inspect(me)
	_info_time -= delta
	_info_panel.visible = _info_time > 0.0
	_comms_button.visible = touch_mode and in_match and state == Vitals.State.ALIVE
	(_hud.get_meta("map_button") as Button).visible = touch_mode and in_match
	full_map.own_pos = local_pos
	full_map.heading = heading
	# Minimap.
	minimap.center = local_pos
	minimap.heading = heading
	minimap.queue_redraw()
	_tasks_panel.visible = not game.tasks.is_empty() and in_match
	touch.flashlight_available = dark_here
	# Alerts fade.
	for a in _alerts.get_children():
		a.set_meta("t", float(a.get_meta("t", 0.0)) + delta)
		a.modulate.a = clampf(1.0 - (float(a.get_meta("t")) - 5.0) / 2.0, 0.0, 1.0)
		if float(a.get_meta("t")) > 7.0:
			a.queue_free()
	for c in _chat_panel.get_children():
		c.set_meta("t", float(c.get_meta("t", 0.0)) + delta)
		c.modulate.a = clampf(1.0 - (float(c.get_meta("t")) - 8.0) / 2.0, 0.0, 1.0)
		if float(c.get_meta("t")) > 10.0:
			c.queue_free()
	_banner_time -= delta
	_banner.visible = _banner_time > 0.0
	_hit_time = maxf(0.0, _hit_time - delta)
	_crosshair.queue_redraw()


func _update_weapon(me: Dictionary) -> void:
	var inv: Dictionary = me.get("inv", {})
	if inv.is_empty():
		return
	var active: int = inv["active"]
	var ws: Array = inv["weapons"]
	var weapons: Dictionary = {}
	for w: Dictionary in GameData.table("weapons")["weapons"]:
		weapons[w["id"]] = w
	if active == Inventory.HEALING:
		var items: Dictionary = inv["items"]
		_weapon_label.text = "HEALING — hold FIRE to use"
		var parts := PackedStringArray()
		for k: String in items:
			parts.append("%s ×%d" % [k.replace("_", " ").capitalize(), items[k]])
		_ammo_label.text = ", ".join(parts) if not parts.is_empty() else "—"
	elif active < ws.size() and not ws[active].is_empty():
		var w: Array = ws[active]
		var def: Dictionary = weapons[w[0]]
		var rarity: Dictionary = GameData.table("combat")["rarities"][w[1]]
		_weapon_label.text = "%s · %s" % [def["display_name"], rarity["display_name"]]
		_weapon_label.add_theme_color_override("font_color", Color(rarity["color"]))
		_ammo_label.text = "%d / %d%s" % [w[2], int(inv["ammo"].get(def["ammo_type"], 0)), "  RELOADING" if me.get("reloading", false) else ""]
	var names := PackedStringArray()
	for i in 3:
		var label := "%d:%s" % [i + 1, weapons[ws[i][0]]["display_name"] if not ws[i].is_empty() else "—"]
		names.append("[%s]" % label if i == active else label)
	names.append("5:Heal" if active != Inventory.HEALING else "[5:Heal]")
	_slots_label.text = "  ".join(names)


func _update_prompt(me: Dictionary) -> void:
	var prompt: Dictionary = me.get("prompt", {})
	var show := not prompt.is_empty() and game.phase in ["ACTIVE", "RESUMING"]
	_prompt_panel.visible = show
	touch.context_label = prompt.get("verb", "") if show else ""
	if show:
		var key := "E" if InputRouter.mode == InputClassifier.Mode.DESKTOP else ("X" if InputRouter.mode == InputClassifier.Mode.CONTROLLER else "USE")
		_prompt_label.text = "[%s] %s — %s" % [key, prompt["verb"], prompt["label"]]
		var hold := float(prompt["hold"])
		var progress := float(prompt["progress"]) / hold if hold > 0.0 else 0.0
		_prompt_bar.value = progress * 100.0
		touch.context_progress = progress
	touch.queue_redraw()


func _update_inspect(me: Dictionary) -> void:
	var ins: Dictionary = me.get("inspect", {})
	var show := not ins.is_empty() and game.phase in ["ACTIVE", "RESUMING"]
	_inspect_panel.visible = show
	touch.inspect_label = "INSPECT" if show else ""
	if show:
		var key := "Q" if InputRouter.mode == InputClassifier.Mode.DESKTOP else ("LB" if InputRouter.mode == InputClassifier.Mode.CONTROLLER else "INSPECT")
		_inspect_label.text = "[%s] %s" % [key, ins["label"]]
		var hold := float(ins["hold"])
		_inspect_bar.value = float(ins["progress"]) / hold * 100.0 if hold > 0.0 else 0.0


func show_info(text: String, seconds: float = 7.0) -> void:
	_info_label.text = text
	_info_time = seconds


func _draw_crosshair() -> void:
	if game.phase in ["INCIDENT_MEETING", "ROLE_REVEAL"] or game.my_state() != Vitals.State.ALIVE:
		return
	var c := Color(1, 1, 1, 0.9)
	var g := 5.0
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_crosshair.draw_line(d * g, d * (g + 9.0), c, 2.0)
	_crosshair.draw_circle(Vector2.ZERO, 1.5, c)
	if _hit_time > 0.0:
		var hc := Color(1, 1, 1, _hit_time / 0.25)
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_crosshair.draw_line(d.normalized() * 8.0, d.normalized() * 16.0, hc, 3.0)
	var now := NetworkManager.local_time()
	for h: Array in _hurt:
		var age := now - float(h[1])
		if age > 1.2:
			continue
		var ang := float(h[0])
		_crosshair.draw_arc(Vector2.ZERO, 90.0, ang - 0.35 - PI * 0.5, ang + 0.35 - PI * 0.5, 16, Color(1, 0.2, 0.15, 1.0 - age / 1.2), 8.0)


# ---------------------------------------------------------------- events ---

func _on_event(kind: String, data: Dictionary) -> void:
	match kind:
		"alert":
			var text: String = data["text"] + ((" — " + data["district"]) if not String(data["district"]).is_empty() else "")
			var l := UIKit.label(text, 18, UITheme.DANGER if data["critical"] else UITheme.AMBER)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_alerts.add_child(l)
			_show_banner(text, UITheme.DANGER if data["critical"] else UITheme.AMBER)
		"hit":
			_hit_time = 0.25
		"hurt":
			var dir: Vector3 = data["dir"]
			var cam_yaw: float = get_meta("camera_yaw", 0.0)
			var local := Basis(Vector3.UP, cam_yaw).inverse() * dir
			_hurt.append([atan2(local.x, -local.z), NetworkManager.local_time()])
			if _hurt.size() > 6:
				_hurt.pop_front()
		"denied":
			_show_banner("Not available: %s" % String(data["reason"]).replace("_", " "), UITheme.AMBER)
		"task_step":
			_show_banner("TASK COMPLETE" if data["done"] else "STEP COMPLETE", UITheme.CYAN)
		"open_cameras":
			cameras.open()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		"revived":
			_show_banner("YOU WERE REVIVED", UITheme.CYAN)
		"inspection":
			if data.get("known", false):
				show_info("BODY INSPECTION — %s\nEstimated time: ~%d s ago (±15 s)\nDamage: %s\nWeapon family: %s\nRange: %s\nLast hit from: %s\n(The attacker cannot be determined.)" % [data.get("name", "?"), int(data["seconds_ago"]), data["damage_type"], data["weapon_family"], data["range"], data["direction"]])
			else:
				show_info("BODY INSPECTION — %s\nNo clear evidence of what happened." % data.get("name", "?"))
		"evidence_info":
			var what := "Shell casing" if data["kind"] == "casing" else "Impact mark"
			show_info("%s — weapon family: %s\nLeft roughly %d s ago." % [what, data["family"], int(data["seconds_ago"])], 5.0)
		"coop_wait", "repair_progress":
			_show_banner(data["text"], UITheme.CYAN)
		"eliminated":
			_show_banner("YOU WERE ELIMINATED", UITheme.DANGER)


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_time = 3.0


func _on_meeting_changed() -> void:
	if not game.meeting.is_empty() and not meeting_panel.visible:
		meeting_panel.open()
		cameras.close()
		touch.release_all()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif game.meeting.is_empty() and meeting_panel.visible:
		meeting_panel.visible = false
		var r := game.last_meeting_result
		if not r.is_empty():
			var text := ""
			if r["had_vote"]:
				text = "%s was %s" % [game.player_name(r["victim"]), "REVIVED" if r["revived"] else "KEPT ELIMINATED"]
			if not r["suspects"].is_empty():
				text += ("  ·  " if not text.is_empty() else "") + "SUSPECT: " + ", ".join(r["suspects"].map(func(id: int) -> String: return game.player_name(id)))
			if not text.is_empty():
				_show_banner(text, UITheme.AMBER)
		if InputRouter.mode == InputClassifier.Mode.DESKTOP:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_results(r: Dictionary) -> void:
	meeting_panel.visible = false
	cameras.visible = false
	results_panel.show_results(r)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_role() -> void:
	if not game.role.is_empty():
		role_reveal.play()
		_refresh_tasks()


func _on_info() -> void:
	if game.phase == "WAITING":
		results_panel.visible = false
		role_reveal.visible = false


func _refresh_tasks() -> void:
	UIKit.clear(_tasks_box)
	if game.tasks.is_empty():
		return
	var traitor := game.role == "traitor"
	_tasks_box.add_child(UIKit.label("FAKE TASKS (no progress)" if traitor else "TASKS", 15, UITheme.DANGER if traitor else UITheme.AMBER))
	for t: Dictionary in game.tasks:
		var step := "" if int(t["steps"]) <= 1 else " (%d/%d)" % [int(t["step"]) + (1 if t["done"] else 0), int(t["steps"])]
		var where := map.district_name(map.station(t["station"]).get("district", "")) if not t["done"] else ""
		var text := "%s %s%s%s" % ["✓" if t["done"] else "•", t["name"], step, ("  — " + where) if not where.is_empty() else ""]
		_tasks_box.add_child(UIKit.label(text, 15, UITheme.TEXT_DIM if t["done"] else UITheme.TEXT))


func _on_chat(p: Dictionary) -> void:
	if meeting_panel.visible:
		return
	var colors := UIKit.suit_colors(game.player_color(p["from"]))
	var l := UIKit.label("%s%s: %s" % ["[dead] " if p["channel"] == CommsRules.DEAD else "", p["name"], p["text"]], 16, colors[0].lightened(0.3))
	_chat_panel.add_child(l)
	while _chat_panel.get_child_count() > 6:
		_chat_panel.get_child(0).queue_free()
