shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin : source_color, filter_nearest, repeat_disable;
instance uniform float desaturation = 0.0;

void fragment() {
	vec3 color = texture(skin, UV).rgb;
	float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(color, vec3(gray), desaturation);
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
}
