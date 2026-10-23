shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// Overlay only: original mesh vertices, UV channels, vertex colours and base
// materials are untouched. TIME is deliberately not used: the world clock pauses.
uniform float world_time = 0.0;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.65;
uniform vec2 flow_direction = vec2(0.2, 1.0);
varying vec3 surface_world;

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = surface_world.xz;
	float wave_a = sin(dot(p, flow_direction) * 3.0 - world_time * 0.55);
	float wave_b = sin(p.x * 1.4 + p.y * 1.1 + world_time * 0.22);
	float crest = smoothstep(0.70, 0.98, wave_a * 0.7 + wave_b * 0.3);
	ALBEDO = vec3(0.78, 0.88, 0.84);
	ALPHA = crest * 0.12 * ripple_strength;
}
