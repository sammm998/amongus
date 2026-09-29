class_name SabotagePanel
extends Control
## Private Traitor panel (GAME_SPEC §5.7). Only built for Traitor clients.

var game: ClientGameState
var _list: VBoxContainer
var _status: Label
var _district: OptionButton
var _districts: Array = []


func _ready() -> void:
	var panel := UIKit.panel(Vector2(360, 0), 0.92)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UIKit.label("SABOTAGE", 24, UITheme.DANGER))
	_status = UIKit.label("", 16, UITheme.TEXT_DIM)
	col.add_child(_status)
	var row := HBoxContainer.new()
	row.add_child(UIKit.label("Target district:", 16))
	_district = OptionButton.new()
	_district.focus_mode = Control.FOCUS_NONE
	row.add_child(_district)
	col.add_child(row)
	_list = VBoxContainer.new()
	col.add_child(_list)
	game.panel_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if game.panel.is_empty() or not is_inside_tree():
		return
	var p := game.panel
	var ds: Array = p.get("districts", [])
	if ds != _districts:
		_districts = ds
		_district.clear()
		for d: String in ds:
			_district.add_item(d.replace("_", " ").capitalize())
	var grace := float(p.get("grace_left", 0.0))
	var team := float(p.get("team_ready_in", 0.0))
	_status.text = "Available in %s (opening grace)" % UIKit.fmt_time(grace) if grace > 0.0 else ("Team cooldown %s" % UIKit.fmt_time(team) if team > 0.0 else "Ready")
	UIKit.clear(_list)
	var names := {"blackout": "BLACKOUT (district)", "camera_jam": "CAMERA JAM (district)", "power_failure": "POWER FAILURE (critical)"}
	for kind: String in p["kinds"]:
		var k: Dictionary = p["kinds"][kind]
		var ready := float(k["ready_in"])
		var label: String = names.get(kind, kind)
		var b := UIKit.button(label if ready <= 0.0 else "%s  %s" % [label, UIKit.fmt_time(ready)], func() -> void: _trigger(kind), 18, Vector2(320, 46))
		b.disabled = ready > 0.0 or team > 0.0 or grace > 0.0 or game.my_state() != Vitals.State.ALIVE
		_list.add_child(b)


func _trigger(kind: String) -> void:
	var district := ""
	if game.panel["kinds"][kind]["targets"] == "district" and _district.selected >= 0:
		district = _districts[_district.selected]
	NetworkManager.send_action("sabotage", 0, "%s|%s" % [kind, district])
