// Independent mathematical interface; private fixtures are external.
vec3 foliage_rotation_delta(vec3 relative_position, vec3 axis, float angle) {
	return vec3(0.0);
}
vec3 foliage_background_wpo(vec3 relative_position, vec2 axis_input,
		vec2 noise_samples, float gain, float pin_height, float pin_width,
		float vertex_red, float attenuation, float maximum_displacement) {
	return vec3(0.0);
}
