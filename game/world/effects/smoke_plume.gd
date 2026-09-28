class_name SmokePlume
extends RefCounted
## Soft rising smoke (volcano, fires, supply-drop flares).


static func create(scale_m: float = 1.0, color: Color = Color(0.85, 0.72, 0.72, 0.55), amount: int = 48) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = AABB(Vector3(-60, -5, -60) * scale_m, Vector3(120, 140, 120) * scale_m)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.3, 1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 3.0 * scale_m
	pm.initial_velocity_max = 5.0 * scale_m
	pm.gravity = Vector3(1.2, 0.4, 0.0) * scale_m
	pm.damping_min = 0.2
	pm.damping_max = 0.4
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.6))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.0))
	fade.set_color(1, Color(color, 0.0))
	fade.add_point(0.15, color)
	fade.add_point(0.7, Color(color, color.a * 0.6))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 4.0 * scale_m
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(14, 14) * scale_m
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff_texture()
	mat.roughness = 1.0
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 3.0
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _puff_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t
