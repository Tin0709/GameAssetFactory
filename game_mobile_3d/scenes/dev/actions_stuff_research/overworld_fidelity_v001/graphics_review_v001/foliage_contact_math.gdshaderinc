// Independently authored field-consumer math. Z-up basis, meter lengths.
// No spawning, particle lifetime, force history, or field generation is implied.
float foliage_saturated_ratio(float numerator, float denominator) {
 return denominator == 0.0 ? (numerator > 0.0 ? 1.0 : 0.0) : clamp(numerator / denominator, 0.0, 1.0);
}
vec3 foliage_contact_wpo(vec3 relative_position, vec2 encoded_field, float clock_seconds,
 float oscillation_frequency, float threshold, float strong_gain, float angle_scale,
 float pin_height, float pin_width) {
 float proximity = foliage_saturated_ratio(encoded_field.y, threshold);
 float strong_weight = foliage_saturated_ratio(encoded_field.y - threshold, 1.0 - threshold);
 float direction_y = 2.0 * encoded_field.x - 1.0;
 float ripple = 0.1 * sin(clock_seconds * oscillation_frequency * 6.2831854820251465);
 float quiet_response = ripple * proximity;
 float strong_response = encoded_field.y * sqrt(1.0 + direction_y * direction_y) * strong_gain;
 float response = mix(quiet_response, strong_response, strong_weight * proximity);
 float angle = angle_scale * 6.2831854820251465 * response;
 float height_weight = clamp((relative_position.z - pin_height) / max(pin_width, 0.000001), 0.0, 1.0);
 // The recovered field branch uses this axis without normalization. Normalizing
 // it changes both the rotation amplitude and its axial component.
 return height_weight * foliage_rotation_delta(relative_position, vec3(1.0, direction_y, 0.0), angle);
}
