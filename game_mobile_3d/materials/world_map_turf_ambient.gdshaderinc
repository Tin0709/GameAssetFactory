// WorldMap calibration of the sky fill on evening turf. The neutral setting is identity.
uniform vec3 turf_ambient_color = vec3(1.0);

vec3 gaf_turf_ambient(vec3 rgb) {
	const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
	vec3 tinted = rgb * vec3(turf_ambient_color.x, 1.0, turf_ambient_color.y);
	return tinted * (dot(rgb, luma) / max(dot(tinted, luma), 0.000001)) * turf_ambient_color.z;
}
