class_name RockBuilder
extends RefCounted
## Chunky rounded rocks: noise-displaced spheres with a mossy top tint.

const ROCK_DARK := Color(0.27, 0.25, 0.24)
const ROCK_LIGHT := Color(0.42, 0.39, 0.36)
const MOSS := Color(0.26, 0.42, 0.16)

static var _material: StandardMaterial3D


static func rock(rng: RandomNumberGenerator, size: Vector3, moss: float = 0.4) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 1.4
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 18
	sphere.rings = 10
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	var shade := rng.randf()
	for i in verts.size():
		var v := verts[i]
		var dir := v.normalized() if v.length() > 0.0001 else Vector3.UP
		var bump := noise.get_noise_3dv(dir * 1.3) * 0.28 + noise.get_noise_3dv(dir * 4.0) * 0.06
		var p := dir * (1.0 + bump)
		p.y = maxf(p.y, -0.35)  # flat-ish bottom so it sits on the ground
		verts[i] = p * size
		var c := ROCK_DARK.lerp(ROCK_LIGHT, clampf(shade * 0.6 + bump * 1.5 + 0.2, 0.0, 1.0))
		colors[i] = c.lerp(MOSS, clampf((dir.y - 0.55) * 2.5, 0.0, 1.0) * moss)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, material())
	return mesh


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.88
	return _material
