class_name StructureBuilder
extends RefCounted
## Chunky stylized buildings: hangar, command building, radio tower, pier, lamps.

const WALL := Color(0.86, 0.8, 0.68)
const WALL_DARK := Color(0.62, 0.56, 0.48)
const ROOF := Color(0.58, 0.55, 0.52)
const TRIM := Color(0.32, 0.3, 0.3)
const DOOR := Color(0.3, 0.33, 0.36)
const WINDOW := Color(1.0, 0.78, 0.45)
const RED := Color(0.86, 0.18, 0.14)
const WHITE := Color(0.95, 0.94, 0.9)
const WOOD := Color(0.55, 0.38, 0.24)
const WOOD_DARK := Color(0.38, 0.26, 0.17)
const NAVY := Color(0.14, 0.2, 0.34)
const CYAN := Color(0.2, 0.9, 1.0)


## Curved-roof hangar; origin at floor centre, door facing +Z.
static func hangar(width: float = 22.0, length: float = 30.0, wall_h: float = 4.0) -> Node3D:
	var kit := MeshKit.new()
	var half_w := width * 0.5
	var radius := half_w
	kit.add_box(Transform3D(Basis(), Vector3(0, wall_h * 0.5, 0)), Vector3(width, wall_h, length), WALL)
	kit.add_arch(Transform3D(Basis(), Vector3(0, wall_h, 0)), radius, length + 0.6, 0.35, ROOF, 18, MeshKit.SLOT_METAL)
	# Roof ribs.
	for i in 7:
		var z := -length * 0.5 + length * i / 6.0
		kit.add_arch(Transform3D(Basis(), Vector3(0, wall_h + 0.05, z)), radius + 0.1, 0.35, 0.4, TRIM, 18)
	# Gable ends: stacked boxes approximating the arch.
	for side: float in [-1.0, 1.0]:
		var z := side * length * 0.5
		for j in 8:
			var y0 := radius * j / 8.0
			var w := 2.0 * sqrt(maxf(radius * radius - y0 * y0, 0.0))
			kit.add_box(Transform3D(Basis(), Vector3(0, wall_h + y0 + radius / 16.0, z)), Vector3(w, radius / 8.0 + 0.02, 0.4), WALL_DARK)
	# Big door with stripes, windows along the sides.
	kit.add_box(Transform3D(Basis(), Vector3(0, wall_h * 0.9, length * 0.5 + 0.25)), Vector3(width * 0.62, wall_h * 1.8, 0.2), DOOR, MeshKit.SLOT_METAL)
	for i in 5:
		kit.add_box(Transform3D(Basis(), Vector3(-width * 0.31 + width * 0.155 * i, 0.4, length * 0.5 + 0.37)), Vector3(width * 0.07, 0.8, 0.05), Color(1.0, 0.78, 0.1))
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var z := -length * 0.4 + length * 0.8 * i / 5.0
			kit.add_box(Transform3D(Basis(), Vector3(side * (half_w + 0.05), wall_h * 0.62, z)), Vector3(0.12, 1.1, 1.8), WINDOW, MeshKit.SLOT_GLOW)
	var root := Node3D.new()
	root.add_child(kit.to_instance())
	root.add_child(_warm_light(Vector3(0, wall_h + 1.0, length * 0.5 + 2.0), 14.0, 1.5))
	return root


