class_name EnvironmentRig
extends RefCounted
## Builds sky, sun and environment from a time-of-day preset
## (data/time_of_day.json). Returns {"environment", "sun", "sky_material", "preset"}.

const SKY_SHADER := preload("res://world/shaders/sky_sunset.gdshader")


static func preset(name: String) -> Dictionary:
	var table: Dictionary = GameData.table("time_of_day")
	var presets: Dictionary = table["presets"]
	return presets.get(name, presets[table["default"]])


static func sun_vector(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var az := deg_to_rad(azimuth_deg)
	var el := deg_to_rad(elevation_deg)
	# Azimuth 0 = -Z (north), 90 = +X (east).
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


static func build(p: Dictionary) -> Dictionary:
	var sky_cfg: Dictionary = p["sky"]
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky_sun := sun_vector(float(p["sun_azimuth_degrees"]), float(p["sky_sun_elevation_degrees"]))
	sky_mat.set_shader_parameter("sun_direction", sky_sun)
	for key: String in ["zenith", "upper", "lower", "horizon", "below"]:
		sky_mat.set_shader_parameter("%s_color" % key, Color(sky_cfg[key]))
	sky_mat.set_shader_parameter("sun_color", Color(sky_cfg["sun"]))
	sky_mat.set_shader_parameter("sun_energy", float(sky_cfg["sun_energy"]))
	sky_mat.set_shader_parameter("glow_energy", float(sky_cfg["glow_energy"]))
	sky_mat.set_shader_parameter("cloud_coverage", float(sky_cfg["cloud_coverage"]))
	sky_mat.set_shader_parameter("cloud_lit", Color(sky_cfg["cloud_lit"]))
	sky_mat.set_shader_parameter("cloud_shadow", Color(sky_cfg["cloud_shadow"]))
	sky_mat.set_shader_parameter("sun_disc_degrees", float(sky_cfg["sun_disc_degrees"]))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(p["ambient_energy"])
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES if p["tonemap"] == "aces" else Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(p["exposure"])
	env.glow_enabled = true
	env.glow_intensity = float(p["glow_intensity"])
	env.glow_hdr_threshold = float(p["glow_threshold"])
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(p["fog_color"])
	env.fog_density = float(p["fog_density"])
	env.fog_aerial_perspective = float(p["fog_aerial"])
	env.fog_sun_scatter = 0.05
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(p["volumetric_density"])
	env.volumetric_fog_albedo = Color(p["fog_color"])
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = float(p["saturation"])
	env.adjustment_contrast = float(p["contrast"])
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	var light_cfg: Dictionary = p["light"]
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(light_cfg["color"])
	sun.light_energy = float(light_cfg["energy"])
	sun.shadow_enabled = true
	sun.shadow_blur = float(light_cfg["shadow_blur"])
	sun.directional_shadow_max_distance = 300.0
	# Generous biases: no striped "shadow acne" on flat roofs/ground (web renderer too).
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.5
	var light_dir := sun_vector(float(p["sun_azimuth_degrees"]), float(p["sun_elevation_degrees"]))
	sun.basis = Basis.looking_at(-light_dir, Vector3.UP)
	return {"environment": world_env, "sun": sun, "sky_material": sky_mat, "preset": p, "sky_sun": sky_sun}
