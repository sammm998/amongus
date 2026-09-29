class_name ResultsPanel
extends Control
## Match results (GAME_SPEC §8.4): winner, every role revealed, per-player
## stats and the match timeline.

signal leave_pressed

var game: ClientGameState
var _content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)


func show_results(r: Dictionary) -> void:
	visible = true
	UIKit.clear(_content)
	var winner: String = r["winner"]
	var my_role := game.role
	var won := (winner == "agents" and my_role == "agent") or (winner == "traitors" and my_role == "traitor")
	var banner := UIKit.label("%s WIN" % winner.to_upper(), 56, UITheme.CYAN if winner == "agents" else UITheme.DANGER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(banner)
	var reasons := {
		"all_traitors_eliminated": "Every Traitor was eliminated.", "security_complete": "Island Security reached 100%.",
		"island_control_lost": "ISLAND CONTROL LOST — the power failure was never repaired.",
		"traitors_outnumber": "The Traitors matched the living Agents.", "time_limit": "Time ran out — the Traitors survived.",
	}
	var sub := UIKit.label("%s   %s" % [reasons.get(r["reason"], r["reason"]), ("You won!" if won else "You lost.") if not my_role.is_empty() else ""], 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(sub)
	var table := GridContainer.new()
	table.columns = 7
	table.add_theme_constant_override("h_separation", 22)
	_content.add_child(table)
	for h in ["", "PLAYER", "ROLE", "STATUS", "TASKS", "DOWNS", "REPORTS"]:
		table.add_child(UIKit.label(h, 16, UITheme.TEXT_DIM))
	for p: Dictionary in r["players"]:
		var colors := UIKit.suit_colors(int(p["color"]))
		table.add_child(UIKit.color_swatch(colors[0], 22))
		table.add_child(UIKit.label(p["name"] + (" (bot)" if p["bot"] else ""), 20))
		table.add_child(UIKit.label(String(p["role"]).to_upper(), 20, UITheme.DANGER if p["role"] == "traitor" else UITheme.CYAN))
		table.add_child(UIKit.label(String(p["state"]).to_upper(), 18, UITheme.TEXT_DIM))
		table.add_child(UIKit.label(str(p["stats"]["tasks"]), 18))
		table.add_child(UIKit.label(str(p["stats"]["downs"]), 18))
		table.add_child(UIKit.label(str(p["stats"]["reports"]), 18))
	_content.add_child(UIKit.label("MATCH TIMELINE", 22, UITheme.AMBER))
	for line: Dictionary in r["timeline"]:
		_content.add_child(UIKit.label("%s   %s" % [UIKit.fmt_time(float(line["t"])), line["text"]], 17))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(UIKit.button("LEAVE MATCH", func() -> void: leave_pressed.emit(), 22, Vector2(240, 60)))
	_content.add_child(buttons)
	_content.add_child(UIKit.label("The lobby reopens automatically in a few seconds.", 16, UITheme.TEXT_DIM))
