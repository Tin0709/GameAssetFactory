uniform sampler2D living_skin : source_color, filter_nearest, repeat_enable;
uniform sampler2D corpse_skin : source_color, filter_nearest, repeat_disable;
// Preserve the corpse tint across skin swaps. Flash uses slot zero.
instance uniform float desaturation : instance_index(1) = 0.0;

void fragment() {
	vec3 color = desaturation > 0.0 ? texture(corpse_skin, UV).rgb : texture(living_skin, UV).rgb;
	float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(color, vec3(gray), desaturation);
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
#ifdef ZOMBIE_HIT_FLASH
	// Blend the existing unlit flash into the lit skin in Forward Mobile.
	float opacity = hit_flash * 0.88;
	AO = 1.0 - opacity;
	AO_LIGHT_AFFECT = 1.0;
	EMISSION = vec3(flash_red, 1.93, 0.70) * opacity;
#endif
}
