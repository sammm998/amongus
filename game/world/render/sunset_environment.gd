class_name SunsetEnvironment
extends RefCounted
## Golden-hour lighting rig: painterly sky, low warm sun, cool sky fill,
## bloom, haze. Returns {"environment": WorldEnvironment, "sun": DirectionalLight3D}.

const SKY_SHADER := preload("res://world/shaders/sky_sunset.gdshader")


## `to_sun` points from the scene toward the visible sun disc. The light itself
## sits `light_elevation_deg` higher so flat ground still catches warm light.
static func build(to_sun: Vector3, light_elevation_deg: float = 14.0) -> Dictionary:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("sun_direction", to_sun.normalized())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 1.0)
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(1.0, 0.66, 0.55)
	env.fog_sun_scatter = 0.03
	env.fog_density = 0.00025
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.00035
	env.volumetric_fog_albedo = Color(1.0, 0.82, 0.72)
	env.volumetric_fog_anisotropy = 0.3
	env.volumetric_fog_length = 200.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.3
	env.adjustment_contrast = 1.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.76, 0.5)
	sun.light_energy = 2.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 300.0
	sun.light_angular_distance = 1.2
	var flat := Vector3(to_sun.x, 0.0, to_sun.z).normalized()
	var elev := deg_to_rad(light_elevation_deg)
	var light_dir := flat * cos(elev) + Vector3.UP * sin(elev)
	sun.basis = Basis.looking_at(-light_dir, Vector3.UP)
	return {"environment": world_env, "sun": sun, "sky_material": sky_mat}
