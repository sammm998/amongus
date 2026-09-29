class_name RoleReveal
extends Control
## Fade to black -> big role card with subtitle and fellow Traitors (GAME_SPEC §5.1).

var game: ClientGameState
var _black: ColorRect
var _card: VBoxContainer
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 16)
	center.add_child(_card)


func play() -> void:
	visible = true
	_t = 0.0
	UIKit.clear(_card)
	var traitor := game.role == "traitor"
	var title := UIKit.label("YOU ARE A TRAITOR" if traitor else "YOU ARE AN AGENT", 64, UITheme.DANGER if traitor else UITheme.CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(title)
	var sub := UIKit.label("Blend in. Sabotage the island. Eliminate the Agents." if traitor else "Protect the island. Find the Traitors. Do not trust everyone.", 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(sub)
	if traitor and not game.allies.is_empty():
		_card.add_child(UIKit.label("FELLOW TRAITORS", 18, UITheme.TEXT_DIM))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		for a: Dictionary in game.allies:
			var box := VBoxContainer.new()
			box.alignment = BoxContainer.ALIGNMENT_CENTER
			var c := CenterContainer.new()
			c.add_child(UIKit.color_swatch(UIKit.suit_colors(int(a["color"]))[0], 48))
			box.add_child(c)
			box.add_child(UIKit.label(a["name"], 20))
			row.add_child(box)
		_card.add_child(row)
	elif traitor:
		_card.add_child(UIKit.label("You are the only Traitor.", 18, UITheme.TEXT_DIM))
	_card.modulate.a = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_card.modulate.a = clampf((_t - 0.6) / 0.6, 0.0, 1.0) * clampf(1.0 - (_t - 6.0) / 1.0, 0.0, 1.0)
	_black.color.a = 1.0 if _t < 5.5 else clampf(1.0 - (_t - 5.5) / 1.2, 0.0, 1.0)
	if _t > 7.2:
		visible = false
