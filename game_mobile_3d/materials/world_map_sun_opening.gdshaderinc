#include "res://materials/world_map_point_kernel.gdshaderinc"

global uniform float gaf_sun_opening_gain;
global uniform vec4 gaf_diffuse_opening;
global uniform vec4 gaf_shadow_diffuse_sun;
global uniform vec3 gaf_shadow_diffuse_tint;
global uniform vec2 gaf_ground_shadow_fill_reduction;
global uniform vec2 gaf_canopy_ground_fill;
global uniform vec4 gaf_grass_terrace_shadow_state;
global uniform sampler2D gaf_grass_terrace_shadow_field : filter_nearest, repeat_disable;
global uniform vec4 gaf_near_wall_fill;
global uniform sampler2D gaf_near_wall_field : filter_nearest, repeat_disable;
global uniform vec4 gaf_turf_sun_chroma;
global uniform vec4 gaf_projected_sun_contrast;

float gaf_projected_patch_scale(bool directional, vec3 view_light, mat4 inverse_view,
		float transmission, float visibility, float pivot) {
	if (!directional || gaf_projected_sun_contrast.w <= 0.0 || visibility <= .58 ||
			dot(mat3(inverse_view) * view_light, gaf_projected_sun_contrast.xyz) < .9999 ||
			distance(inverse_view[3].xyz, gaf_point_kernel_camera) > .005) {
		return 1.0;
	}
	// Keep both endpoints fixed and blend in through geometric penumbra.
	float t = clamp(transmission, 0.0, 1.0);
	float strength = gaf_projected_sun_contrast.w * smoothstep(.58, .84, visibility);
	float shoulder = min(t / pivot, (1.0 - t) / (1.0 - pivot));
	return 1.0 + strength * (t - pivot) * shoulder / max(t, .00001);
}

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


float gaf_terrace_shadow_fill(vec2 world_xz) {
	if (gaf_grass_terrace_shadow_state.z <= 0.0) return 1.0;
	ivec2 size = textureSize(gaf_grass_terrace_shadow_field, 0);
	ivec2 cell = ivec2(floor(world_xz - gaf_grass_terrace_shadow_state.xy));
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, size))) return 1.0;
	// Byte 128 encodes level terrain and remains exactly neutral.
	float relief = floor(255.0 * texelFetch(gaf_grass_terrace_shadow_field, cell, 0).r + .5) - 128.0;
	return clamp(1.0 + (1.5 / 127.0) * gaf_grass_terrace_shadow_state.z * relief, .13, 1.90);
}

float gaf_terrace_shadow_weight(float attenuation) {
	return 1.0 - smoothstep(.10, .58, attenuation);
}

float gaf_near_wall_strength(vec2 world_xz) {
	if (max(gaf_near_wall_fill.z, gaf_near_wall_fill.w) <= 0.0) return 0.0;
	ivec2 size = textureSize(gaf_near_wall_field, 0);
	ivec2 cell = ivec2(floor(world_xz - gaf_near_wall_fill.xy));
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, size))) return 0.0;
	return smoothstep(.015, .29, texelFetch(gaf_near_wall_field, cell, 0).r);
}

float gaf_near_wall_turf(vec2 world_xz, vec3 albedo) {
	float near_wall = gaf_near_wall_strength(world_xz);
	if (near_wall <= 0.0) return 0.0;
	float green = smoothstep(1.04, 1.20, albedo.g / max(albedo.r, .0001)) *
		smoothstep(1.12, 1.35, albedo.g / max(albedo.b, .0001));
	return near_wall * green;
}

float gaf_canopy_ground_ev(float visibility) {
	// Keep open ground at its original level and distinguish the edge from the dense interior.
	float core = 1.0 - smoothstep(.61, .87, visibility);
	float border = smoothstep(.84, .94, visibility) * (1.0 - smoothstep(.947, 1.0, visibility));
	return .60 * border - .82 * core;
}

vec2 gaf_canopy_ground_delta(float ev, float attenuation) {
	return exp2(gaf_canopy_ground_fill * (ev * gaf_terrace_shadow_weight(attenuation))) - vec2(1.0);
}

float gaf_ground_shadow_fill_multiplier(float reduction, float attenuation) {
	// Fade out the fill correction toward the bright side of the penumbra.
	return 1.0 - reduction * (1.0 - smoothstep(.02, .40, attenuation));
}
