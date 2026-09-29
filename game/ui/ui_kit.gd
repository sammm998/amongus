class_name UIKit
extends RefCounted
## Small helpers for building the original UI language in code.


static func panel(min_size: Vector2 = Vector2.ZERO, alpha: float = 0.82) -> PanelContainer:
	var p := PanelContainer.new()
	var box := UITheme.panel_box()
	box.bg_color = Color(UITheme.PANEL, alpha)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_size = 6
	p.add_theme_stylebox_override("panel", box)
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String = "", size: int = 18, color: Color = UITheme.TEXT, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.08, 0.85))
		l.add_theme_constant_override("outline_size", maxi(4, size / 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, action: Callable, size: int = 22, min_size: Vector2 = Vector2(0, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


static func bar(color: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_size
	b.show_percentage = false
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.04, 0.08, 0.75)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func color_swatch(color: Color, size: float = 18.0) -> Panel:
	var p := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(size * 0.5))
	box.border_color = Color(1, 1, 1, 0.6)
	box.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", box)
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func suit_colors(index: int) -> Array:
	var list: Array = GameData.table("cosmetics")["base_colors"]
	var c: Dictionary = list[index % list.size()]
	return [Color(c["suit"]), Color(c["accent"])]


static func fmt_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]


static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()
