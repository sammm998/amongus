class_name VegetationBuilder
extends RefCounted
## Procedural tropical plants: palms, broadleaf bushes, ferns.
## Leaves use the foliage wind shader (COLOR.a = sway weight).

const FOLIAGE_SHADER := preload("res://world/shaders/foliage_wind.gdshader")
const TRUNK := Color(0.4, 0.29, 0.19)
const TRUNK_RING := Color(0.3, 0.21, 0.14)

class LeafBuffer:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()


static var _leaf_material: ShaderMaterial
static var _bush_material: ShaderMaterial


static func leaf_material() -> ShaderMaterial:
	if _leaf_material == null:
		_leaf_material = ShaderMaterial.new()
		_leaf_material.shader = FOLIAGE_SHADER
	return _leaf_material


static func bush_material() -> ShaderMaterial:
	if _bush_material == null:
		_bush_material = ShaderMaterial.new()
		_bush_material.shader = FOLIAGE_SHADER
		_bush_material.set_shader_parameter("base_color", Color(0.08, 0.3, 0.1))
		_bush_material.set_shader_parameter("tip_color", Color(0.3, 0.6, 0.18))
		_bush_material.set_shader_parameter("wind_strength", 0.08)
	return _bush_material


## A palm: curved ringed trunk + crown of drooping fronds + coconuts.
static func palm(rng: RandomNumberGenerator, height: float = 9.0) -> Node3D:
	var root := Node3D.new()
	var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * height * rng.randf_range(0.12, 0.3)
	var kit := MeshKit.new()
	var segments := 12
	var prev := Vector3.ZERO
	var top := Vector3.ZERO
	for i in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var p0 := _trunk_point(t0, height, lean)
		var p1 := _trunk_point(t1, height, lean)
		var r0 := lerpf(0.3, 0.17, t0)
		var r1 := lerpf(0.3, 0.17, t1)
		kit.add_tube(p0, p1, r0 * 1.12, r1, TRUNK if i % 2 == 0 else TRUNK_RING, 10)
		top = p1
		prev = p1
	for c in 3:
		var a := TAU * c / 3.0
		kit.add_sphere(Transform3D(Basis(), top + Vector3(cos(a) * 0.3, -0.35, sin(a) * 0.3)), 0.22, Color(0.36, 0.42, 0.12), 8)
	root.add_child(kit.to_instance())

	var leaves := _leaf_arrays()
	var fronds := rng.randi_range(8, 11)
	for f in fronds:
		var angle := TAU * f / fronds + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var length := height * rng.randf_range(0.42, 0.55)
		var droop := rng.randf_range(0.8, 1.3)
		_add_frond(leaves, top, dir, length, length * 0.14, droop, 0.55 + 0.3 * rng.randf())
	var mi := MeshInstance3D.new()
	mi.mesh = _commit_leaves(leaves, leaf_material())
	root.add_child(mi)
	return root


## Broadleaf bush: big glossy leaves fanning out from the ground.
static func bush(rng: RandomNumberGenerator, size: float = 1.6) -> ArrayMesh:
	var leaves := _leaf_arrays()
	var count := rng.randi_range(12, 18)
	for i in count:
		var angle := rng.randf() * TAU
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var up := rng.randf_range(0.5, 1.3)
		var length := size * rng.randf_range(0.7, 1.1)
		var base := Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0.0, 0.25), rng.randf_range(-0.12, 0.12)) * size
		_add_leaf(leaves, base, (dir + Vector3.UP * up).normalized(), length, length * 0.3, 0.55, rng.randf_range(0.75, 1.1))
	return _commit_leaves(leaves, bush_material())


## Round broadleaf tree: short trunk + lumpy clustered canopy (stylised, bright).
static func broadleaf(rng: RandomNumberGenerator, height: float = 7.0) -> ArrayMesh:
	var kit := MeshKit.new()
	var top := Vector3(rng.randf_range(-0.3, 0.3), height * 0.55, rng.randf_range(-0.3, 0.3))
	kit.add_tube(Vector3.ZERO, top, 0.32, 0.2, TRUNK, 8)
	var greens := [Color(0.22, 0.5, 0.14), Color(0.3, 0.58, 0.16), Color(0.18, 0.42, 0.12), Color(0.36, 0.62, 0.2)]
	var lobes := rng.randi_range(5, 7)
	for i in lobes:
		var a := TAU * i / lobes + rng.randf_range(-0.3, 0.3)
		var r := height * rng.randf_range(0.16, 0.26)
		var off := Vector3(cos(a), rng.randf_range(-0.2, 0.5), sin(a)) * height * 0.2
		var basis := Basis().scaled(Vector3(1.0, rng.randf_range(0.75, 0.95), 1.0))
		kit.add_sphere(Transform3D(basis, top + Vector3(0, height * 0.12, 0) + off), r, greens[rng.randi() % greens.size()], 8)
	kit.add_sphere(Transform3D(Basis(), top + Vector3(0, height * 0.3, 0)), height * 0.24, greens[1], 8)
	return kit.commit()


