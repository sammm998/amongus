class_name Minimap
extends Control
## Top-left minimap: districts, roads, own position/heading, own task targets.
## Never shows other players (GAME_SPEC §5.8).

var map: MapData
var game: ClientGameState
var center := Vector3.ZERO
var heading := 0.0
var metres := 260.0  # visible span


var _layer: Control


func _ready() -> void:
	# Everything is drawn on a child clipped to the round background.
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.draw.connect(_draw_content)
	add_child(_layer)


func _draw() -> void:
	draw_circle(size * 0.5, size.x * 0.5, Color(0.05, 0.12, 0.2, 0.85))
	if _layer != null:
		_layer.queue_redraw()


func _draw_content() -> void:
	if map == null:
		return
	var r := size.x * 0.5
	var c := size * 0.5
	var scale := size.x / metres
	var to_px := func(p: Vector3) -> Vector2:
		var d := Vector2(p.x - center.x, p.z - center.z) * scale
		return c + d
	for d: Dictionary in map.districts:
		if d["id"] == "roads":
			continue
		var pc: Vector2 = to_px.call(Vector3(float(d["x"]), 0, float(d["z"])))
		var col := Color(d["accent"])
		col.a = 0.35 if not game.district_dark(d["id"]) else 0.08
		_layer.draw_circle(pc, float(d["radius"]) * scale, col)
	for road: Array in map.raw.get("roads", []):
		for i in road.size() - 1:
			var a: Vector2 = to_px.call(Vector3(road[i][0], 0, road[i][1]))
			var b: Vector2 = to_px.call(Vector3(road[i + 1][0], 0, road[i + 1][1]))
			_layer.draw_line(a, b, Color(0.8, 0.8, 0.8, 0.5), 3.0)
	for b: Dictionary in map.raw.get("buildings", []):
		var p0: Vector2 = to_px.call(Vector3(float(b["x"]) - float(b["w"]) * 0.5, 0, float(b["z"]) - float(b["d"]) * 0.5))
		var p1: Vector2 = to_px.call(Vector3(float(b["x"]) + float(b["w"]) * 0.5, 0, float(b["z"]) + float(b["d"]) * 0.5))
		_layer.draw_rect(Rect2(p0, p1 - p0), Color(0.9, 0.95, 1.0, 0.55))
	if game.my_state() == Vitals.State.ALIVE:
		for t: Dictionary in game.tasks:
			if not t["done"] and map.stations.has(t["station"]):
				var tp: Vector2 = to_px.call(map.station_pos(t["station"]))
				if tp.distance_to(c) > r - 6:
					tp = c + (tp - c).normalized() * (r - 6)
				_layer.draw_circle(tp, 5.0, UITheme.AMBER)
	var fwd := Vector2(-sin(heading), -cos(heading))
	var side := Vector2(fwd.y, -fwd.x)
	_layer.draw_colored_polygon(PackedVector2Array([c + fwd * 11, c - fwd * 7 + side * 7, c - fwd * 7 - side * 7]), UITheme.CYAN)
	_layer.draw_arc(c, r - 1, 0, TAU, 64, UITheme.PANEL_BORDER, 2.0)
