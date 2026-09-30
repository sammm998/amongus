class_name MapBuilder
extends RefCounted
## Builds a playable map from MapData. With `visuals = false` only collision is
## created (dedicated/listen server world). Collision layer 1 = world.

const WORLD_LAYER := 1
## Extra layer on everything solid except the terrain: vehicles collide with
## these and follow the ground through the (baked) height function instead.
const STRUCTURE_LAYER := 16
const DOOR_HEIGHT := 3.0
const WALL := 0.4

const STYLES := {
	"command": {"wall": Color(0.88, 0.9, 0.94), "trim": Color(0.12, 0.2, 0.36), "roof": Color(0.2, 0.26, 0.36), "floor": Color(0.55, 0.6, 0.66), "glow": MeshKit.SLOT_GLOW_CYAN},
	"medical": {"wall": Color(0.96, 0.97, 0.97), "trim": Color(0.1, 0.66, 0.62), "roof": Color(0.8, 0.84, 0.84), "floor": Color(0.82, 0.88, 0.88), "glow": MeshKit.SLOT_GLOW},
	"warehouse": {"wall": Color(0.22, 0.4, 0.6), "trim": Color(0.66, 0.34, 0.18), "roof": Color(0.5, 0.5, 0.52), "floor": Color(0.45, 0.45, 0.47), "glow": MeshKit.SLOT_GLOW},
	"industrial": {"wall": Color(0.62, 0.64, 0.66), "trim": Color(0.95, 0.5, 0.12), "roof": Color(0.4, 0.42, 0.44), "floor": Color(0.4, 0.4, 0.42), "glow": MeshKit.SLOT_GLOW},
	"house": {"wall": Color(0.94, 0.89, 0.78), "trim": Color(0.97, 0.97, 0.95), "roof": Color(0.72, 0.2, 0.15), "floor": Color(0.6, 0.45, 0.3), "glow": MeshKit.SLOT_GLOW, "pitched": true},
	"house_blue": {"wall": Color(0.56, 0.72, 0.86), "trim": Color(0.97, 0.97, 0.95), "roof": Color(0.28, 0.3, 0.35), "floor": Color(0.6, 0.45, 0.3), "glow": MeshKit.SLOT_GLOW, "pitched": true},
	"barn": {"wall": Color(0.66, 0.17, 0.12), "trim": Color(0.95, 0.94, 0.9), "roof": Color(0.35, 0.34, 0.33), "floor": Color(0.5, 0.4, 0.3), "glow": MeshKit.SLOT_GLOW, "pitched": true},
	"hut": {"wall": Color(0.62, 0.45, 0.3), "trim": Color(0.42, 0.3, 0.2), "roof": Color(0.8, 0.66, 0.4), "floor": Color(0.55, 0.42, 0.3), "glow": MeshKit.SLOT_GLOW},
}


## Result node exposes metadata used by the client/server:
##   "district_lights": {district: [Light3D]}, "station_nodes": {id: Node3D},
##   "camera_points": {id: Transform3D}
static func build(map: MapData, visuals: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "MapWorld"
	var statics := StaticBody3D.new()
	statics.name = "WorldCollision"
	statics.collision_layer = WORLD_LAYER | STRUCTURE_LAYER
	statics.collision_mask = 0
	root.add_child(statics)
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_body.collision_layer = WORLD_LAYER
	terrain_body.collision_mask = 0
	root.add_child(terrain_body)
	var col: Dictionary = map.raw["collision"]
	var center := Vector2(float(col["center"][0]), float(col["center"][1]))
	if map.grid != null:
		for tile: CollisionShape3D in TerrainMeshBuilder.build_grid_collision(map.grid):
			terrain_body.add_child(tile)
	else:
		terrain_body.add_child(TerrainMeshBuilder.build_collision(map.field, center, int(col["size"])))
	_boundary(map, statics)
	_tree_collision(map, root)
	_landmarks(map, root, statics, visuals)
	var district_lights := {}
	var station_nodes := {}
	var doors := {}
	var kit := MeshKit.new() if visuals else null
	for b: Dictionary in map.raw.get("buildings", []):
		_building(map, b, statics, kit, root, district_lights)
		doors[b["id"]] = _doors(map, b, root, visuals)
	for p: Dictionary in map.raw.get("props", []):
		_prop(map, p, statics, kit, root)
	for s: Dictionary in map.raw.get("stations", []):
		var node := _station(map, s, statics, visuals)
		root.add_child(node)
		station_nodes[s["id"]] = node
	var camera_points := {}
	for c: Dictionary in map.raw.get("cameras", []):
		var base := map.ground_point(float(c["x"]), float(c["z"]))
		var eye := base + Vector3(0, float(c["y"]), 0)
		var target := map.ground_point(float(c["tx"]), float(c["tz"])) + Vector3(0, float(c["ty"]), 0)
		camera_points[c["id"]] = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
		if visuals:
			var cam_kit := MeshKit.new()
			cam_kit.add_cylinder(Transform3D(Basis(), base + Vector3(0, float(c["y"]) * 0.5, 0)), 0.08, 0.1, float(c["y"]), Color(0.3, 0.32, 0.35), 6)
			cam_kit.add_box(Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye), Vector3(0.35, 0.3, 0.6), Color(0.9, 0.9, 0.92), MeshKit.SLOT_GLOSS)
			cam_kit.add_sphere(Transform3D(Basis(), eye + Vector3(0, 0.22, 0)), 0.06, Color.RED, 6, MeshKit.SLOT_GLOW_RED)
			root.add_child(cam_kit.to_instance())
	root.set_meta("district_lights", district_lights)
	root.set_meta("station_nodes", station_nodes)
	root.set_meta("camera_points", camera_points)
	root.set_meta("doors", doors)
	if visuals:
		# Paved plazas under facilities (flat pads marked "paved").
		for f: Dictionary in map.raw["terrain"].get("flats", []):
			if f.get("paved", false):
				var fr := float(f["radius"]) * (1.0 - float(f.get("blend", 0.3)) * 0.9)
				kit.add_cylinder(Transform3D(Basis(), Vector3(float(f["x"]), float(f["height"]) + 0.03, float(f["z"]))), fr, fr, 0.06, Color(0.52, 0.52, 0.5), 40)
		root.add_child(kit.to_instance())
		_terrain_visuals(map, root)
		_roads(map, root, district_lights)
		_vegetation(map, root)
	return root


