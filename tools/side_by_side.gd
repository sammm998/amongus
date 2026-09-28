extends SceneTree
## godot --headless -s tools/side_by_side.gd -- <left.png> <right.png> <out.png> [height]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var h := int(a[3]) if a.size() > 3 else 540
	var imgs: Array[Image] = []
	for p in [a[0], a[1]]:
		var img := Image.load_from_file(p)
		img.resize(int(img.get_width() * float(h) / img.get_height()), h, Image.INTERPOLATE_LANCZOS)
		img.convert(Image.FORMAT_RGB8)
		imgs.append(img)
	var out := Image.create(imgs[0].get_width() + imgs[1].get_width() + 8, h, false, Image.FORMAT_RGB8)
	out.fill(Color.BLACK)
	out.blit_rect(imgs[0], Rect2i(Vector2i.ZERO, imgs[0].get_size()), Vector2i.ZERO)
	out.blit_rect(imgs[1], Rect2i(Vector2i.ZERO, imgs[1].get_size()), Vector2i(imgs[0].get_width() + 8, 0))
	out.save_png(a[2])
	print("saved ", a[2])
	quit()
