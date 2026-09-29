class_name MeshKit
extends RefCounted
## Accumulates primitive parts (with vertex colours) into one ArrayMesh with a
## few shared material slots. Keeps draw calls low for chunky stylized props.

const SLOT_MATTE := "matte"
const SLOT_GLOSS := "gloss"
const SLOT_METAL := "metal"
const SLOT_GLOW := "glow"
const SLOT_GLASS := "glass"
const SLOT_GLOW_RED := "glow_red"
const SLOT_GLOW_CYAN := "glow_cyan"
const GLOW_COLORS := {
	SLOT_GLOW: Color(1.0, 0.72, 0.38),
	SLOT_GLOW_RED: Color(1.0, 0.12, 0.08),
	SLOT_GLOW_CYAN: Color(0.2, 0.9, 1.0),
}

static var _materials: Dictionary = {}

var _tools: Dictionary = {}  # slot -> SurfaceTool


func add_box(xf: Transform3D, size: Vector3, color: Color, slot: String = SLOT_MATTE) -> void:
	var m := BoxMesh.new()
	m.size = size
	add_arrays(m.get_mesh_arrays(), xf, color, slot)


func add_cylinder(xf: Transform3D, top: float, bottom: float, height: float, color: Color, segments: int = 12, slot: String = SLOT_MATTE) -> void:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	add_arrays(m.get_mesh_arrays(), xf, color, slot)


func add_sphere(xf: Transform3D, radius: float, color: Color, segments: int = 12, slot: String = SLOT_MATTE) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(4, segments / 2)
	add_arrays(m.get_mesh_arrays(), xf, color, slot)


func add_capsule(xf: Transform3D, radius: float, height: float, color: Color, slot: String = SLOT_MATTE) -> void:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	add_arrays(m.get_mesh_arrays(), xf, color, slot)


func add_prism(xf: Transform3D, size: Vector3, color: Color, slot: String = SLOT_MATTE) -> void:
	var m := PrismMesh.new()
	m.size = size
	add_arrays(m.get_mesh_arrays(), xf, color, slot)


## Thin beam between two points (lattice towers, rails).
func add_beam(a: Vector3, b: Vector3, thickness: float, color: Color, slot: String = SLOT_MATTE) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.001:
		return
	var y := dir / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	add_box(Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(thickness, length, thickness), color, slot)


## Round tapered tube between two points (palm trunks, pipes, posts).
func add_tube(a: Vector3, b: Vector3, radius_a: float, radius_b: float, color: Color, segments: int = 10, slot: String = SLOT_MATTE) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.001:
		return
	var y := dir / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	add_cylinder(Transform3D(Basis(x, y, z), (a + b) * 0.5), radius_b, radius_a, length, color, segments, slot)


## Half-cylinder shell (curved hangar roof), axis along local Z.
func add_arch(xf: Transform3D, radius: float, length: float, thickness: float, color: Color, segments: int = 16, slot: String = SLOT_MATTE) -> void:
	for i in segments:
		var a0 := PI * float(i) / segments
		var a1 := PI * float(i + 1) / segments
		var p0 := Vector3(cos(a0) * radius, sin(a0) * radius, 0.0)
		var p1 := Vector3(cos(a1) * radius, sin(a1) * radius, 0.0)
		var mid := (p0 + p1) * 0.5
		var tangent := (p1 - p0).normalized()
		var normal := Vector3(mid.x, mid.y, 0.0).normalized()
		var basis := Basis(tangent, normal, Vector3.BACK)
		var width := p0.distance_to(p1) + 0.02
		add_box(xf * Transform3D(basis, mid), Vector3(width, thickness, length), color, slot)


func add_arrays(arrays: Array, xf: Transform3D, color: Color, slot: String) -> void:
	var st: SurfaceTool = _tools.get(slot)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[slot] = st
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	for idx in indices:
		st.set_color(color)
		st.set_normal((nb * normals[idx]).normalized())
		st.add_vertex(xf * verts[idx])


func add_colored_triangles(verts: PackedVector3Array, colors: PackedColorArray, slot: String = SLOT_MATTE) -> void:
	var st: SurfaceTool = _tools.get(slot)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[slot] = st
	for i in verts.size():
		st.set_color(colors[i])
		st.add_vertex(verts[i])
	st.generate_normals()


func is_empty() -> bool:
	return _tools.is_empty()


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for slot: String in _tools:
		var st: SurfaceTool = _tools[slot]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(slot))
	return mesh


func to_instance(xf: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = commit()
	mi.transform = xf
	return mi


static func material(slot: String) -> Material:
	if _materials.has(slot):
		return _materials[slot]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	match slot:
		SLOT_GLOSS:
			m.roughness = 0.3
			m.clearcoat_enabled = true
		SLOT_METAL:
			m.roughness = 0.4
			m.metallic = 0.55
		SLOT_GLOW, SLOT_GLOW_RED, SLOT_GLOW_CYAN:
			m.roughness = 0.5
			m.emission_enabled = true
			m.emission = GLOW_COLORS[slot]
			m.emission_energy_multiplier = 2.4
		SLOT_GLASS:
			m.roughness = 0.08
			m.metallic = 0.3
		_:
			m.roughness = 0.85
	_materials[slot] = m
	return m