static func _terrain_visuals(map: MapData, root: Node3D) -> void:
	var rect := map.terrain_rect()
	var builder := TerrainMeshBuilder.new()
	# Chunks of <= 256 m so off-screen parts are culled; ~2.3 m (slice) / 4 m cells.
	var chunk_m := 256.0
	var nx := int(ceil(rect.size.x / chunk_m))
	var nz := int(ceil(rect.size.y / chunk_m))
	var cell := 4.0 if map.grid != null else rect.size.x / 240.0
	for cz in nz:
		for cx in nx:
			var o := rect.position + Vector2(cx, cz) * chunk_m
			var sz := Vector2(minf(chunk_m, rect.end.x - o.x), minf(chunk_m, rect.end.y - o.y))
			var mi := MeshInstance3D.new()
			mi.name = "Terrain_%d_%d" % [cx, cz]
			mi.mesh = builder.build_mesh(map, o, sz, maxi(8, int(ceil(maxf(sz.x, sz.y) / cell))))
			root.add_child(mi)
	var to_sun := Vector3(0.72, 0.075, -0.69)
	if map.raw.has("sun_direction"):
		var s: Array = map.raw["sun_direction"]
		to_sun = Vector3(s[0], s[1], s[2])
	# Distant backdrop terrain outside the playable grid (e.g. the volcano isle).
	for ft: Dictionary in map.raw.get("far_terrain", []):
		var fmi := MeshInstance3D.new()
		fmi.name = "FarTerrain"
		fmi.mesh = builder.build_mesh(map.field, Vector2(ft["origin"][0], ft["origin"][1]), Vector2(ft["size"][0], ft["size"][1]), int(ft["res"]))
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fmi)
	var sea := WaterFactory.sea(maxf(3000.0, rect.size.x * 2.5), to_sun, 128)
	sea.name = "Sea"
	root.add_child(sea)
	WaterFactory.bake_depth(sea, map, rect, 1.0 if map.grid == null else 3.0)


## Set pieces from the Sunset Cove look (map "landmarks"): arched hangars,
## radio tower, piers, moored boats, parked jets, sea stacks, volcano smoke.
static func _landmarks(map: MapData, root: Node3D, statics: StaticBody3D, visuals: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for l: Dictionary in map.raw.get("landmarks", []):
		var x := float(l["x"])
		var z := float(l["z"])
		var pos := Vector3(x, float(l["y"]) if l.has("y") else map.height(x, z), z)
		var xf := Transform3D(Basis(Vector3.UP, float(l.get("yaw", 0.0))), pos)
		var node: Node3D = null
		match str(l["kind"]):
			"hangar":
				var w := float(l.get("w", 22.0))
				var len := float(l.get("l", 26.0))
				var wall := float(l.get("h", 4.5))
				_add_box_collider(statics, xf * Transform3D(Basis(), Vector3(0, (wall + w * 0.5) * 0.5, 0)), Vector3(w, wall + w * 0.5, len))
				if visuals:
					node = StructureBuilder.hangar(w, len, wall)
			"radio_tower":
				_add_box_collider(statics, xf * Transform3D(Basis(), Vector3(0, 5.0, 0)), Vector3(5.0, 10.0, 5.0))
				if visuals:
					node = StructureBuilder.radio_tower(float(l.get("h", 44.0)))
			"pier":
				var len := float(l.get("l", 34.0))
				var w := float(l.get("w", 3.4))
				_add_box_collider(statics, xf * Transform3D(Basis(), Vector3(0, 1.12, len * 0.5)), Vector3(w, 0.3, len))
				if visuals:
					node = StructureBuilder.pier(len, w)
			"boat":
				if visuals:
					node = VehicleProps.boat()
			"jet":
				_add_box_collider(statics, xf * Transform3D(Basis(), Vector3(0, 1.2, 0)), Vector3(8.0, 2.4, 7.5))
				if visuals:
					node = VehicleProps.small_jet()
			"sea_stack":
				var sz := float(l.get("size", 8.0))
				var hgt := float(l.get("h", 24.0))
				var shape := CylinderShape3D.new()
				shape.radius = sz * 0.8
				shape.height = hgt + 20.0
				var cs := CollisionShape3D.new()
				cs.shape = shape
				cs.position = pos + Vector3(0, hgt * 0.5 - 10.0, 0)
				statics.add_child(cs)
				if visuals:
					var mi := MeshInstance3D.new()
					mi.mesh = RockBuilder.rock(rng, Vector3(sz, hgt, sz), 0.7)
					node = mi
			"smoke":
				if visuals:
					node = SmokePlume.create(float(l.get("scale", 9.0)), Color(0.72, 0.62, 0.66, 0.7))
		if node != null:
			node.transform = xf
			root.add_child(node)


static func _boundary(map: MapData, statics: StaticBody3D) -> void:
	var b: Dictionary = map.raw.get("boundary", {})
	if b.is_empty():
		return
	var n := int(b["segments"])
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(float(b["x"]) + cos(a0) * float(b["rx"]), 0, float(b["z"]) + sin(a0) * float(b["rz"]))
		var p1 := Vector3(float(b["x"]) + cos(a1) * float(b["rx"]), 0, float(b["z"]) + sin(a1) * float(b["rz"]))
		var mid := (p0 + p1) * 0.5
		var len := p0.distance_to(p1) + 2.0
		var shape := BoxShape3D.new()
		shape.size = Vector3(len, float(b["height"]), 2.0)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var dir := (p1 - p0).normalized()
		cs.transform = Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)), mid + Vector3(0, float(b["height"]) * 0.5 - 16.0, 0))
		statics.add_child(cs)


