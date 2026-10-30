// Independently authored field-consumer math. Z-up basis, meter lengths.
// No spawning, particle lifetime, force history, or field generation is implied.
float foliage_saturated_ratio(float numerator, float denominator) {
 return denominator == 0.0 ? (numerator > 0.0 ? 1.0 : 0.0) : clamp(numerator / denominator, 0.0, 1.0);
}
vec3 foliage_contact_wpo(vec3 relative_position, vec2 encoded_field, float clock_seconds,
 float oscillation_frequency, float threshold, float strong_gain, float angle_scale,
 float pin_height, float pin_width) {
 return vec3(0.0);
}
