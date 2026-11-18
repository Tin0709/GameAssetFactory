shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D living_skin : source_color, filter_nearest, repeat_enable;
uniform sampler2D corpse_skin : source_color, filter_nearest, repeat_disable;
// Slot zero belongs to the separate hit flash material.
instance uniform float desaturation : instance_index(1) = 0.0;

void fragment() {
	vec3 color = desaturation > 0.0 ? texture(corpse_skin, UV).rgb : texture(living_skin, UV).rgb;
	float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(color, vec3(gray), desaturation);
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
}
