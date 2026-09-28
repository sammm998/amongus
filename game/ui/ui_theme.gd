class_name UITheme
extends RefCounted
## Original UI language (GAME_SPEC §8.3): dark translucent rounded panels,
## cyan highlights, amber warnings, red danger.

const PANEL := Color(0.05, 0.08, 0.14, 0.82)
const PANEL_BORDER := Color(0.18, 0.89, 0.9, 0.35)
const CYAN := Color(0.18, 0.89, 0.9)
const AMBER := Color(1.0, 0.72, 0.25)
const DANGER := Color(1.0, 0.3, 0.33)
const TEXT := Color(0.94, 0.96, 1.0)
const TEXT_DIM := Color(0.66, 0.73, 0.82)
const BUTTON := Color(0.1, 0.16, 0.26, 0.95)
const BUTTON_HOVER := Color(0.13, 0.25, 0.36, 1.0)
const BUTTON_PRESSED := Color(0.18, 0.89, 0.9, 1.0)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_stylebox("panel", "PanelContainer", panel_box())
	theme.set_stylebox("panel", "Panel", panel_box())
	theme.set_color("font_color", "Label", TEXT)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "Button", _button_box(state))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color(0.03, 0.06, 0.1))
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_font_size("font_size", "Button", 22)
	var edit := _rounded(Color(0.02, 0.04, 0.08, 0.9), 10)
	edit.border_color = PANEL_BORDER
	edit.set_border_width_all(2)
	edit.content_margin_left = 12
	edit.content_margin_right = 12
	edit.content_margin_top = 8
	edit.content_margin_bottom = 8
	theme.set_stylebox("normal", "LineEdit", edit)
	var focus := edit.duplicate() as StyleBoxFlat
	focus.border_color = CYAN
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", CYAN)
	return theme


static func panel_box() -> StyleBoxFlat:
	var box := _rounded(PANEL, 18)
	box.border_color = PANEL_BORDER
	box.set_border_width_all(2)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 12
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box


static func _button_box(state: String) -> StyleBoxFlat:
	var color := BUTTON
	match state:
		"hover", "focus":
			color = BUTTON_HOVER
		"pressed":
			color = BUTTON_PRESSED
		"disabled":
			color = Color(BUTTON, 0.5)
	var box := _rounded(color, 12)
	box.border_color = CYAN if state in ["hover", "focus"] else Color(CYAN, 0.25)
	box.set_border_width_all(2)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box
