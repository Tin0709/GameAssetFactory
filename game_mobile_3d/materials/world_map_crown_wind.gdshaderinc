// Filtered playback of the measured Oak wind samples in a world-fixed frame.
// Keep the point-sampled PIX comparison evaluator separate.
vec3 gaf_leaf_world_drift(sampler2D pattern, vec3 position, float root_height, vec2 state, float weight) {
	vec3 relative = position - vec3(0.0, root_height + 24.0, 0.0);
	relative.y = min(relative.y, -8.0);
	vec2 slope = relative.xz / relative.y;
	float broad = textureLod(pattern, slope * 0.05 + state.x * vec2(-0.05, 0.1), 0.0).r;
	vec2 detail = textureLod(pattern, slope + state.x * vec2(0.1, 0.5), 0.0).gb;
	float horizontal = (3.0 * broad + 0.25 * detail.x - 1.0) * 0.30;
	return state.y * weight * vec3(horizontal, detail.y * 0.15, horizontal);
}
