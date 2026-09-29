class_name MapBuilder
extends RefCounted
## Builds a playable map from MapData. With `visuals = false` only collision is
## created (dedicated/listen server world). Collision layer 1 = world.

const WORLD_LAYER := 1
const DOOR_HEIGHT := 3.0
const WALL := 0.4

const STYLES := {
	"command": {"wall": Color(0.88, 0.9, 0.94), "trim": Color(0.12, 0.2, 0.36), "roof": Color(0.2, 0.26, 0.36), "floor": Color(0.55, 0.6, 0.66), "glow": MeshKit.SLOT_GLOW_CYAN},
	"medical": {"wall": Color(0.96, 0.97, 0.97), "trim": Color(0.1, 0.66, 0.62), "roof": Color(0.8, 0.84, 0.84), "floor": Color(0.82, 0.88, 0.88), "glow": MeshKit.SLOT_GLOW},
	"warehouse": {"wall": Color(0.22, 0.4, 0.6), "trim": Color(0.66, 0.34, 0.18), "roof": Color(0.5, 0.5, 0.52), "floor": Color(0.45, 0.45, 0.47), "glow": MeshKit.SLOT_GLOW},
	"industrial": {"wall": Color(0.62, 0.64, 0.66), "trim": Color(0.95, 0.5, 0.12), "roof": Color(0.4, 0.42, 0.44), "floor": Color(0.4, 0.4, 0.42), "glow": MeshKit.SLOT_GLOW},
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
	statics.collision_layer = WORLD_LAYER
	statics.collision_mask = 0
	root.add_child(statics)
	var col: Dictionary = map.raw["collision"]
	var center := Vector2(float(col["center"][0]), float(col["center"][1]))
	statics.add_child(TerrainMeshBuilder.build_collision(map.field, center, int(col["size"])))
	_boundary(map, statics)
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
		root.add_child(kit.to_instance())
		_terrain_visuals(map, root)
		_roads(map, root, district_lights)
		_vegetation(map, root)
	return root


static func _terrain_visuals(map: MapData, root: Node3D) -> void:
	var col: Dictionary = map.raw["collision"]
	var size := float(col["size"]) + 120.0
	var origin := Vector2(float(col["center"][0]), float(col["center"][1])) - Vector2(size, size) * 0.5
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = TerrainMeshBuilder.new().build_mesh(map.field, origin, Vector2(size, size), 240)
	root.add_child(mi)
	var to_sun := Vector3(0.72, 0.075, -0.69)
	if map.raw.has("sun_direction"):
		var s: Array = map.raw["sun_direction"]
		to_sun = Vector3(s[0], s[1], s[2])
	var sea := WaterFactory.sea(3000.0, to_sun, 128)
	sea.name = "Sea"
	root.add_child(sea)
	WaterFactory.bake_depth(sea, map.field, Rect2(origin, Vector2(size, size)), 1.0)


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
		(door["body"] as StaticBody3D).collision_layer = WORLD_LAYER if locked else 0
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
							if not lights.has(district):
								lights[district] = []
							lights[district].append(child)
	root.add_child(kit.to_instance())


static func _vegetation(map: MapData, root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var palms: Array[Node3D] = []
	for i in 3:
		palms.append(VegetationBuilder.palm(rng, 8.0 + i * 1.5))
	var bush_mm := MultiMesh.new()
	bush_mm.transform_format = MultiMesh.TRANSFORM_3D
	bush_mm.mesh = VegetationBuilder.bush(rng, 1.8)
	var fern_mm := MultiMesh.new()
	fern_mm.transform_format = MultiMesh.TRANSFORM_3D
	fern_mm.mesh = VegetationBuilder.fern(rng, 1.2)
	var bushes: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var blockers := _blockers(map)
	var palm_count := 0
	for i in 7000:
		var x := rng.randf_range(-200.0, 200.0)
		var z := rng.randf_range(-150.0, 140.0)
		var h := map.height(x, z)
		if h < 0.6 or _blocked(blockers, x, z):
			continue
		var r := rng.randf()
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.5)), Vector3(x, h - 0.1, z))
		var inland := map.field.coast_distance(x, z) - map.field.beach_width
		if r < 0.05 and palm_count < 260:
			var p := palms[palm_count % palms.size()].duplicate()
			p.position = Vector3(x, h - 0.2, z)
			p.rotation.y = rng.randf() * TAU
			p.scale = Vector3.ONE * rng.randf_range(0.85, 1.2)
			root.add_child(p)
			palm_count += 1
		elif inland > 2.0 and r < 0.45:
			bushes.append(xf)
		elif inland > 2.0 and r < 0.65:
			ferns.append(xf)
	for v in palms:
		v.free()
	for pair: Array in [[bush_mm, bushes], [fern_mm, ferns]]:
		var mm: MultiMesh = pair[0]
		var xfs: Array[Transform3D] = pair[1]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 160.0
		root.add_child(mmi)


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
		out.append([p.x, p.z, 2.5])
	return out


static func _blocked(blockers: Array, x: float, z: float) -> bool:
	for c: Array in blockers:
		var dx: float = x - c[0]
		var dz: float = z - c[1]
		if dx * dx + dz * dz < c[2] * c[2]:
			return true
	return false
