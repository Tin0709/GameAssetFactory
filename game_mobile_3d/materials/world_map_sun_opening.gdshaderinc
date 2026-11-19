#include "res://materials/world_map_point_kernel.gdshaderinc"

global uniform float gaf_sun_opening_gain;
global uniform vec4 gaf_diffuse_opening;
global uniform vec4 gaf_shadow_diffuse_sun;
global uniform vec3 gaf_shadow_diffuse_tint;
global uniform vec2 gaf_ground_shadow_fill_reduction;
global uniform vec4 gaf_turf_sun_chroma;

float gaf_turf_sun_weight(bool directional, vec3 view_light, mat4 inverse_view, float visibility) {
	if (!directional || gaf_turf_sun_chroma.w <= 0.0 ||
			dot(mat3(inverse_view) * view_light, gaf_turf_sun_chroma.xyz) < 0.9999 ||
			distance(inverse_view[3].xyz, gaf_point_kernel_camera) > 0.005) {
		return 0.0;
	}
	return smoothstep(0.27, 0.85, visibility) * gaf_turf_sun_chroma.w;
}

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

vec3 gaf_shadow_diffuse(bool directional, vec3 view_light, mat4 inverse_view,
		float attenuation, float cloud, float facing, float contact) {
	if (gaf_shadow_diffuse_sun.w <= 0.0 || !directional ||
		dot(mat3(inverse_view) * view_light, gaf_shadow_diffuse_sun.xyz) < .9999 ||
		distance(inverse_view[3].xyz, gaf_point_kernel_camera) > .005) {
		return vec3(0.0);
	}
	float direct = attenuation * cloud * facing;
	float shade = 1.0 - smoothstep(.055, .48, direct);
	return gaf_shadow_diffuse_tint * (gaf_shadow_diffuse_sun.w * contact * shade);
}

float gaf_ground_shadow_fill_multiplier(float reduction, float attenuation) {
	// Fade out the fill correction toward the bright side of the penumbra.
	return 1.0 - reduction * (1.0 - smoothstep(.02, .40, attenuation));
}
