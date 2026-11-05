uniform bool gaf_ground_contact_enabled = false;
uniform sampler2D gaf_ground_contact_field : filter_linear, repeat_disable;

float gaf_ground_contact_factor(vec3 world_position) {
	if (!gaf_ground_contact_enabled || world_position.y >= .65) { return 1.0; }
	vec2 uv = (world_position.xz + vec2(52.0)) / 104.0;
	float contact = texture(gaf_ground_contact_field, uv).r;
	float height_weight = 1.0 - smoothstep(.12, .65, world_position.y);
	return 1.0 - .48 * contact * height_weight;
}
