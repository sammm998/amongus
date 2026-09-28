// Stylized tropical water: depth-based turquoise -> deep blue, refraction of
// the sea floor in the shallows, shoreline foam, scrolling normals and sun glints.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 shallow_color : source_color = vec4(0.30, 0.95, 0.86, 1.0);
uniform vec4 mid_color : source_color = vec4(0.02, 0.66, 0.78, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.22, 0.48, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float shallow_depth = 1.8;
uniform float deep_depth = 16.0;
uniform float clarity = 3.5;
uniform float foam_distance = 0.9;
uniform sampler2D normal_a : hint_normal;
uniform sampler2D normal_b : hint_normal;
uniform sampler2D foam_noise : hint_default_white;
uniform float normal_scale = 0.05;
uniform float normal_strength = 0.5;
uniform vec2 flow_a = vec2(0.012, 0.007);
uniform vec2 flow_b = vec2(-0.009, 0.011);
uniform float wave_height = 0.1;
uniform vec3 sun_direction = vec3(0.6, 0.1, -0.8);
uniform float glint_strength = 6.0;
// Water depth baked from the terrain height field: R = depth / depth_range,
// covering depth_bounds (x, z, width, depth) in world space. Outside -> deep.
uniform sampler2D depth_map : filter_linear, repeat_disable, hint_default_white;
uniform vec4 depth_bounds = vec4(-100.0, -100.0, 200.0, 200.0);
uniform float depth_range = 20.0;
// Stylized self-illumination so the water keeps its vivid colour at golden hour.
uniform float body_glow = 0.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * 0.12 + TIME * 1.1) * 0.5 + sin(world_pos.z * 0.19 + TIME * 0.8) * 0.5;
	VERTEX.y += w * wave_height;
}

void fragment() {
	vec2 uv_a = world_pos.xz * normal_scale + TIME * flow_a;
	vec2 uv_b = world_pos.xz * normal_scale * 1.9 + TIME * flow_b;
	vec3 nmap = normalize(mix(texture(normal_a, uv_a).rgb, texture(normal_b, uv_b).rgb, 0.5));
	NORMAL_MAP = nmap;
	NORMAL_MAP_DEPTH = normal_strength;

	vec2 duv = (world_pos.xz - depth_bounds.xy) / depth_bounds.zw;
	float inside = step(0.0, duv.x) * step(duv.x, 1.0) * step(0.0, duv.y) * step(duv.y, 1.0);
	float vd = mix(depth_range, texture(depth_map, duv).r * depth_range, inside);

	vec3 water = mix(shallow_color.rgb, mid_color.rgb, smoothstep(0.0, shallow_depth, vd));
	water = mix(water, deep_color.rgb, smoothstep(shallow_depth, deep_depth, vd));

	vec2 offset = (nmap.xy - 0.5) * 0.03 * smoothstep(0.0, 1.5, vd);
	vec3 below = texture(screen_tex, SCREEN_UV + offset).rgb;
	float see = exp(-vd / clarity);
	vec3 col = mix(water, below * mix(vec3(1.0), shallow_color.rgb * 1.2, 0.6), see * 0.8);

	float fn = texture(foam_noise, world_pos.xz * 0.12 + TIME * 0.015).r;
	float edge = 1.0 - smoothstep(0.0, foam_distance, vd + (fn - 0.5) * 0.7);
	float bands = sin(vd * 5.0 - TIME * 1.8 + fn * 3.0) * 0.5 + 0.5;
	float band_foam = step(0.78, bands * fn * 1.4) * (1.0 - smoothstep(foam_distance, foam_distance * 3.0, vd));
	float foam = clamp(max(edge, band_foam), 0.0, 1.0);
	col = mix(col, foam_color.rgb, foam);

	vec3 view_dir = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec3 n_world = normalize(vec3((nmap.x - 0.5) * 0.35, 1.0, (nmap.y - 0.5) * 0.35));
	float align = max(dot(reflect(view_dir, n_world), normalize(sun_direction)), 0.0);
	float sparkle = pow(texture(foam_noise, world_pos.xz * 0.8 - TIME * 0.04).r, 10.0);
	float glint = (pow(align, 60.0) * 0.6 + pow(align, 400.0) * 3.0) * (0.35 + sparkle * 4.0);

	ALBEDO = col;
	ALPHA = 1.0;
	ROUGHNESS = mix(0.06, 0.7, foam);
	SPECULAR = 0.55;
	EMISSION = col * body_glow + glint_color.rgb * glint * glint_strength * (1.0 - foam);
}
