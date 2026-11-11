shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_tint : source_color = vec4(0.46, 0.72, 0.47, 1.0);
uniform vec4 tip_warmth : source_color = vec4(0.76, 0.88, 0.55, 1.0);
uniform vec4 subsurface_tint : source_color = vec4(0.84, 0.93, 0.58, 1.0);
uniform float wind_time = 0.0;
uniform float sway_strength : hint_range(0.0, 0.25) = 0.045;
uniform float roughness_val : hint_range(0.1, 1.0) = 0.68;

varying float v_height_mask;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_height_mask = clamp(VERTEX.y * 0.85 + 0.35, 0.0, 1.0);
	float phase = world_pos.x * 0.9 + world_pos.z * 0.75;
	float gust = sin(wind_time * 1.45 + phase) * (0.75 + 0.25 * sin(wind_time * 0.37 + phase * 0.5));
	VERTEX.x += gust * sway_strength * v_height_mask;
	VERTEX.z += cos(wind_time * 1.2 + phase * 1.1) * sway_strength * 0.65 * v_height_mask;
}

void fragment() {
	vec3 col = mix(albedo_tint.rgb, tip_warmth.rgb, smoothstep(0.15, 0.95, v_height_mask));
	ALBEDO = col;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.28;
	BACKLIGHT = subsurface_tint.rgb * 0.42;
}
