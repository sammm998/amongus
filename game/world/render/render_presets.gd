class_name RenderPresets
extends RefCounted
## Applies a graphics preset from data/render_presets.json to the environment,
## sun and viewport. Every expensive feature is individually toggleable.


static func default_name(table: Dictionary) -> String:
	return table["default_mobile"] if OS.has_feature("mobile") or OS.has_feature("web") else table["default_desktop"]


static func apply(preset: Dictionary, env: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	env.glow_enabled = bool(preset["glow"])
	env.ssao_enabled = bool(preset["ssao"]) and not compat
	env.ssil_enabled = bool(preset["ssil"]) and not compat
	env.volumetric_fog_enabled = bool(preset["volumetric_fog"]) and not compat
	env.sdfgi_enabled = bool(preset["sdfgi"]) and not compat
	if sun != null:
		var cascades := int(preset["shadow_cascades"])
		sun.shadow_enabled = cascades > 0
		match cascades:
			1:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			2:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			_:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = float(preset["shadow_distance"])
	RenderingServer.directional_shadow_atlas_set_size(int(preset["shadow_size"]), true)
	if viewport != null:
		var msaa := int(preset["msaa"])
		viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(msaa, 0, 2)] as Viewport.MSAA
		viewport.scaling_3d_scale = float(preset["render_scale"])
	Engine.max_fps = int(preset["max_fps"])
	for mat: ShaderMaterial in [VegetationBuilder.leaf_material(), VegetationBuilder.bush_material()]:
		mat.set_shader_parameter("sway_enabled", bool(preset["foliage_sway"]))
