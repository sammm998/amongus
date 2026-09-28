// Stylized waterfall sheet: streaks scroll downward, foamy edges.
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D streak_noise : hint_default_white;
uniform vec4 water_color : source_color = vec4(0.55, 0.92, 0.95, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 0.8;

void fragment() {
	vec2 uv = vec2(UV.x * 2.0, UV.y * 0.6 - TIME * speed);
	float n = texture(streak_noise, uv).r;
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float streak = smoothstep(0.45, 0.8, n);
	ALBEDO = mix(water_color.rgb, foam_color.rgb, streak * 0.8 + (1.0 - edge) * 0.4);
	ALPHA = mix(0.75, 1.0, streak) * edge;
	EMISSION = foam_color.rgb * streak * 0.25;
	ROUGHNESS = 0.2;
}
