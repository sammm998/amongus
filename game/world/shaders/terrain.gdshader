// Terrain: vertex colours (sand/grass/rock) broken up with world-space noise
// so large areas don't look flat; slightly darker in crevices.
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D detail_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float detail_scale = 0.06;
uniform float macro_scale = 0.006;
uniform float variation = 0.22;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float d = texture(detail_noise, world_pos.xz * detail_scale).r;
	float m = texture(detail_noise, world_pos.xz * macro_scale + vec2(0.37, 0.71)).r;
	float v = 1.0 + (d - 0.5) * variation + (m - 0.5) * variation * 1.4;
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	vec3 base = pow(COLOR.rgb, vec3(2.2));  // vertex colours are authored in sRGB
	vec3 col = base * v * (1.0 - slope * 0.25);
	ALBEDO = col;
	ROUGHNESS = 0.92 - d * 0.1;
	SPECULAR = 0.3;
}