static func _add_box_collider(statics: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	statics.add_child(cs)


static func _solid(statics: StaticBody3D, kit: MeshKit, center: Vector3, size: Vector3, color: Color, slot: String = MeshKit.SLOT_MATTE) -> void:
	var xf := Transform3D(Basis(), center)
	_add_box_collider(statics, xf, size)
	if kit != null:
		kit.add_box(xf, size, color, slot)


static func _building(map: MapData, b: Dictionary, statics: StaticBody3D, kit: MeshKit, root: Node3D, lights: Dictionary) -> void:
	var style: Dictionary = STYLES.get(b.get("style", "command"), STYLES["command"])
	var cx := float(b["x"])
	var cz := float(b["z"])
	var w := float(b["w"])
	var d := float(b["d"])
	var h := float(b["h"])
	var base := map.height(cx, cz)
	var doors: Array = b.get("doors", [])
	# side -> (start corner, direction along wall, length, outward normal)
	var sides := {
		"n": [Vector3(cx - w * 0.5, 0, cz - d * 0.5), Vector3.RIGHT, w, Vector3.FORWARD],
		"s": [Vector3(cx - w * 0.5, 0, cz + d * 0.5), Vector3.RIGHT, w, Vector3.BACK],
		"w": [Vector3(cx - w * 0.5, 0, cz - d * 0.5), Vector3.BACK, d, Vector3.LEFT],
		"e": [Vector3(cx + w * 0.5, 0, cz - d * 0.5), Vector3.BACK, d, Vector3.RIGHT],
	}
	for side: String in sides:
		var info: Array = sides[side]
		var start: Vector3 = info[0]
		var along: Vector3 = info[1]
		var length: float = info[2]
		var normal: Vector3 = info[3]
		var gaps: Array = []
		for door: Dictionary in doors:
			if door["side"] == side:
				var c := length * 0.5 + float(door.get("offset", 0.0))
				gaps.append([c - float(door["width"]) * 0.5, c + float(door["width"]) * 0.5])
		gaps.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		var cursor := 0.0
		var pieces: Array = []
		for g: Array in gaps:
			pieces.append([cursor, g[0], false])
			pieces.append([g[0], g[1], true])
			cursor = g[1]
		pieces.append([cursor, length, false])
		for piece: Array in pieces:
			var a: float = piece[0]
			var e: float = piece[1]
			if e - a < 0.05:
				continue
			var mid := start + along * ((a + e) * 0.5)
			var size := Vector3(e - a, 0, WALL) if along == Vector3.RIGHT else Vector3(WALL, 0, e - a)
			if piece[2]:
				# Door gap: lintel above the opening.
				var lintel_h := h - DOOR_HEIGHT
				if lintel_h > 0.05:
					_solid(statics, kit, Vector3(mid.x, base + DOOR_HEIGHT + lintel_h * 0.5, mid.z), Vector3(size.x, lintel_h, size.z), style["trim"])
			else:
				_solid(statics, kit, Vector3(mid.x, base + h * 0.5, mid.z), Vector3(size.x, h, size.z), style["wall"])
				if kit != null:
					# Trim band and warm windows on the outside.
					kit.add_box(Transform3D(Basis(), Vector3(mid.x, base + h - 0.3, mid.z) + normal * 0.05), Vector3(size.x + 0.02, 0.6, size.z + 0.02), style["trim"])
					var n_windows := int((e - a) / 4.0)
					for i in n_windows:
						var t := a + (e - a) * (i + 0.5) / n_windows
						var wp := start + along * t + normal * (WALL * 0.5 + 0.03)
						var wsize := Vector3(1.8, 1.2, 0.06) if along == Vector3.RIGHT else Vector3(0.06, 1.2, 1.8)
						kit.add_box(Transform3D(Basis(), Vector3(wp.x, base + minf(2.0, h * 0.45), wp.z)), wsize, Color(1.0, 0.8, 0.5), style["glow"])
	# Roof slab + floor.
	_solid(statics, kit, Vector3(cx, base + h + 0.2, cz), Vector3(w + 0.8, 0.4, d + 0.8), style["roof"])
	if kit != null and style.get("pitched", false):
		# Gable roof (visual): ridge along the longer side.
		var rh := minf(w, d) * 0.4
		var rbasis := Basis() if d >= w else Basis(Vector3.UP, PI * 0.5)
		var rsize := Vector3(w + 1.0, rh, d + 1.0) if d >= w else Vector3(d + 1.0, rh, w + 1.0)
		kit.add_prism(Transform3D(rbasis, Vector3(cx, base + h + 0.4 + rh * 0.5, cz)), rsize, style["roof"])
	if kit != null:
		kit.add_box(Transform3D(Basis(), Vector3(cx, base + 0.03, cz)), Vector3(w - 0.2, 0.06, d - 0.2), style["floor"])
		var district: String = b.get("district", "roads")
		var count := maxi(1, int(w * d / 150.0))
		for i in count:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.86, 0.7)
			l.light_energy = 1.4
			l.omni_range = maxf(w, d) * 0.7
			var t := (i + 0.5) / count
			l.position = Vector3(cx - w * 0.5 + w * t, base + h - 0.8, cz)
			l.shadow_enabled = false
			l.distance_fade_enabled = true
			l.distance_fade_begin = 50.0
			l.distance_fade_length = 15.0
			root.add_child(l)
			if not lights.has(district):
				lights[district] = []
			lights[district].append(l)
			kit.add_box(Transform3D(Basis(), l.position + Vector3(0, 0.5, 0)), Vector3(1.4, 0.1, 0.5), Color(1, 0.95, 0.85), MeshKit.SLOT_GLOW)


