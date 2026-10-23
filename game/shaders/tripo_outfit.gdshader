shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_texture : filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform bool recolor = false;
uniform vec4 outfit_color : source_color = vec4(0.83, 0.45, 0.56, 1.0);

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb;
	float garment = smoothstep(0.25, 0.8, UV2.x);
	// The mask is restricted to the overalls; white shirt, buttons, face, hair,
	// shoes and backpack retain their supplied Tripo texture.
	float yellow = smoothstep(1.5, 2.2, base.r / max(base.b, 0.001));
	float brightness = clamp(dot(base, vec3(0.2126, 0.7152, 0.0722)) / 0.43, 0.3, 1.5);
	ALBEDO = mix(base, outfit_color.rgb * brightness, garment * yellow * float(recolor));
	ROUGHNESS = has_orm ? clamp(texture(orm_texture, UV).g, 0.55, 1.0) : 0.82;
	METALLIC = 0.0;
	SPECULAR = 0.3;
	if (has_normal) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = 0.55;
	}
}