## Conifer: trunk + three stacked cones.
static func pine(rng: RandomNumberGenerator, height: float = 10.0) -> ArrayMesh:
	var kit := MeshKit.new()
	kit.add_tube(Vector3.ZERO, Vector3(0, height * 0.35, 0), 0.28, 0.2, TRUNK_RING, 8)
	var dark := Color(0.1, 0.3, 0.14)
	var light := Color(0.16, 0.4, 0.18)
	for i in 3:
		var t := float(i) / 3.0
		var r := height * lerpf(0.3, 0.14, t)
		var ch := height * 0.38
		kit.add_cylinder(Transform3D(Basis(), Vector3(0, height * (0.3 + t * 0.25) + ch * 0.5, 0)), 0.0, r, ch, dark.lerp(light, t), 9)
	return kit.commit()


## Grass tuft: a handful of short bright blades (ground cover near the player).
static func grass_tuft(rng: RandomNumberGenerator, size: float = 0.6) -> ArrayMesh:
	var leaves := _leaf_arrays()
	for i in rng.randi_range(6, 9):
		var angle := rng.randf() * TAU
		var dir := (Vector3(cos(angle), 0.0, sin(angle)) * 0.35 + Vector3.UP).normalized()
		_add_leaf(leaves, Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1)), dir, size * rng.randf_range(0.7, 1.2), size * 0.1, 0.25, rng.randf_range(0.9, 1.2))
	return _commit_leaves(leaves, grass_material())


static var _grass_material: ShaderMaterial


static func grass_material() -> ShaderMaterial:
	if _grass_material == null:
		_grass_material = ShaderMaterial.new()
		_grass_material.shader = FOLIAGE_SHADER
		_grass_material.set_shader_parameter("base_color", Color(0.16, 0.36, 0.1))
		_grass_material.set_shader_parameter("tip_color", Color(0.5, 0.72, 0.26))
		_grass_material.set_shader_parameter("wind_strength", 0.12)
	return _grass_material


## Fern: many narrow arching fronds.
static func fern(rng: RandomNumberGenerator, size: float = 1.2) -> ArrayMesh:
	var leaves := _leaf_arrays()
	var count := rng.randi_range(9, 13)
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		_add_frond(leaves, Vector3(0, 0.05, 0), (dir + Vector3.UP * 0.8).normalized(), size * rng.randf_range(0.8, 1.1), size * 0.12, 0.9, 1.0)
	return _commit_leaves(leaves, bush_material())


static func _trunk_point(t: float, height: float, lean: Vector3) -> Vector3:
	return Vector3(0.0, t * height, 0.0) + lean * t * t


static func _leaf_arrays() -> LeafBuffer:
	return LeafBuffer.new()


## Palm frond: arched spine with serrated leaflets folded in a V.
static func _add_frond(leaves: LeafBuffer, base: Vector3, dir: Vector3, length: float, width: float, droop: float, tint: float) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var n := 14
	var prev_c := base
	var prev_l := base
	var prev_r := base
	for i in range(1, n + 1):
		var s := float(i) / n
		var spine := base + dir * length * s + Vector3.UP * length * (0.35 * s - 0.55 * droop * s * s)
		var w := width * pow(sin(PI * minf(s * 1.1, 1.0)), 0.6) * (1.0 if i % 2 == 0 else 0.7)
		var drop := Vector3.DOWN * w * 0.45
		var l := spine + side * w + drop
		var r := spine - side * w + drop
		var a0 := float(i - 1) / n
		_quad(leaves, prev_c, spine, l, prev_l, a0, s, tint)
		_quad(leaves, prev_c, prev_r, r, spine, a0, s, tint)
		prev_c = spine
		prev_l = l
		prev_r = r


## Broad leaf: wide ellipse, slightly cupped.
static func _add_leaf(leaves: LeafBuffer, base: Vector3, dir: Vector3, length: float, width: float, droop: float, tint: float) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var n := 10
	var prev_c := base
	var prev_l := base
	var prev_r := base
	for i in range(1, n + 1):
		var s := float(i) / n
		var spine := base + dir * length * s + Vector3.DOWN * droop * length * s * s
		# Heart-ish outline: widest at 40 %, pointed tip.
		var w := width * pow(sin(PI * pow(s, 0.8)), 0.9) * (1.0 - 0.3 * s)
		var cup := Vector3.UP * w * 0.3
		var l := spine + side * w + cup
		var r := spine - side * w + cup
		var a0 := float(i - 1) / n
		_quad(leaves, prev_c, spine, l, prev_l, a0, s, tint)
		_quad(leaves, prev_c, prev_r, r, spine, a0, s, tint)
		prev_c = spine
		prev_l = l
		prev_r = r


static func _quad(leaves: LeafBuffer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, sa: float, sb: float, tint: float) -> void:
	var ca := Color(tint, tint, tint, sa)
	var cb := Color(tint, tint, tint, sb)
	leaves.verts.append_array([a, b, c, a, c, d])
	leaves.colors.append_array([ca, cb, cb, ca, cb, ca])


static func _commit_leaves(leaves: LeafBuffer, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in leaves.verts.size():
		st.set_color(leaves.colors[i])
		st.add_vertex(leaves.verts[i])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh
