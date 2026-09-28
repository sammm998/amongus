extends SceneTree
## Renders a top-down colour map of a HeightField definition for layout work.
## godot --headless --path game -s ../tools/terrain_map.gd -- <map.json> <out.png> [x0 z0 x1 z1] [px_per_m]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var map: Dictionary = GameDataRegistry.read_json(a[0])
	var field := HeightField.new(map["terrain"])
	var builder := TerrainMeshBuilder.new()
	var r := Rect2(-220, -270, 460, 360)
	if a.size() >= 6:
		r = Rect2(float(a[2]), float(a[3]), float(a[4]) - float(a[2]), float(a[5]) - float(a[3]))
	var ppm := float(a[6]) if a.size() >= 7 else 2.0
	var w := int(r.size.x * ppm)
	var h := int(r.size.y * ppm)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for py in h:
		for px in w:
			var x := r.position.x + px / ppm
			var z := r.position.y + py / ppm
			var ht := field.height_at(x, z)
			var c := builder.color_for(ht, field.normal_at(x, z), x, z, field.coast_distance(x, z) - field.beach_width)
			if ht < 0.0:
				c = c.lerp(Color(0.1, 0.5, 0.7), clampf(-ht / 8.0, 0.2, 0.85))
			if int(x) % 20 == 0 or int(z) % 20 == 0:
				c = c.darkened(0.15)
			if absf(x) < 0.6 or absf(z) < 0.6:
				c = Color.RED
			img.set_pixel(px, py, c)
	var to_px := func(x: float, z: float) -> Vector2i: return Vector2i(int((x - r.position.x) * ppm), int((z - r.position.y) * ppm))
	for b: Dictionary in map.get("buildings", []):
		var p0: Vector2i = to_px.call(float(b["x"]) - float(b["w"]) * 0.5, float(b["z"]) - float(b["d"]) * 0.5)
		var p1: Vector2i = to_px.call(float(b["x"]) + float(b["w"]) * 0.5, float(b["z"]) + float(b["d"]) * 0.5)
		for x in range(p0.x, p1.x):
			for y in [p0.y, p1.y]:
				if x >= 0 and x < w and y >= 0 and y < h:
					img.set_pixel(x, y, Color.BLACK)
		for y in range(p0.y, p1.y):
			for x in [p0.x, p1.x]:
				if x >= 0 and x < w and y >= 0 and y < h:
					img.set_pixel(x, y, Color.BLACK)
	var wps: Dictionary = map.get("waypoints", {})
	for e: Array in map.get("edges", []):
		var a0: Array = wps[e[0]]
		var a1: Array = wps[e[1]]
		for i in 60:
			var t := i / 59.0
			var q: Vector2i = to_px.call(lerpf(a0[0], a1[0], t), lerpf(a0[1], a1[1], t))
			if q.x >= 0 and q.x < w and q.y >= 0 and q.y < h:
				img.set_pixel(q.x, q.y, Color.MAGENTA)
	for sdef: Dictionary in map.get("stations", []):
		var q: Vector2i = to_px.call(float(sdef["x"]), float(sdef["z"]))
		img.fill_rect(Rect2i(q - Vector2i(2, 2), Vector2i(5, 5)), Color.YELLOW)
	img.save_png(a[1])
	print("saved ", a[1], " ", w, "x", h)
	quit()