## Two-storey command/base building with lit windows and rooftop details.
static func command_building(width: float = 14.0, depth: float = 10.0, floors: int = 2, accent: Color = NAVY) -> Node3D:
	var kit := MeshKit.new()
	var floor_h := 3.4
	var height := floor_h * floors
	kit.add_box(Transform3D(Basis(), Vector3(0, height * 0.5, 0)), Vector3(width, height, depth), WALL)
	kit.add_box(Transform3D(Basis(), Vector3(0, height + 0.25, 0)), Vector3(width + 0.6, 0.5, depth + 0.6), accent)
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(width + 0.3, 0.6, depth + 0.3), WALL_DARK)
	for f in floors:
		var y := floor_h * f + floor_h * 0.55
		kit.add_box(Transform3D(Basis(), Vector3(0, floor_h * (f + 1), 0)), Vector3(width + 0.2, 0.18, depth + 0.2), accent)
		for i in int(width / 2.6):
			var x := -width * 0.5 + 1.6 + i * 2.6
			if x > width * 0.5 - 1.0:
				break
			for side: float in [-1.0, 1.0]:
				kit.add_box(Transform3D(Basis(), Vector3(x, y, side * (depth * 0.5 + 0.03))), Vector3(1.4, 1.3, 0.08), WINDOW, MeshKit.SLOT_GLOW)
		for i in int(depth / 2.6):
			var z := -depth * 0.5 + 1.6 + i * 2.6
			if z > depth * 0.5 - 1.0:
				break
			for side: float in [-1.0, 1.0]:
				kit.add_box(Transform3D(Basis(), Vector3(side * (width * 0.5 + 0.03), y, z)), Vector3(0.08, 1.3, 1.4), WINDOW, MeshKit.SLOT_GLOW)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.3, depth * 0.5 + 0.05)), Vector3(2.0, 2.6, 0.12), DOOR, MeshKit.SLOT_METAL)
	kit.add_box(Transform3D(Basis(), Vector3(-width * 0.25, height + 1.0, -depth * 0.2)), Vector3(2.2, 1.2, 1.6), ROOF, MeshKit.SLOT_METAL)
	kit.add_cylinder(Transform3D(Basis(), Vector3(width * 0.3, height + 2.5, 0)), 0.05, 0.08, 4.0, TRIM, 6)
	var root := Node3D.new()
	root.add_child(kit.to_instance())
	root.add_child(_warm_light(Vector3(0, 3.2, depth * 0.5 + 1.5), 10.0, 1.2))
	return root


## Red-and-white lattice radio tower with dishes and a blinking beacon.
static func radio_tower(height: float = 42.0) -> Node3D:
	var kit := MeshKit.new()
	var base_half := 3.2
	var top_half := 0.8
	var sections := 10
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for s in sections:
		var t0 := float(s) / sections
		var t1 := float(s + 1) / sections
		var h0 := lerpf(base_half, top_half, t0)
		var h1 := lerpf(base_half, top_half, t1)
		var y0 := height * t0
		var y1 := height * t1
		var color := RED if s % 2 == 0 else WHITE
		for c in 4:
			var a: Vector2 = corners[c]
			var b: Vector2 = corners[(c + 1) % 4]
			var p0 := Vector3(a.x * h0, y0, a.y * h0)
			var p1 := Vector3(a.x * h1, y1, a.y * h1)
			kit.add_beam(p0, p1, 0.32, color)
			var q0 := Vector3(b.x * h0, y0, b.y * h0)
			var q1 := Vector3(b.x * h1, y1, b.y * h1)
			kit.add_beam(p0, q1, 0.14, color)
			kit.add_beam(q0, p1, 0.14, color)
			kit.add_beam(p1, q1, 0.18, color)
	var top := Vector3(0, height, 0)
	kit.add_box(Transform3D(Basis(), top + Vector3(0, 0.2, 0)), Vector3(3.4, 0.3, 3.4), TRIM, MeshKit.SLOT_METAL)
	kit.add_cylinder(Transform3D(Basis(), top + Vector3(0, 3.5, 0)), 0.06, 0.15, 7.0, RED, 6)
	kit.add_sphere(Transform3D(Basis(), top + Vector3(0, 7.2, 0)), 0.35, RED, 8, MeshKit.SLOT_GLOW_RED)
	# Dishes: flattened spheres on arms, facing outward.
	for d in 3:
		var y := height * (0.62 + 0.14 * d)
		var ang := TAU * d / 3.0 + 0.4
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var half := lerpf(base_half, top_half, y / height)
		var pos := out * (half + 1.6) + Vector3(0, y, 0)
		kit.add_beam(Vector3(0, y, 0), pos, 0.18, TRIM)
		var basis := Basis.looking_at(-out, Vector3.UP).scaled(Vector3(1.0, 1.0, 0.35))
		kit.add_sphere(Transform3D(basis, pos), 1.5 - d * 0.25, WHITE, 16, MeshKit.SLOT_GLOSS)
	var root := Node3D.new()
	root.add_child(kit.to_instance())
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.15, 0.1)
	beacon.light_energy = 3.0
	beacon.omni_range = 8.0
	beacon.position = top + Vector3(0, 7.2, 0)
	root.add_child(beacon)
	return root


