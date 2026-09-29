class_name CameraTerminal
extends Control
## Security camera monitor wall (GAME_SPEC §5.8): live render views of the world
## with no name tags or role markers; jammed/unpowered feeds show SIGNAL LOST.
## REPLAY plays back the last 10 s recorded by the server as positions/poses
## (ghost suits only visible to that feed). Feeds render only while open.

signal closed

const GHOST_LAYER := RenderLayers.REPLAY_GHOSTS

var game: ClientGameState
var map: MapData
var camera_points: Dictionary
var world_3d: World3D
var ghost_root: Node3D
var _grid: GridContainer
var _feeds: Dictionary = {}  # id -> {viewport, camera, static, box, district, label, replay: {frames, t, ghosts}}
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
	head.add_child(UIKit.label("Tap a feed to enlarge · REPLAY = last 10 s   ", 15, UITheme.TEXT_DIM))
	head.add_child(UIKit.button("EXIT", func() -> void: close(), 24, Vector2(160, 56)))
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_grid)
	for c: Dictionary in map.raw.get("cameras", []):
		_add_feed(c)
	game.replay_received.connect(_on_replay)
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
	cam.cull_mask = RenderLayers.LIVE_FEED
	vp.add_child(cam)
	var static_rect := ColorRect.new()
	static_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	static_rect.color = Color(0.1, 0.1, 0.12)
	static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(static_rect)
	var lost := UIKit.label("SIGNAL LOST", 30, UITheme.DANGER)
	lost.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	static_rect.add_child(lost)
	var label := UIKit.label(c["label"], 16, Color.WHITE)
	label.position = Vector2(8, 6)
	box.add_child(label)
	var replay_btn := UIKit.button("REPLAY", func() -> void: NetworkManager.send_action("replay", 0, c["id"]), 14, Vector2(96, 34))
	replay_btn.position = Vector2(8, 34)
	box.add_child(replay_btn)
	box.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_expanded = "" if _expanded == c["id"] else c["id"]
			_layout())
	_grid.add_child(box)
	_feeds[c["id"]] = {"viewport": vp, "camera": cam, "static": static_rect, "lost": lost, "box": box, "district": c["district"], "label": label, "title": c["label"], "replay": {}}


func open() -> void:
	visible = true
	_expanded = ""
	_layout()


func close() -> void:
	visible = false
	for id: String in _feeds:
		_stop_replay(id)
		(_feeds[id]["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func _layout() -> void:
	_grid.columns = 1 if not _expanded.is_empty() else 2
	for id: String in _feeds:
		_feeds[id]["box"].visible = _expanded.is_empty() or _expanded == id


func _on_replay(p: Dictionary) -> void:
	var id: String = p["camera"]
	if not _feeds.has(id) or not visible:
		return
	_stop_replay(id)
	var frames: Array = p["frames"]
	if frames.is_empty():
		return
	var f: Dictionary = _feeds[id]
	f["replay"] = {"frames": frames, "t": float(frames[0][0]), "ghosts": {}}
	(f["camera"] as Camera3D).cull_mask = RenderLayers.REPLAY_FEED


func _stop_replay(id: String) -> void:
	var f: Dictionary = _feeds[id]
	var r: Dictionary = f["replay"]
	for g: Node in r.get("ghosts", {}).values():
		g.queue_free()
	f["replay"] = {}
	(f["camera"] as Camera3D).cull_mask = RenderLayers.LIVE_FEED
	(f["label"] as Label).text = f["title"]


func _ghost(r: Dictionary, pid: int) -> Astronaut:
	var ghosts: Dictionary = r["ghosts"]
	if ghosts.has(pid):
		return ghosts[pid]
	var a := Astronaut.new()
	var colors := UIKit.suit_colors(game.player_color(pid))
	a.suit_color = colors[0]
	a.accent_color = colors[1]
	ghost_root.add_child(a)
	a.set_render_layers(GHOST_LAYER)
	ghosts[pid] = a
	return a


func _process(delta: float) -> void:
	if not visible:
		return
	for id: String in _feeds:
		var f: Dictionary = _feeds[id]
		var static_rect: ColorRect = f["static"]
		var vp: SubViewport = f["viewport"]
		var r: Dictionary = f["replay"]
		var jammed := game.camera_jammed(f["district"])
		if not r.is_empty():
			jammed = _step_replay(id, f, r, delta)
		static_rect.visible = jammed
		if jammed:
			static_rect.color = Color.from_hsv(0, 0, randf_range(0.05, 0.22))
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if jammed or not f["box"].visible else SubViewport.UPDATE_ALWAYS


## Advances playback; returns true while the recording has a gap (jammed/unpowered).
func _step_replay(id: String, f: Dictionary, r: Dictionary, delta: float) -> bool:
	r["t"] = float(r["t"]) - delta
	var frames: Array = r["frames"]
	if float(r["t"]) < float(frames[-1][0]):
		_stop_replay(id)
		return false
	var current: Array = frames[0]
	for fr: Array in frames:
		if float(fr[0]) >= float(r["t"]):
			current = fr
	(f["label"] as Label).text = "%s — REPLAY -%.0fs" % [f["title"], float(r["t"])]
	(f["lost"] as Label).text = "NO RECORDING" if current[1] == null else "SIGNAL LOST"
	var seen := {}
	if current[1] != null:
		for e: Array in current[1]:
			var g := _ghost(r, e[0])
			g.visible = true
			g.global_position = e[1]
			g.rotation.y = float(e[2]) + PI
			g.downed = int(e[3]) != Vitals.State.ALIVE
			g.move_blend = 0.4
			seen[e[0]] = true
	for pid: int in r["ghosts"]:
		if not seen.has(pid):
			(r["ghosts"][pid] as Node3D).visible = false
	return current[1] == null


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()
