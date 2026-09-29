extends SceneTree
## Bakes the height cache (data/maps/<id>.heights) for maps with a "grid" entry.
## Usage: godot --headless --path game --script res://tools/bake_maps.gd


func _init() -> void:
	for id: String in ["island"]:
		var t := Time.get_ticks_msec()
		var m := MapData.load_map(id)
		print("%s: grid %dx%d in %d ms" % [id, m.grid.width, m.grid.depth, Time.get_ticks_msec() - t])
	quit()
