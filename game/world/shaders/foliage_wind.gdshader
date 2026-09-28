// Glossy tropical foliage with gentle wind sway. Vertex COLOR.rgb tints the
// leaf, COLOR.a is how much the vertex sways (0 at the stem, 1 at the tip).
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.14, 0.42, 0.12, 1.0);
uniform vec4 tip_color : source_color = vec4(0.42, 0.72, 0.16, 1.0);
uniform float roughness = 0.38;
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.3;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.4);
uniform float translucency = 0.5;
uniform bool sway_enabled = true;

void vertex() {
	if (sway_enabled) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float phase = dot(origin.xz, vec2(0.13, 0.21));
		float s = sin(TIME * wind_speed + phase + wp.x * 0.15) * 0.7
				+ sin(TIME * wind_speed * 2.3 + phase * 1.7 + wp.z * 0.3) * 0.3;
		vec3 offset = normalize(wind_direction) * s + vec3(0.0, s * 0.25, 0.0);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * offset * wind_strength * COLOR.a;
	}
}

void fragment() {
	vec3 leaf = mix(base_color.rgb, tip_color.rgb, clamp(COLOR.a, 0.0, 1.0)) * COLOR.rgb;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = leaf;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;
	BACKLIGHT = leaf * translucency;
}
