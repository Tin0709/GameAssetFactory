global uniform vec4 gaf_spruce_sky_region;
global uniform vec3 gaf_spruce_sky_extent;
global uniform vec3 gaf_spruce_sky_camera;
global uniform sampler3D gaf_spruce_sky_volume : filter_linear, repeat_disable;
global uniform float gaf_canopy_edge_fill;
global uniform float gaf_canopy_sky_color;
global uniform float gaf_pre_twilight_receiver;

float gaf_spruce_sky(vec3 point, vec3 camera_position) {
	if (gaf_spruce_sky_region.w <= 0.0 || distance(camera_position, gaf_spruce_sky_camera) > 0.01) {
		return 1.0;
	}
	vec3 cell = point - gaf_spruce_sky_region.xyz;
	cell.y = max(cell.y, 0.0);
	if (any(lessThan(cell, vec3(0.0))) || any(greaterThan(cell, gaf_spruce_sky_extent - 1.0))) {
		return 1.0;
	}
	float occlusion = textureLod(gaf_spruce_sky_volume, (cell + 0.5) / gaf_spruce_sky_extent, 0.0).r;
	return 1.0 - gaf_spruce_sky_region.w * occlusion;
}

float gaf_ground_canopy_sky(float current) {
	if (gaf_canopy_edge_fill <= 0.0 || current >= 1.0) {
		return current;
	}
	// Restore some sky at the edge of the canopy. Keep the dense core dark.
	float cover = clamp((1.0 - current) / gaf_spruce_sky_region.w, 0.0, 1.0);
	return mix(current, 1.0, gaf_canopy_edge_fill * (1.0 - smoothstep(0.18, 0.60, cover)));
}

vec3 gaf_pre_twilight_diffuse(vec3 rgb, vec3 camera_position) {
	if (gaf_pre_twilight_receiver <= 0.0 || distance(camera_position, gaf_spruce_sky_camera) > .01) return rgb;
	const vec3 luma = vec3(.2126, .7152, .0722);
	// Original chroma adjustment at fixed incident luminance.
	vec3 target = rgb * vec3(1.15, 1.0, 1.20);
	target *= dot(rgb, luma) / max(dot(target, luma), .000001);
	return mix(rgb, target, gaf_pre_twilight_receiver);
}

vec3 gaf_canopy_diffuse_color(vec3 rgb, float visibility, float gain) {
	float weight = gain * (1.0 - smoothstep(.72, .96, visibility));
	if (weight <= 0.0) return rgb;
	const vec3 luma = vec3(.2126, .7152, .0722);
	vec3 cool = rgb * vec3(.72, 1.0, 1.48);
	cool *= dot(rgb, luma) / max(dot(cool, luma), .000001);
	return mix(rgb, cool, weight);
}