## Door leaves for every doorway: open (no collision, hidden) until a Security
## Door Lock sabotage closes them. Returns [{body, visual}].
static func _doors(map: MapData, b: Dictionary, root: Node3D, visuals: bool) -> Array:
	var out: Array = []
	var cx := float(b["x"])
	var cz := float(b["z"])
	var w := float(b["w"])
	var d := float(b["d"])
	var base := map.height(cx, cz)
	for door: Dictionary in b.get("doors", []):
		var width := float(door["width"])
		var off := float(door.get("offset", 0.0))
		var pos := Vector3.ZERO
		var size := Vector3.ZERO
		match door["side"]:
			"n":
				pos = Vector3(cx + off, 0, cz - d * 0.5)
				size = Vector3(width, DOOR_HEIGHT, WALL * 0.6)
			"s":
				pos = Vector3(cx + off, 0, cz + d * 0.5)
				size = Vector3(width, DOOR_HEIGHT, WALL * 0.6)
			"w":
				pos = Vector3(cx - w * 0.5, 0, cz + off)
				size = Vector3(WALL * 0.6, DOOR_HEIGHT, width)
			"e":
				pos = Vector3(cx + w * 0.5, 0, cz + off)
				size = Vector3(WALL * 0.6, DOOR_HEIGHT, width)
		pos.y = base + DOOR_HEIGHT * 0.5
		var body := StaticBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		body.position = pos
		root.add_child(body)
		var visual: MeshInstance3D = null
		if visuals:
			visual = MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = size
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.12, 0.1, 0.75)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.15, 0.1)
			mat.emission_energy_multiplier = 0.6
			mesh.material = mat
			visual.mesh = mesh
			visual.position = pos
			visual.visible = false
			root.add_child(visual)
		out.append({"body": body, "visual": visual})
	return out


## Locks or unlocks the doors of one building.
static func set_doors_locked(world_root: Node3D, building: String, locked: bool) -> void:
	var doors: Dictionary = world_root.get_meta("doors", {})
	for door: Dictionary in doors.get(building, []):
		(door["body"] as StaticBody3D).collision_layer = (WORLD_LAYER | STRUCTURE_LAYER) if locked else 0
		if door["visual"] != null:
			(door["visual"] as MeshInstance3D).visible = locked


