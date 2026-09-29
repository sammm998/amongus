class_name WaterFactory
extends RefCounted
## Builds the stylized sea surface and waterfall materials.

const WATER_SHADER := preload("res://world/shaders/water_stylized.gdshader")
const WATERFALL_SHADER := preload("res://world/shaders/waterfall.gdshader")


static func sea(size: float, to_sun: Vector3, subdivisions: int = 96) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("normal_a", _noise_texture(3, 0.02, true))
	mat.set_shader_parameter("normal_b", _noise_texture(7, 0.035, true))
	mat.set_shader_parameter("foam_noise", _noise_texture(11, 0.03, false))
	mat.set_shader_parameter("sun_direction", to_sun.normalized())
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Bakes water depth (0 at the waterline) from a HeightField into a texture
## the sea shader samples for shallow colour and shoreline foam.
## `ground`: MapData or HeightField (anything with height(x, z)).
static func bake_depth(sea: MeshInstance3D, ground: Variant, bounds: Rect2, metres_per_pixel: float = 1.0, depth_range: float = 20.0) -> void:
	var w := int(bounds.size.x / metres_per_pixel)
	var h := int(bounds.size.y / metres_per_pixel)
	var img := Image.create(w, h, false, Image.FORMAT_RF)
	for y in h:
		for x in w:
			var wx := bounds.position.x + (x + 0.5) * metres_per_pixel
			var wz := bounds.position.y + (y + 0.5) * metres_per_pixel
			img.set_pixel(x, y, Color(clampf(-float(ground.height(wx, wz)) / depth_range, 0.0, 1.0), 0, 0))
	var mat: ShaderMaterial = sea.material_override
	mat.set_shader_parameter("depth_map", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("depth_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	mat.set_shader_parameter("depth_range", depth_range)


static func waterfall(width: float, height: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var mat := ShaderMaterial.new()
	mat.shader = WATERFALL_SHADER
	mat.set_shader_parameter("streak_noise", _noise_texture(5, 0.05, false, 128, 512))
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _noise_texture(seed: int, frequency: float, normal: bool, w: int = 256, h: int = 256) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = w
	tex.height = h
	tex.seamless = true
	tex.noise = noise
	tex.as_normal_map = normal
	tex.bump_strength = 6.0
	tex.generate_mipmaps = true
	return tex