## Wooden pier along +Z from the origin, with posts and warm lanterns.
static func pier(length: float = 34.0, width: float = 3.4) -> Node3D:
	var kit := MeshKit.new()
	var planks := int(length / 0.6)
	for i in planks:
		var z := i * 0.6 + 0.3
		var shade := 0.9 + 0.1 * sin(i * 12.9898)
		kit.add_box(Transform3D(Basis(), Vector3(0, 1.2, z)), Vector3(width, 0.14, 0.54), WOOD * shade)
	var posts := int(length / 3.0) + 1
	for i in posts:
		var z := i * 3.0
		for side: float in [-1.0, 1.0]:
			kit.add_cylinder(Transform3D(Basis(), Vector3(side * width * 0.5, -0.8, z)), 0.18, 0.2, 4.6, WOOD_DARK, 8)
			kit.add_cylinder(Transform3D(Basis(), Vector3(side * width * 0.5, 1.9, z)), 0.1, 0.1, 1.3, WOOD_DARK, 6)
		if i > 0:
			for side: float in [-1.0, 1.0]:
				kit.add_beam(Vector3(side * width * 0.5, 2.3, z - 3.0), Vector3(side * width * 0.5, 2.3, z), 0.08, WOOD)
	var root := Node3D.new()
	var lanterns := int(length / 12.0)
	for i in lanterns + 1:
		var z := i * 12.0
		var pos := Vector3(width * 0.5, 2.9, z)
		kit.add_sphere(Transform3D(Basis(), pos), 0.2, WINDOW, 8, MeshKit.SLOT_GLOW)
		root.add_child(_warm_light(pos, 7.0, 1.4))
	root.add_child(kit.to_instance())
	return root


static func lamp_post(height: float = 4.5) -> Node3D:
	var kit := MeshKit.new()
	kit.add_cylinder(Transform3D(Basis(), Vector3(0, height * 0.5, 0)), 0.08, 0.12, height, TRIM, 8, MeshKit.SLOT_METAL)
	kit.add_sphere(Transform3D(Basis(), Vector3(0, height + 0.15, 0)), 0.28, WINDOW, 10, MeshKit.SLOT_GLOW)
	var root := Node3D.new()
	root.add_child(kit.to_instance())
	root.add_child(_warm_light(Vector3(0, height + 0.1, 0), 9.0, 1.6))
	return root


## Flat runway with markings; runs along local X.
static func airstrip(length: float, width: float) -> MeshInstance3D:
	var kit := MeshKit.new()
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(length, 0.1, width), Color(0.33, 0.33, 0.35))
	var dashes := int(length / 8.0)
	for i in dashes:
		kit.add_box(Transform3D(Basis(), Vector3(-length * 0.5 + 4.0 + i * 8.0, 0.11, 0)), Vector3(4.0, 0.02, 0.4), WHITE)
	for side: float in [-1.0, 1.0]:
		kit.add_box(Transform3D(Basis(), Vector3(0, 0.11, side * (width * 0.5 - 0.5))), Vector3(length, 0.02, 0.3), Color(1.0, 0.8, 0.15))
	return kit.to_instance()


static func _warm_light(pos: Vector3, light_range: float, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = energy
	l.omni_range = light_range
	l.position = pos
	l.distance_fade_enabled = true
	l.distance_fade_begin = 60.0
	l.distance_fade_length = 20.0
	return l