static func _prop(map: MapData, p: Dictionary, statics: StaticBody3D, kit: MeshKit, root: Node3D) -> void:
	var x := float(p["x"])
	var z := float(p["z"])
	var size := Vector3(float(p["w"]), float(p["h"]), float(p["d"]))
	var base := map.height(x, z)
	var center := Vector3(x, base + size.y * 0.5, z)
	var color := Color(p.get("color", "#8a8f96"))
	match p["kind"]:
		"meeting_table":
			_add_box_collider(statics, Transform3D(Basis(), center), size * Vector3(0.8, 1, 0.8))
			if kit != null:
				kit.add_cylinder(Transform3D(Basis(), center + Vector3(0, 0.35, 0)), size.x * 0.5, size.x * 0.5, 0.25, Color(0.14, 0.2, 0.34), 24, MeshKit.SLOT_GLOSS)
				kit.add_cylinder(Transform3D(Basis(), center + Vector3(0, 0.49, 0)), size.x * 0.3, size.x * 0.3, 0.04, Color(0.2, 0.9, 1.0), 24, MeshKit.SLOT_GLOW_CYAN)
				kit.add_cylinder(Transform3D(Basis(), center - Vector3(0, 0.1, 0)), 0.6, 0.9, size.y - 0.2, Color(0.3, 0.33, 0.4), 12)
		"monitor_wall":
			_solid(statics, kit, center, size, Color(0.12, 0.14, 0.18))
			if kit != null:
				for i in 4:
					kit.add_box(Transform3D(Basis(), center + Vector3(-size.x * 0.375 + size.x * 0.25 * i, 0.3, 0.32)), Vector3(size.x * 0.22, 1.2, 0.04), Color(0.2, 0.7, 0.9), MeshKit.SLOT_GLOW_CYAN)
		"server_rack":
			_solid(statics, kit, center, size, Color(0.15, 0.17, 0.22), MeshKit.SLOT_METAL)
			if kit != null:
				for i in 6:
					kit.add_box(Transform3D(Basis(), center + Vector3(-size.x * 0.52, -0.9 + i * 0.35, 0)), Vector3(0.04, 0.05, size.z * 0.8), Color(0.3, 1.0, 0.5), MeshKit.SLOT_GLOW_CYAN)
		"container":
			_solid(statics, kit, center, size, color, MeshKit.SLOT_METAL)
			if kit != null:
				var long_x := size.x > size.z
				for i in 8:
					var t := -0.45 + i * 0.13
					var off := Vector3(size.x * t, 0, size.z * 0.5 + 0.03) if long_x else Vector3(size.x * 0.5 + 0.03, 0, size.z * t)
					kit.add_box(Transform3D(Basis(), center + off), Vector3(0.12, size.y * 0.9, 0.06) if long_x else Vector3(0.06, size.y * 0.9, 0.12), color.darkened(0.25))
		"fuel_tank":
			_add_box_collider(statics, Transform3D(Basis(), center), size * Vector3(0.85, 1, 0.85))
			if kit != null:
				kit.add_cylinder(Transform3D(Basis(), center), size.x * 0.5, size.x * 0.5, size.y, Color(0.9, 0.9, 0.88), 20, MeshKit.SLOT_GLOSS)
				kit.add_cylinder(Transform3D(Basis(), center + Vector3(0, size.y * 0.2, 0)), size.x * 0.51, size.x * 0.51, 0.5, Color(0.8, 0.3, 0.15), 20)
		"crane":
			_add_box_collider(statics, Transform3D(Basis(), center), Vector3(size.x, size.y, size.z))
			if kit != null:
				for c in 4:
					var off := Vector3((c % 2 - 0.5) * size.x, 0, (c / 2 - 0.5) * size.z)
					kit.add_box(Transform3D(Basis(), center + off), Vector3(0.4, size.y, 0.4), Color(1.0, 0.72, 0.1))
				kit.add_box(Transform3D(Basis(), center + Vector3(6, size.y * 0.5, 0)), Vector3(22, 1.2, 1.2), Color(1.0, 0.72, 0.1))
				kit.add_box(Transform3D(Basis(), center + Vector3(0, size.y * 0.5 + 1.5, 0)), Vector3(4, 2.4, 3), Color(0.9, 0.9, 0.88))
				kit.add_beam(center + Vector3(14, size.y * 0.5, 0), center + Vector3(14, -size.y * 0.1, 0), 0.08, Color(0.2, 0.2, 0.2))
		"wreck":
			_add_box_collider(statics, Transform3D(Basis(Vector3.UP, 0.4), center), size)
			if kit != null:
				var xf := Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.FORWARD, 0.25), center)
				kit.add_capsule(xf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), 1.0, size.x, Color(0.85, 0.85, 0.82), MeshKit.SLOT_GLOSS)
				kit.add_box(xf * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0.5, 0.2, 2.5)), Vector3(1.6, 0.15, 3.5), Color(0.7, 0.3, 0.2))
				kit.add_box(xf * Transform3D(Basis(), Vector3(-size.x * 0.4, 1.0, 0)), Vector3(0.15, 1.6, 1.2), Color(0.2, 0.5, 0.9))
		"radar":
			_add_box_collider(statics, Transform3D(Basis(), center), Vector3(size.x, size.y, size.z))
			if kit != null:
				kit.add_box(Transform3D(Basis(), Vector3(x, base + 0.5, z)), Vector3(size.x, 1.0, size.z), Color(0.35, 0.37, 0.4))
				kit.add_cylinder(Transform3D(Basis(), center + Vector3(0, 0.5, 0)), 0.2, 0.25, size.y - 1.0, Color(0.6, 0.62, 0.65), 8, MeshKit.SLOT_METAL)
				kit.add_sphere(Transform3D(Basis.looking_at(Vector3(0.4, 0.5, 1)).scaled(Vector3(1, 1, 0.3)), center + Vector3(0, size.y * 0.5, 0)), 1.6, Color(0.95, 0.95, 0.95), 16, MeshKit.SLOT_GLOSS)
		"crate_stack":
			_solid(statics, kit, center, size, Color(0.6, 0.44, 0.26))
			if kit != null:
				kit.add_box(Transform3D(Basis(Vector3.UP, 0.3), center + Vector3(0.2, size.y * 0.5 + 0.4, 0.1)), Vector3(1.0, 0.8, 1.0), Color(0.55, 0.4, 0.24))
		"helipad":
			if kit != null:
				kit.add_cylinder(Transform3D(Basis(), Vector3(x, base + 0.08, z)), size.x * 0.5, size.x * 0.5, 0.16, Color(0.25, 0.27, 0.3), 32)
				kit.add_box(Transform3D(Basis(), Vector3(x - 1.2, base + 0.18, z)), Vector3(0.6, 0.02, 4.0), Color.WHITE)
				kit.add_box(Transform3D(Basis(), Vector3(x + 1.2, base + 0.18, z)), Vector3(0.6, 0.02, 4.0), Color.WHITE)
				kit.add_box(Transform3D(Basis(), Vector3(x, base + 0.18, z)), Vector3(2.4, 0.02, 0.6), Color.WHITE)
		_:
			_solid(statics, kit, center, size, color)


