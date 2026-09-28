// Painterly golden-hour sky: orange -> pink -> purple gradient, sun disc with
// glow, and stylized fluffy clouds lit warm on the sun side (GAME_SPEC §2).
shader_type sky;
render_mode use_debanding;

uniform vec4 zenith_color : source_color = vec4(0.20, 0.16, 0.42, 1.0);
uniform vec4 upper_color : source_color = vec4(0.55, 0.33, 0.62, 1.0);
uniform vec4 lower_color : source_color = vec4(1.0, 0.46, 0.42, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.62, 0.3, 1.0);
uniform vec4 below_color : source_color = vec4(0.10, 0.22, 0.40, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.86, 0.58, 1.0);
uniform float sun_disc_degrees = 1.6;
uniform float sun_energy = 14.0;
uniform float glow_energy = 0.9;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.6;
uniform float cloud_scale = 1.0;
uniform float cloud_speed = 0.003;
uniform vec4 cloud_lit : source_color = vec4(1.0, 0.62, 0.5, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.5, 0.3, 0.55, 1.0);
uniform float exposure = 1.0;
// Visual sun position (can sit lower than the light so scenes stay bright).
uniform vec3 sun_direction = vec3(0.72, 0.075, -0.69);
uniform bool use_light_direction = false;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 sun_dir = (use_light_direction && LIGHT0_ENABLED) ? LIGHT0_DIRECTION : normalize(sun_direction);
	float sun_dot = max(dot(d, sun_dir), 0.0);
	vec2 dxz = d.xz + vec2(1e-4);
	vec2 sxz = sun_dir.xz + vec2(1e-4);
	float toward_sun = max(dot(normalize(dxz), normalize(sxz)), 0.0);

	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color.rgb, lower_color.rgb, smoothstep(0.0, 0.09, h));
		col = mix(col, upper_color.rgb, smoothstep(0.06, 0.3, h));
		col = mix(col, zenith_color.rgb, smoothstep(0.25, 0.8, h));
		// The sky glows warmer toward the sun's azimuth.
		float warm = pow(toward_sun, 4.0) * (1.0 - smoothstep(0.0, 0.5, h));
		col = mix(col, horizon_color.rgb * 1.15, warm * 0.7);
	} else {
		col = mix(horizon_color.rgb * 0.85, below_color.rgb, smoothstep(0.0, -0.15, h));
	}

	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.1) * 0.35 * cloud_scale + TIME * cloud_speed;
		float n = fbm(uv * 1.3);
		float detail = fbm(uv * 4.1 + 3.1);
		float shape = n * 0.78 + detail * 0.32;
		float lo = 1.0 - cloud_coverage;
		float c = smoothstep(lo, lo + 0.08, shape);
		c *= smoothstep(0.0, 0.05, h);
		c *= 1.0 - 0.5 * smoothstep(0.5, 0.95, h);
		// Puffy shading: denser parts darker underneath, rims lit by the sun.
		float lit = clamp((detail - 0.35) * 1.6 + toward_sun * 0.55 + (1.0 - h) * 0.2, 0.0, 1.0);
		vec3 ccol = mix(cloud_shadow.rgb, cloud_lit.rgb, lit);
		ccol += sun_color.rgb * pow(sun_dot, 24.0) * 0.8;
		// Cloud underside darker, tops brighter: puffy volume.
		ccol *= mix(0.8, 1.15, smoothstep(0.3, 0.7, detail));
		col = mix(col, ccol, c * 0.95);
	}

	float disc = smoothstep(cos(radians(sun_disc_degrees)), cos(radians(sun_disc_degrees * 0.75)), sun_dot);
	float glow = pow(sun_dot, 120.0) * 2.5 + pow(sun_dot, 24.0) * 0.35;
	COLOR = col * exposure + sun_color.rgb * (disc * sun_energy + glow * glow_energy);
}
