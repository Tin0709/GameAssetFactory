// Independently authored wind math. Inputs use a Z-up basis and meters.
// Private material/collection values and texture samples are supplied externally.
// No particle spawn, field recovery, sampler or engine-clock behavior is implied.
vec3 foliage_rotation_delta(vec3 relative_position, vec3 axis, float angle) {
	vec3 transverse = relative_position - axis * dot(axis, relative_position);
	return transverse * (cos(angle) - 1.0) + cross(axis, transverse) * sin(angle);
}
float foliage_noise_ease(float value) {
	float bounded_value = clamp(value, 0.0, 1.0);
	return bounded_value * bounded_value * (3.0 - 2.0 * bounded_value);
}
vec3 foliage_background_wpo(vec3 relative_position, vec2 axis_input,
		vec2 noise_samples, float gain, float pin_height, float pin_width,
		float vertex_red, float attenuation, float maximum_displacement) {
	float detail = foliage_noise_ease((noise_samples.y - 0.1) / 0.9);
	float broad = foliage_noise_ease((noise_samples.x + 0.2 * detail + 0.2) / 1.4);
	float height_weight = clamp((relative_position.z - pin_height) / max(pin_width, 0.000001), 0.0, 1.0);
	vec3 axis = normalize(vec3(axis_input + vec2(0.01), 0.0));
	float angle = gain * height_weight * (1.5 * broad - 0.5);
	vec3 delta = foliage_rotation_delta(relative_position, axis, angle) * (1.0 - vertex_red * attenuation);
	if (maximum_displacement > 0.0) {
		delta = clamp(delta, vec3(-maximum_displacement), vec3(maximum_displacement));
	}
	return delta;
}