static func _station(map: MapData, s: Dictionary, statics: StaticBody3D, visuals: bool) -> Node3D:
	var node := Node3D.new()
	node.name = s["id"]
	var pos := map.station_pos(s["id"])
	node.position = pos
	var kit := MeshKit.new()
	var solid := Vector3.ZERO
	match s["kind"]:
		"console", "security_desk":
			solid = Vector3(1.4, 1.1, 0.7)
			kit.add_box(Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(1.4, 1.0, 0.7), Color(0.2, 0.24, 0.3), MeshKit.SLOT_METAL)
			kit.add_box(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 1.25, -0.1)), Vector3(1.1, 0.6, 0.06), Color(0.2, 0.9, 1.0), MeshKit.SLOT_GLOW_CYAN)
		"button":
			solid = Vector3(0.8, 1.0, 0.8)
			kit.add_cylinder(Transform3D(Basis(), Vector3(0, 0.45, 0)), 0.35, 0.45, 0.9, Color(0.25, 0.27, 0.32), 16, MeshKit.SLOT_METAL)
			kit.add_sphere(Transform3D(Basis().scaled(Vector3(1, 0.5, 1)), Vector3(0, 0.95, 0)), 0.3, Color(1, 0.15, 0.1), 16, MeshKit.SLOT_GLOW_RED)
		"generator":
			solid = Vector3(1.8, 1.8, 1.8)
			kit.add_box(Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(2.0, 0.6, 2.0), Color(0.3, 0.32, 0.35), MeshKit.SLOT_METAL)
			kit.add_cylinder(Transform3D(Basis(), Vector3(0, 1.2, 0)), 0.8, 0.8, 1.3, Color(0.95, 0.5, 0.12), 16, MeshKit.SLOT_GLOSS)
			kit.add_cylinder(Transform3D(Basis(), Vector3(0, 1.2, 0)), 0.82, 0.82, 0.2, Color(0.15, 0.15, 0.15), 16)
		"breaker":
			kit.add_box(Transform3D(Basis(), Vector3(0, 1.3, 0)), Vector3(0.7, 0.9, 0.25), Color(0.5, 0.52, 0.55), MeshKit.SLOT_METAL)
			kit.add_box(Transform3D(Basis(), Vector3(0, 1.3, 0.14)), Vector3(0.12, 0.4, 0.1), Color(1.0, 0.75, 0.1))
		"medpod":
			solid = Vector3(1.2, 2.0, 1.2)
			kit.add_cylinder(Transform3D(Basis(), Vector3(0, 0.15, 0)), 0.7, 0.8, 0.3, Color(0.9, 0.95, 0.95), 16)
			kit.add_capsule(Transform3D(Basis(), Vector3(0, 1.1, 0)), 0.55, 1.9, Color(0.4, 0.95, 0.9), MeshKit.SLOT_GLOSS)
		"crate":
			solid = Vector3(1.6, 1.2, 1.6)
			kit.add_box(Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.6, 1.2, 1.6), Color(0.62, 0.46, 0.28))
			kit.add_box(Transform3D(Basis(), Vector3(0, 1.22, 0)), Vector3(1.0, 0.04, 1.0), Color(0.9, 0.2, 0.2))
		"relay":
			kit.add_cylinder(Transform3D(Basis(), Vector3(0, 1.0, 0)), 0.08, 0.1, 2.0, Color(0.4, 0.4, 0.42), 6)
			kit.add_box(Transform3D(Basis(), Vector3(0, 1.4, 0.15)), Vector3(0.7, 0.8, 0.3), Color(0.85, 0.85, 0.8))
			kit.add_sphere(Transform3D(Basis(), Vector3(0, 2.1, 0)), 0.08, Color(0.2, 1, 0.4), 6, MeshKit.SLOT_GLOW_CYAN)
		"beacon":
			kit.add_cylinder(Transform3D(Basis(), Vector3(0, 1.5, 0)), 0.1, 0.14, 3.0, Color(0.9, 0.9, 0.9), 8)
			kit.add_sphere(Transform3D(Basis(), Vector3(0, 3.1, 0)), 0.25, Color(1, 0.5, 0.1), 10, MeshKit.SLOT_GLOW)
		"door_panel":
			kit.add_box(Transform3D(Basis(), Vector3(0, 1.3, 0)), Vector3(0.6, 0.8, 0.2), Color(0.25, 0.28, 0.34), MeshKit.SLOT_METAL)
			kit.add_box(Transform3D(Basis(), Vector3(0, 1.35, 0.11)), Vector3(0.4, 0.4, 0.02), Color(1.0, 0.7, 0.2), MeshKit.SLOT_GLOW)
		"wreck_site":
			kit.add_box(Transform3D(Basis(Vector3.UP, 0.7), Vector3(0, 0.3, 0)), Vector3(1.2, 0.6, 0.8), Color(0.3, 0.3, 0.32), MeshKit.SLOT_METAL)
	if solid != Vector3.ZERO:
		_add_box_collider(statics, Transform3D(Basis(), pos + Vector3(0, solid.y * 0.5, 0)), solid)
	if visuals and not kit.is_empty():
		node.add_child(kit.to_instance())
	return node


