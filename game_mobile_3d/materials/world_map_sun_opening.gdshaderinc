global uniform float gaf_sun_opening_gain;
global uniform vec4 gaf_diffuse_opening;

// Lift the direct beam in lit openings using the existing geometric and
// projected visibility. Sky, bounce and local light stay separately owned.
float gaf_opening_gain(bool directional, float visibility) {
	if (!directional || gaf_sun_opening_gain <= 0.0) {
		return 1.0;
	}
	return 1.0 + gaf_sun_opening_gain * smoothstep(0.60, 0.88, visibility);
}

float gaf_diffuse_opening_weight(bool directional, vec3 light, vec3 light_color, mat4 inverse_view, float visibility) {
	if (!directional || gaf_diffuse_opening.w <= 0.0 || max(light_color.r, max(light_color.g, light_color.b)) <= 0.0) {
		return 0.0;
	}
	if (dot(mat3(inverse_view) * light, gaf_diffuse_opening.xyz) < 0.9999 ||
		distance(inverse_view[3].xyz, gaf_point_kernel_camera) > 0.005) {
		return 0.0;
	}
	// Original low-frequency response to the same shadow and projected visibility.
	return gaf_diffuse_opening.w * smoothstep(0.12, 0.76, visibility);
}
