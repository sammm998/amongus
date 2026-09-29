class_name FullMap
extends Control
## Full map (M): districts, roads, buildings, own position, pings, and the
## activity map — delayed, approximate blips per district, never exact
## positions or names (GAME_SPEC §5.8). Offline while comms are down.

var map: MapData
var game: ClientGameState
var own_pos := Vector3.ZERO
var heading := 0.0
var pings: Array = []  # [pos, kind, name, time]
var _t := 0.0

const BLIP_TEXT := {"gunfire": "GUNFIRE DETECTED", "power_outage": "POWER OUTAGE", "door_breach": "DOOR BREACH", "vehicle": "VEHICLE ACTIVITY", "aircraft": "AIRCRAFT"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


var _silhouette: ImageTexture


## Map area: the playable boundary ellipse (falls back to the slice extent).
func _bounds() -> Rect2:
	var b: Dictionary = map.raw.get("boundary", {})
	if b.is_empty():
		return Rect2(-220, -170, 440, 320)
	return Rect2(float(b["x"]) - float(b["rx"]), float(b["z"]) - float(b["rz"]), float(b["rx"]) * 2.0, float(b["rz"]) * 2.0)


## Island silhouette from the terrain, baked once into a small texture.
func _bake_silhouette(bounds: Rect2) -> ImageTexture:
	var w := 220
	var h := maxi(1, int(w * bounds.size.y / bounds.size.x))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for py in h:
		for px in w:
			var x := bounds.position.x + (px + 0.5) * bounds.size.x / w
			var z := bounds.position.y + (py + 0.5) * bounds.size.y / h
			var ht := map.height(x, z)
			var c := Color(0, 0, 0, 0)
			if ht > 0.0:
				c = Color(0.2, 0.42, 0.25) if ht > 2.0 else Color(0.85, 0.78, 0.6)
				if ht > 14.0:
					c = c.lerp(Color(0.45, 0.45, 0.42), clampf((ht - 14.0) / 20.0, 0.0, 1.0))
			img.set_pixel(px, py, c)
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.1, 0.9))
	var bounds := _bounds()
	var scale := minf((size.x - 80) / bounds.size.x, (size.y - 120) / bounds.size.y)
	var origin := Vector2((size.x - bounds.size.x * scale) * 0.5, 70)
	var to_px := func(x: float, z: float) -> Vector2: return origin + (Vector2(x, z) - bounds.position) * scale
	var font := get_theme_default_font()
	draw_string(font, Vector2(30, 44), "ISLAND MAP  ·  ACTIVITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UITheme.CYAN)
	if _silhouette == null:
		_silhouette = _bake_silhouette(bounds)
	draw_texture_rect(_silhouette, Rect2(origin, bounds.size * scale), false)
	for road: Array in map.raw.get("roads", []):
		for i in road.size() - 1:
			draw_line(to_px.call(road[i][0], road[i][1]), to_px.call(road[i + 1][0], road[i + 1][1]), Color(0.3, 0.3, 0.32), 4.0)
	for b: Dictionary in map.raw.get("buildings", []):
		var p0: Vector2 = to_px.call(float(b["x"]) - float(b["w"]) * 0.5, float(b["z"]) - float(b["d"]) * 0.5)
		var p1: Vector2 = to_px.call(float(b["x"]) + float(b["w"]) * 0.5, float(b["z"]) + float(b["d"]) * 0.5)
		draw_rect(Rect2(p0, p1 - p0), Color(0.92, 0.94, 0.98))
	var district_pos := {}
	for d: Dictionary in map.districts:
		if d["id"] == "roads":
			continue
		var c: Vector2 = to_px.call(float(d["x"]), float(d["z"]))
		district_pos[d["id"]] = c
		draw_arc(c, float(d["radius"]) * scale, 0, TAU, 48, Color(d["accent"], 0.7), 2.0)
		draw_string(font, c + Vector2(-60, -float(d["radius"]) * scale - 6), String(d["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	# Activity blips: approximate (district circle), delayed, anonymous.
	if game.comms_up:
		var offsets := {}
		for b: Dictionary in game.activity:
			var c: Vector2 = district_pos.get(b["district"], Vector2(-1000, -1000))
			var n: int = offsets.get(b["district"], 0)
			offsets[b["district"]] = n + 1
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			var fade := clampf(1.0 - float(b["age"]) / 60.0, 0.25, 1.0)
			var col := UITheme.DANGER if b["kind"] == "gunfire" else UITheme.AMBER
			draw_circle(c, 10.0 + pulse * 8.0, Color(col, 0.35 * fade))
			draw_string(font, c + Vector2(-80, 24 + n * 18), "%s (%ds ago)" % [BLIP_TEXT.get(b["kind"], b["kind"]), int(b["age"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col, fade))
	else:
		draw_string(font, Vector2(30, size.y - 30), "COMMUNICATION FAILURE — activity map offline", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITheme.DANGER)
	for p: Array in pings:
		var pc: Vector2 = to_px.call(p[0].x, p[0].z)
		draw_circle(pc, 6, UITheme.CYAN)
		draw_string(font, pc + Vector2(8, 4), "%s: %s" % [p[2], String(p[1]).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.CYAN)
	var me: Vector2 = to_px.call(own_pos.x, own_pos.z)
	var fwd := Vector2(-sin(heading), -cos(heading))
	var side := Vector2(fwd.y, -fwd.x)
	draw_colored_polygon(PackedVector2Array([me + fwd * 12, me - fwd * 8 + side * 8, me - fwd * 8 - side * 8]), Color.WHITE)
	draw_string(font, Vector2(30, size.y - 60), "Blips are delayed 5–15 s and only show the district. Press M to close.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.TEXT_DIM)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		visible = false
