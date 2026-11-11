shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 shallow_color : source_color = vec4(0.46, 0.85, 0.80, 0.78);
uniform vec4 deep_color : source_color = vec4(0.18, 0.56, 0.67, 0.92);
uniform vec4 foam_color : source_color = vec4(0.98, 0.99, 0.96, 0.96);
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.97, 0.84, 1.0);

uniform vec2 flow_direction = vec2(0.65, 0.42);
uniform float world_time = 0.0;
uniform float ripple_strength : hint_range(0.0, 1.5) = 0.68;
uniform float foam_distance : hint_range(0.05, 2.5) = 0.62;
uniform float wave_scale : hint_range(0.1, 4.0) = 0.85;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = world_time * 1.15;
	float bob = sin(v_world_pos.x * 1.35 + t) * cos(v_world_pos.z * 1.15 - t * 0.8) * 0.018 * ripple_strength;
	VERTEX.y += bob;
}

void fragment() {
	vec2 dir = normalize(flow_direction + vec2(0.0001));
	float t = world_time * 0.42;
	vec2 uv_a = v_world_pos.xz * wave_scale + dir * t;
	vec2 uv_b = v_world_pos.xz * (wave_scale * 1.65) - dir.yx * (t * 0.78);

	float n1 = value_noise(uv_a * 2.4);
	float n2 = value_noise(uv_b * 3.3);
	float wave = (n1 * 0.58 + n2 * 0.42);

	// Soft procedural normal for toy-like glossy water facets
	float nx = (value_noise(uv_a * 2.4 + vec2(0.08, 0.0)) - n1) * 2.4 * ripple_strength;
	float nz = (value_noise(uv_b * 3.3 + vec2(0.0, 0.08)) - n2) * 2.4 * ripple_strength;
	NORMAL = normalize(mix(NORMAL, normalize(vec3(-nx, 1.0, -nz)), 0.38));

	// Depth-based shoreline foam & shallow-to-deep gradient
	float raw_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	vec4 view_behind = INV_PROJECTION_MATRIX * ndc;
	view_behind.xyz /= max(abs(view_behind.w), 0.00001);
	float water_depth = max(0.0, (-view_behind.z) - (-VERTEX.z));

	float depth_blend = clamp(water_depth / 2.6, 0.0, 1.0);
	vec3 base_col = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, 1.0, depth_blend));

	// Animated caustics ribbons in shallow water
	float caustic = smoothstep(0.66, 0.90, sin(uv_a.x * 5.2 + sin(uv_b.y * 4.4)) * 0.5 + 0.5);
	base_col += shallow_color.rgb * caustic * (1.0 - depth_blend) * 0.18 * ripple_strength;

	//Toy-diorama double-ring shoreline foam
	float shore = 1.0 - clamp(water_depth / max(foam_distance, 0.05), 0.0, 1.0);
	float foam_wave = sin(shore * 14.0 - world_time * 2.6 + wave * 3.2) * 0.5 + 0.5;
	float foam_mask = smoothstep(0.45, 0.88, shore * 0.85 + foam_wave * shore * 0.48);
	// Crest sparkles
	float sparkle = smoothstep(0.87, 0.97, wave) * ripple_strength;

	vec3 final_rgb = mix(base_col, foam_color.rgb, clamp(foam_mask, 0.0, 1.0));
	final_rgb = mix(final_rgb, sparkle_color.rgb, sparkle * 0.55);

	ALBEDO = final_rgb;
	ROUGHNESS = mix(0.11, 0.55, foam_mask);
	SPECULAR = 0.72;
	METALLIC = 0.02;
	ALPHA = clamp(mix(shallow_color.a, deep_color.a, depth_blend) + foam_mask * 0.22, 0.0, 0.97);
}
