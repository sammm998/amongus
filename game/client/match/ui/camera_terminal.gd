class_name CameraTerminal
extends Control
## Security camera monitor wall (GAME_SPEC §5.8): live render views of the world
## with no name tags or role markers; jammed/unpowered feeds show SIGNAL LOST.
## Feeds only render while this screen is open.

signal closed

var game: ClientGameState
var map: MapData
var camera_points: Dictionary
var world_3d: World3D
var _grid: GridContainer
var _feeds: Dictionary = {}  # id -> {viewport, static, label, district}
var _expanded := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_right = -20
	col.offset_top = 16
	col.offset_bottom = -16
	add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UIKit.label("SECURITY CAMERAS", 28, UITheme.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.button("EXIT", func() -> void: close(), 24, Vector2(160, 56)))
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_grid)
	for c: Dictionary in map.raw.get("cameras", []):
		_add_feed(c)
	visible = false


func _add_feed(c: Dictionary) -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := SubViewport.new()
	vp.world_3d = world_3d
	vp.size = Vector2i(480, 270)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	box.add_child(vp)
	var cam := Camera3D.new()
	cam.transform = camera_points[c["id"]]
	cam.fov = 70.0
	cam.cull_mask = 1  # layer 1 only: no name tags
	vp.add_child(cam)
	var static_rect := ColorRect.new()
	static_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	static_rect.color = Color(0.1, 0.1, 0.12)
	static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(static_rect)
	var lost := UIKit.label("SIGNAL LOST", 30, UITheme.DANGER)
	lost.set_anchors_preset(Control.PRESET_CENTER)
	static_rect.add_child(lost)
	var label := UIKit.label(c["label"], 16, Color.WHITE)
	label.position = Vector2(8, 6)
	box.add_child(label)
	box.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_expanded = "" if _expanded == c["id"] else c["id"]
			_layout())
	_grid.add_child(box)
	_feeds[c["id"]] = {"viewport": vp, "static": static_rect, "box": box, "district": c["district"]}


func open() -> void:
	visible = true
	_expanded = ""
	_layout()


func close() -> void:
	visible = false
	for f: Dictionary in _feeds.values():
		(f["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func _layout() -> void:
	_grid.columns = 1 if not _expanded.is_empty() else 2
	for id: String in _feeds:
		_feeds[id]["box"].visible = _expanded.is_empty() or _expanded == id


func _process(_delta: float) -> void:
	if not visible:
		return
	for id: String in _feeds:
		var f: Dictionary = _feeds[id]
		var jammed := game.camera_jammed(f["district"])
		var static_rect: ColorRect = f["static"]
		static_rect.visible = jammed
		if jammed:
			static_rect.color = Color.from_hsv(0, 0, randf_range(0.05, 0.22))
		var vp: SubViewport = f["viewport"]
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if jammed or not f["box"].visible else SubViewport.UPDATE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()
