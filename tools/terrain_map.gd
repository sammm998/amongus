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
			var c := builder.color_for(ht, field.normal_at(x, z), x, z)
			if ht < 0.0:
				c = c.lerp(Color(0.1, 0.5, 0.7), clampf(-ht / 8.0, 0.2, 0.85))
			if int(x) % 20 == 0 or int(z) % 20 == 0:
				c = c.darkened(0.15)
			if absf(x) < 0.6 or absf(z) < 0.6:
				c = Color.RED
			img.set_pixel(px, py, c)
	img.save_png(a[1])
	print("saved ", a[1], " ", w, "x", h)
	quit()
