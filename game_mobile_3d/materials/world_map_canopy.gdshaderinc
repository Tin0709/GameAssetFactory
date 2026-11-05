uniform sampler2D canopy_field : filter_linear, repeat_disable;
uniform vec2 canopy_origin = vec2(0.0);
uniform vec2 canopy_extent = vec2(1.0);
uniform float canopy_base_y = 0.0;
// Ambient contact with a weaker direct term to ground the porous near-ground leaves.
const float CANOPY_STRENGTH = 0.82;
const float CANOPY_DIRECT_AFFECT = 0.40;

float canopy_ao(vec3 receiver) {
	vec2 uv = (receiver.xz - canopy_origin) / canopy_extent;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) return 1.0;
	vec3 field = textureLod(canopy_field, uv, 0.0).rgb;
	if (field.r <= 0.00392) return 1.0;
	float height = canopy_base_y + dot(field.gb, vec2(1020.0, 3.984375)) / field.r;
	float match_height = 1.0 - smoothstep(0.12, 0.28, abs(receiver.y - height));
	return 1.0 - field.r * match_height * CANOPY_STRENGTH;
}