static func _roads(map: MapData, root: Node3D, lights: Dictionary) -> void:
	var kit := MeshKit.new()
	var lamp_every := 28.0
	for road: Array in map.raw.get("roads", []):
		var since_lamp := lamp_every * 0.5
		for i in road.size() - 1:
			var a := Vector2(road[i][0], road[i][1])
			var b := Vector2(road[i + 1][0], road[i + 1][1])
			var length := a.distance_to(b)
			var steps := int(ceil(length / 2.0))
			for sidx in steps:
				var p0 := a.lerp(b, float(sidx) / steps)
				var p1 := a.lerp(b, float(sidx + 1) / steps)
				var y0 := map.height(p0.x, p0.y) + 0.06
				var y1 := map.height(p1.x, p1.y) + 0.06
				var dir := (p1 - p0).normalized()
				var side := Vector3(-dir.y, 0, dir.x) * 3.0
				var v0 := Vector3(p0.x, y0, p0.y)
				var v1 := Vector3(p1.x, y1, p1.y)
				var road_col := Color(0.34, 0.33, 0.35)
				kit.add_colored_triangles(PackedVector3Array([v0 - side, v1 - side, v1 + side, v0 - side, v1 + side, v0 + side]),
					PackedColorArray([road_col, road_col, road_col, road_col, road_col, road_col]))
				since_lamp += p0.distance_to(p1)
				if since_lamp >= lamp_every:
					since_lamp = 0.0
					var lamp := StructureBuilder.lamp_post(4.2)
					lamp.position = Vector3(p1.x, y1, p1.y) + side * 1.25
					root.add_child(lamp)
					var district := map.district_at(lamp.position)
					for child in lamp.get_children():
						if child is Light3D:
							child.set_meta("street", true)
							if not lights.has(district):
								lights[district] = []
							lights[district].append(child)
	root.add_child(kit.to_instance())


## Deterministic vegetation placement: kind name -> Array of Transform3D.
## Shared by the client (visuals) and the server (tree trunk collision).
## Coastal band: palms, bushes and ferns (the Sunset Cove look); inland:
## broadleaf jungle trees, conifers on high ground, grass and rocks.
static var _layout_cache: Dictionary = {}


static func vegetation_layout(map: MapData) -> Dictionary:
	var cache_key: String = str(map.raw.get("id", "")) + str(map.raw.get("vegetation", {}).hash())
	if _layout_cache.has(cache_key):
		return _layout_cache[cache_key]
	var out := {}
	for k: String in ["palm0", "palm1", "palm2", "bush", "fern", "broad0", "broad1", "pine0", "pine1", "grass", "rock0", "rock1", "rock2"]:
		out[k] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var blockers := _blockers(map)
	var veg: Dictionary = map.raw.get("vegetation", {})
	var area: Array = veg.get("area", [-200.0, -150.0, 200.0, 140.0])
	var max_palms := int(veg.get("palms", 260))
	var palm_count := 0
	for i in int(veg.get("samples", 7000)):
		var x := rng.randf_range(float(area[0]), float(area[2]))
		var z := rng.randf_range(float(area[1]), float(area[3]))
		var h := map.height(x, z)
		if h < 0.6 or _blocked(blockers, x, z):
			continue
		var r := rng.randf()
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.5)), Vector3(x, h - 0.1, z))
		var inland := map.coast_distance(x, z) - map.beach_width
		var coastal := inland < 70.0
		# Palms crowd the coast and thin out inland.
		if r < (0.07 if coastal else 0.02) and palm_count < max_palms:
			var pxf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2)), Vector3(x, h - 0.2, z))
			out["palm%d" % (palm_count % 3)].append(pxf)
			palm_count += 1
		elif inland > 2.0 and r < 0.45:
			out["bush"].append(xf)
		elif inland > 2.0 and r < 0.65:
			out["fern"].append(xf)
	for i in int(veg.get("trees", 0)):
		var x := rng.randf_range(float(area[0]), float(area[2]))
		var z := rng.randf_range(float(area[1]), float(area[3]))
		var inland := map.coast_distance(x, z) - map.beach_width
		if inland < 45.0 or _blocked(blockers, x, z):
			continue
		var h := map.height(x, z)
		if map.normal(x, z).y < 0.8:
			continue
		var kind := ("pine%d" if h > 16.0 else "broad%d") % rng.randi_range(0, 1)
		out[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(x, h - 0.15, z)))
	for i in int(veg.get("grass", 0)):
		var x := rng.randf_range(float(area[0]), float(area[2]))
		var z := rng.randf_range(float(area[1]), float(area[3]))
		if map.coast_distance(x, z) - map.beach_width < 4.0 or _blocked(blockers, x, z):
			continue
		out["grass"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6)), Vector3(x, map.height(x, z) - 0.05, z)))
	for i in int(veg.get("rocks", 0)):
		var x := rng.randf_range(float(area[0]), float(area[2]))
		var z := rng.randf_range(float(area[1]), float(area[3]))
		if map.height(x, z) < 0.3 or _blocked(blockers, x, z):
			continue
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled(Vector3.ONE * rng.randf_range(0.6, 1.6))
		out["rock%d" % rng.randi_range(0, 2)].append(Transform3D(basis, Vector3(x, map.height(x, z) - 0.2, z)))
	_layout_cache[cache_key] = out
	return out


const TREE_KINDS := {"palm0": 0.26, "palm1": 0.26, "palm2": 0.26, "broad0": 0.3, "broad1": 0.3, "pine0": 0.3, "pine1": 0.3}


