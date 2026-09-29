class_name TouchControls
extends Control
## First-class touch controls (GAME_SPEC §8.1): floating joystick on the left
## half (push to the edge = sprint), swipe-to-look on the right half, and big
## buttons: FIRE, AIM, JUMP, CROUCH, RELOAD, CONTEXT, weapon slots, flashlight.

const JOY_RADIUS := 90.0
const SPRINT_EDGE := 0.92

var state: TouchInputState
var context_label := ""
var inspect_label := ""
var context_progress := 0.0
var flashlight_available := false
var buttons: Array = []  # [{id, center: Vector2 (relative 0..1 from bottom-right), radius, label, toggle}]
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_index := -1
var _button_touch: Dictionary = {}  # touch index -> button id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Positions are offsets from the bottom-right corner in pixels (canvas units).
	buttons = [
		{"id": "fire", "offset": Vector2(-150, -190), "radius": 62.0, "label": "FIRE"},
		{"id": "aim", "offset": Vector2(-290, -250), "radius": 44.0, "label": "AIM"},
		{"id": "jump", "offset": Vector2(-70, -80), "radius": 46.0, "label": "JUMP"},
		{"id": "crouch", "offset": Vector2(-190, -70), "radius": 40.0, "label": "CROUCH"},
		{"id": "reload", "offset": Vector2(-70, -300), "radius": 38.0, "label": "RELOAD"},
		{"id": "interact", "offset": Vector2(-300, -110), "radius": 50.0, "label": "USE"},
		{"id": "flashlight", "offset": Vector2(-70, -410), "radius": 32.0, "label": "LIGHT"},
		{"id": "inspect", "offset": Vector2(-420, -160), "radius": 40.0, "label": "INSPECT"},
	]


func _button_center(b: Dictionary) -> Vector2:
	return size + (b["offset"] as Vector2)


func _visible_button(b: Dictionary) -> bool:
	if b["id"] == "flashlight":
		return flashlight_available
	if b["id"] == "interact":
		return not context_label.is_empty()
	if b["id"] == "inspect":
		return not inspect_label.is_empty()
	return true


func _input(event: InputEvent) -> void:
	if not visible or state == null:
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			for b: Dictionary in buttons:
				if _visible_button(b) and pos.distance_to(_button_center(b)) <= float(b["radius"]) * 1.15:
					_button_touch[event.index] = b["id"]
					state.set_held(b["id"], true)
					if b["id"] == "fire" and _look_index < 0:
						_look_index = event.index  # fire button also steers the view
					queue_redraw()
					return
			if _slot_at(pos) >= 0:
				state.slot_request = _slot_at(pos)
				return
			if pos.x < size.x * 0.45 and _joy_index < 0:
				_joy_index = event.index
				_joy_origin = pos
				_joy_pos = pos
			elif _look_index < 0:
				_look_index = event.index
		else:
			if _button_touch.has(event.index):
				state.set_held(_button_touch[event.index], false)
				_button_touch.erase(event.index)
			if event.index == _joy_index:
				_joy_index = -1
				state.move = Vector2.ZERO
				state.sprint = false
			if event.index == _look_index:
				_look_index = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.index == _joy_index:
			_joy_pos = pos
			var v := (pos - _joy_origin) / JOY_RADIUS
			state.sprint = v.length() >= SPRINT_EDGE
			v = v.limit_length(1.0)
			state.move = Vector2(v.x, -v.y)
			queue_redraw()
		elif event.index == _look_index:
			state.add_look(event.relative)


func _slot_at(pos: Vector2) -> int:
	for i in 5:
		if _slot_rect(i).has_point(pos):
			return i
	return -1


func _slot_rect(i: int) -> Rect2:
	var w := 64.0
	return Rect2(Vector2(size.x * 0.5 - 2.5 * w - 8 + i * (w + 4), size.y - w - 14), Vector2(w, w))


func _draw() -> void:
	if state == null:
		return
	var font := get_theme_default_font()
	if _joy_index >= 0:
		draw_circle(_joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.10))
		draw_arc(_joy_origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		var knob := _joy_origin + (_joy_pos - _joy_origin).limit_length(JOY_RADIUS)
		draw_circle(knob, 36, Color(UITheme.CYAN, 0.55 if not state.sprint else 0.9))
	else:
		var hint := Vector2(160, size.y - 170)
		draw_arc(hint, JOY_RADIUS * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
	for b: Dictionary in buttons:
		if not _visible_button(b):
			continue
		var c := _button_center(b)
		var r := float(b["radius"])
		var held := state.is_held(b["id"])
		var fill := Color(UITheme.PANEL, 0.55)
		if held:
			fill = Color(UITheme.CYAN, 0.6)
		if b["id"] == "fire":
			fill = Color(UITheme.DANGER, 0.7 if held else 0.45)
		draw_circle(c, r, fill)
		draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
		var text: String = b["label"]
		if b["id"] == "interact":
			text = context_label
			if context_progress > 0.0:
				draw_arc(c, r + 6, -PI * 0.5, -PI * 0.5 + TAU * context_progress, 40, UITheme.CYAN, 6.0)
		var fs := 18 if text.length() <= 6 else 13
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, c - Vector2(ts.x * 0.5, -fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)
	for i in 5:
		var rect := _slot_rect(i)
		draw_rect(rect, Color(UITheme.PANEL, 0.5))
		draw_rect(rect, Color(1, 1, 1, 0.35), false, 2.0)
		draw_string(font, rect.position + Vector2(rect.size.x * 0.5 - 5, rect.size.y * 0.6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


func release_all() -> void:
	_joy_index = -1
	_look_index = -1
	_button_touch.clear()
	if state != null:
		state.release_all()
	queue_redraw()
