class_name CommsPanel
extends Control
## Quick chat, pings and emotes (GAME_SPEC §8.5). Pings are placed where the
## crosshair points; there is deliberately no "traitor here" ping.

signal closed

var game: ClientGameState
var aim_point_provider: Callable
var _grid: VBoxContainer

const PING_LABELS := {"location": "LOCATION", "danger": "DANGER", "vehicle": "VEHICLE", "task": "TASK", "item": "ITEM", "suspicious": "SUSPICIOUS"}


func _ready() -> void:
	var cfg: Dictionary = GameData.table("info_systems")
	var panel := UIKit.panel(Vector2(560, 0), 0.94)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280, -230)
	add_child(panel)
	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", 8)
	panel.add_child(_grid)
	var head := HBoxContainer.new()
	var title := UIKit.label("QUICK CHAT · PINGS · EMOTES", 20, UITheme.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.button("CLOSE", func() -> void: close(), 16, Vector2(100, 40)))
	_grid.add_child(head)
	var quick := HFlowContainer.new()
	var lines: Array = cfg["quick_chat"]
	for i in lines.size():
		var idx := i
		quick.add_child(UIKit.button(lines[i], func() -> void: _quick(idx), 15, Vector2(0, 38)))
	_grid.add_child(quick)
	_grid.add_child(UIKit.label("PING (where you aim)", 15, UITheme.TEXT_DIM))
	var pings := HFlowContainer.new()
	for kind: String in cfg["ping_kinds"]:
		pings.add_child(UIKit.button(PING_LABELS.get(kind, kind.to_upper()), func() -> void: _ping(kind), 16, Vector2(0, 42)))
	_grid.add_child(pings)
	_grid.add_child(UIKit.label("EMOTE", 15, UITheme.TEXT_DIM))
	var emotes := HFlowContainer.new()
	for e: String in cfg["emotes"]:
		emotes.add_child(UIKit.button(e.to_upper(), func() -> void: _emote(e), 16, Vector2(0, 42)))
	_grid.add_child(emotes)
	visible = false


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	closed.emit()


func _quick(idx: int) -> void:
	NetworkManager.send_action("quick", idx)
	close()


func _ping(kind: String) -> void:
	var p: Vector3 = aim_point_provider.call() if aim_point_provider.is_valid() else Vector3.ZERO
	NetworkManager.send_action("ping", 0, "%s|%f|%f|%f" % [kind, p.x, p.y, p.z])
	close()


func _emote(e: String) -> void:
	NetworkManager.send_action("emote", 0, e)
	close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("quick_chat")):
		close()
		get_viewport().set_input_as_handled()
