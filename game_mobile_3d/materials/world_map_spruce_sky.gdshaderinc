global uniform vec4 gaf_spruce_sky_region;
global uniform vec3 gaf_spruce_sky_extent;
global uniform vec3 gaf_spruce_sky_camera;
global uniform sampler3D gaf_spruce_sky_volume : filter_linear, repeat_disable;

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
