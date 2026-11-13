// WorldMap calibration of the sky fill on evening turf. The neutral setting is identity.
#include "res://materials/world_map_point_kernel.gdshaderinc"
uniform vec3 turf_ambient_color = vec3(1.0);
global uniform float gaf_dawn_turf_color;

vec3 gaf_turf_ambient(vec3 rgb) {
	const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
	vec3 tinted = rgb * vec3(turf_ambient_color.x, 1.0, turf_ambient_color.y);
	return tinted * (dot(rgb, luma) / max(dot(tinted, luma), 0.000001)) * turf_ambient_color.z;
}

// Independent color fit using the measured difference between the Forest
// material and incident-light contributions. Keep the player's light pool.
float gaf_dawn_turf_weight(vec3 world, vec3 camera) {
	if (gaf_dawn_turf_color <= 0.0 || distance(camera, gaf_point_kernel_camera) > 0.005) return 0.0;
	return gaf_dawn_turf_color * smoothstep(5.5, 9.0, distance(world, gaf_point_kernel.xyz));
}

float gaf_dawn_turf_coverage(vec3 albedo) {
	return smoothstep(1.09, 1.37, albedo.g / max(albedo.r, 0.0001)) *
		smoothstep(1.18, 1.45, albedo.g / max(albedo.b, 0.0001));
}

vec3 gaf_dawn_turf_chroma(vec3 rgb, vec3 ratios, float weight) {
	if (weight <= 0.0) return rgb;
	const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
	vec3 target = rgb * ratios;
	target *= dot(rgb, luma) / max(dot(target, luma), 0.000001);
	return mix(rgb, target, weight);
}
