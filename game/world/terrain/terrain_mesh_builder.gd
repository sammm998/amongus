class_name TerrainMeshBuilder
extends RefCounted
## Builds vertex-coloured terrain meshes (and collision) from a HeightField.

const SEABED := Color(0.86, 0.84, 0.66)
const SAND := Color(0.9, 0.84, 0.68)
const WET_SAND := Color(0.74, 0.66, 0.52)
const GRASS := Color(0.27, 0.44, 0.16)
const JUNGLE := Color(0.13, 0.27, 0.1)
const ROCK := Color(0.22, 0.2, 0.21)
const CORAL_A := Color(0.9, 0.45, 0.5)
const CORAL_B := Color(0.35, 0.62, 0.45)

var beach_top := 1.9
var grass_start := 2.8
var rock_slope := 0.72  # normal.y below this is rock
var high_rock := 45.0   # above this height everything is rock
var _detail := FastNoiseLite.new()


func _init() -> void:
	_detail.seed = 11
	_detail.frequency = 0.05


## Mesh covering [origin, origin + size] with `res` cells per side.
func build_mesh(field: HeightField, origin: Vector2, size: Vector2, res: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var step := size / float(res)
	verts.resize((res + 1) * (res + 1))
	normals.resize(verts.size())
	colors.resize(verts.size())
	var i := 0
	for zi in res + 1:
		for xi in res + 1:
			var x := origin.x + xi * step.x
			var z := origin.y + zi * step.y
			var h := field.height_at(x, z)
			var n := field.normal_at(x, z, maxf(step.x, 0.5))
			verts[i] = Vector3(x, h, z)
			normals[i] = n
			colors[i] = color_for(h, n, x, z, field.coast_distance(x, z) - field.beach_width)
			i += 1
	for zi in res:
		for xi in res:
			var a := zi * (res + 1) + xi
			var b := a + 1
			var c := a + res + 1
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh


## `inland` = metres past the top of the beach (negative on the beach / at sea).
func color_for(h: float, n: Vector3, x: float, z: float, inland: float = 1000.0) -> Color:
	var jitter := _detail.get_noise_2d(x, z)
	var c: Color
	if h < -0.4:
		c = SEABED
		var coral := _detail.get_noise_2d(x * 2.7 + 100.0, z * 2.7)
		if h < -1.2 and coral > 0.35:
			c = CORAL_A.lerp(CORAL_B, clampf(jitter + 0.5, 0.0, 1.0))
	elif h < 0.25:
		c = WET_SAND.lerp(SAND, clampf((h + 0.4) / 0.65, 0.0, 1.0))
	elif h < beach_top and inland >= 999.0:
		c = SAND
	else:
		var g := clampf((h - beach_top) / (grass_start - beach_top), 0.0, 1.0)
		if inland < 999.0:
			g = smoothstep(-2.0, 4.0, inland + _detail.get_noise_2d(x * 3.0, z * 3.0) * 3.0)
		var green := GRASS.lerp(JUNGLE, clampf(0.5 + jitter * 1.2 + (h - 8.0) / 30.0, 0.0, 1.0))
		c = SAND.lerp(green, g)
	if h > 0.8 and (n.y < rock_slope or h > high_rock):
		var r := 1.0 - smoothstep(rock_slope - 0.12, rock_slope, n.y)
		if h > high_rock:
			r = 1.0
		c = c.lerp(ROCK * (0.9 + jitter * 0.2), r)
	return c


static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://world/shaders/terrain.gdshader")
		var noise := FastNoiseLite.new()
		noise.seed = 5
		noise.frequency = 0.02
		noise.fractal_octaves = 4
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.noise = noise
		tex.generate_mipmaps = true
		_material.set_shader_parameter("detail_noise", tex)
	return _material


## Height-map collision for a square area with 1 m cells (HeightMapShape3D
## must not be scaled non-uniformly, so cell size stays at 1 m).
static func build_collision(field: HeightField, center: Vector2, size: int) -> CollisionShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = size + 1
	shape.map_depth = size + 1
	var data := PackedFloat32Array()
	data.resize((size + 1) * (size + 1))
	var origin := center - Vector2(size, size) * 0.5
	for zi in size + 1:
		for xi in size + 1:
			data[zi * (size + 1) + xi] = field.height_at(origin.x + xi, origin.y + zi)
	shape.map_data = data
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(center.x, 0.0, center.y)
	return col
