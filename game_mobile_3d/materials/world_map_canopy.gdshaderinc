uniform sampler2D canopy_field : filter_linear, repeat_disable;
uniform vec2 canopy_origin = vec2(0.0);
uniform vec2 canopy_extent = vec2(1.0);
uniform float canopy_base_y = 0.0;
// Ambient contact with a weaker direct term to ground the porous near-ground leaves.
const float CANOPY_STRENGTH = 0.82;
const float CANOPY_DIRECT_AFFECT = 0.40;

vec2 canopy_ao(vec3 receiver) {
	vec2 uv = (receiver.xz - canopy_origin) / canopy_extent;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) return vec2(1.0, CANOPY_DIRECT_AFFECT);
	vec4 field = textureLod(canopy_field, uv, 0.0);
	if (field.r <= 0.00392) return vec2(1.0, CANOPY_DIRECT_AFFECT);
	float inverse_coverage = 1.0 / field.r;
	float height = canopy_base_y + dot(field.gb, vec2(1020.0, 3.984375)) * inverse_coverage;
	float match_height = 1.0 - smoothstep(0.12, 0.28, abs(receiver.y - height));
	// The oak part affects ambient fill. Keep the established shrub direct term.
	float shrub_share = clamp(1.0 - field.a * inverse_coverage, 0.0, 1.0);
	return vec2(1.0 - field.r * match_height * CANOPY_STRENGTH, shrub_share * CANOPY_DIRECT_AFFECT);
}