## Trunk colliders (server and client), one StaticBody per 128 m cell.
static func _tree_collision(map: MapData, root: Node3D) -> void:
	var layout := vegetation_layout(map)
	var bodies := {}
	for kind: String in TREE_KINDS:
		for xf: Transform3D in layout[kind]:
			# Small bodies: a body's shapes are tested together once its AABB is hit.
			var key := Vector2i(floori(xf.origin.x / 24.0), floori(xf.origin.z / 24.0))
			if not bodies.has(key):
				var body := StaticBody3D.new()
				body.name = "Trees_%d_%d" % [key.x, key.y]
				body.collision_layer = WORLD_LAYER | STRUCTURE_LAYER
				body.collision_mask = 0
				root.add_child(body)
				bodies[key] = body
			var s := xf.basis.get_scale().x
			var shape := CylinderShape3D.new()
			shape.radius = float(TREE_KINDS[kind]) * s
			shape.height = 4.0 * s
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = xf.origin + Vector3(0, shape.height * 0.5, 0)
			(bodies[key] as StaticBody3D).add_child(cs)


static func _vegetation(map: MapData, root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var meshes := {}
	for i in 3:
		var palm := VegetationBuilder.palm(rng, 8.0 + i * 1.5)
		var parts: Array = []
		for child in palm.get_children():
			if child is MeshInstance3D:
				parts.append((child as MeshInstance3D).mesh)
		meshes["palm%d" % i] = parts
		palm.free()
	meshes["bush"] = [VegetationBuilder.bush(rng, 1.8)]
	meshes["fern"] = [VegetationBuilder.fern(rng, 1.2)]
	for i in 2:
		meshes["broad%d" % i] = [VegetationBuilder.broadleaf(rng, 6.5 + i * 2.0)]
		meshes["pine%d" % i] = [VegetationBuilder.pine(rng, 9.0 + i * 3.0)]
	meshes["grass"] = [VegetationBuilder.grass_tuft(rng)]
	for i in 3:
		meshes["rock%d" % i] = [RockBuilder.rock(rng, Vector3(1.0, 0.6, 0.8) * (0.8 + i * 0.5), 0.5)]
	var layout := vegetation_layout(map)
	# One MultiMesh per mesh per 128 m cell: off-screen cells are culled and
	# visibility ranges work per cell (a single island-wide MultiMesh has one AABB).
	for kind: String in layout:
		var cells := {}
		for xf: Transform3D in layout[kind]:
			var key := Vector2i(floori(xf.origin.x / VEG_CELL), floori(xf.origin.z / VEG_CELL))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(xf)
		var tree := TREE_KINDS.has(kind)
		for mesh: Mesh in meshes[kind]:
			for key: Vector2i in cells:
				var list: Array = cells[key]
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mesh
				mm.instance_count = list.size()
				for i in list.size():
					mm.set_instance_transform(i, list[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				# Trees stay visible far (landmarks); ground cover fades early.
				mmi.visibility_range_end = 420.0 if tree else (60.0 if kind == "grass" else 140.0)
				mmi.visibility_range_end_margin = 20.0
				if not tree and not kind.begins_with("rock"):
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mmi)


const VEG_CELL := 128.0


## Circles (x, z, r) where vegetation must not grow: buildings, props, stations, roads.
static func _blockers(map: MapData) -> Array:
	var out: Array = []
	for b: Dictionary in map.raw.get("buildings", []):
		out.append([float(b["x"]), float(b["z"]), maxf(float(b["w"]), float(b["d"])) * 0.75 + 3.0])
	for p: Dictionary in map.raw.get("props", []):
		out.append([float(p["x"]), float(p["z"]), maxf(float(p["w"]), float(p["d"])) * 0.7 + 2.0])
	for s: Dictionary in map.raw.get("stations", []):
		out.append([float(s["x"]), float(s["z"]), 4.0])
	for s: Dictionary in map.raw.get("spawns", []):
		out.append([float(s["x"]), float(s["z"]), 3.0])
	for road: Array in map.raw.get("roads", []):
		for i in road.size() - 1:
			var a := Vector2(road[i][0], road[i][1])
			var b := Vector2(road[i + 1][0], road[i + 1][1])
			var n := int(a.distance_to(b) / 4.0) + 1
			for k in n + 1:
				var p := a.lerp(b, float(k) / n)
				out.append([p.x, p.y, 5.0])
	for name: String in map.waypoints:
		var p: Vector3 = map.waypoints[name]
		out.append([p.x, p.z, 2.0 if name.begins_with("g_") else 2.5])
	# Spatial hash (BLOCK_CELL buckets) so big maps stay fast to populate.
	var hash := {}
	for c: Array in out:
		var r: float = c[2]
		for bz in range(floori((c[1] - r) / BLOCK_CELL), floori((c[1] + r) / BLOCK_CELL) + 1):
			for bx in range(floori((c[0] - r) / BLOCK_CELL), floori((c[0] + r) / BLOCK_CELL) + 1):
				var key := Vector2i(bx, bz)
				if not hash.has(key):
					hash[key] = []
				hash[key].append(c)
	return [hash]


const BLOCK_CELL := 16.0


static func _blocked(blockers: Array, x: float, z: float) -> bool:
	var bucket: Array = blockers[0].get(Vector2i(floori(x / BLOCK_CELL), floori(z / BLOCK_CELL)), [])
	for c: Array in bucket:
		var dx: float = x - c[0]
		var dz: float = z - c[1]
		if dx * dx + dz * dz < c[2] * c[2]:
			return true
	return false
