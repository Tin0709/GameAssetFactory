// Original diffuse response to a map-authored opening.
global uniform vec4 gaf_local_diffuse_region;
global uniform vec4 gaf_local_diffuse_source;
global uniform vec4 gaf_local_diffuse_additional_region;
global uniform vec4 gaf_local_diffuse_additional_source;
global uniform vec3 gaf_local_diffuse_ambient;

float gaf_diffuse_region_gain(vec3 position, vec4 bounds, float strength) {
	if (strength <= 0.0) return 0.0;
	vec2 offset = (position.xz - bounds.xy) / bounds.zw;
	return strength * (1.0 - smoothstep(.06, 1.0, dot(offset, offset)));
}

vec3 gaf_diffuse_from_opening(vec3 diffuse, vec3 position, vec3 normal, vec3 opening, float gain) {
	vec3 to_opening = opening - position;
	float facing = dot(normal, to_opening) * inversesqrt(max(dot(to_opening, to_opening), 1.0));
	float openness = smoothstep(-.24, .85, facing);
	const vec3 luma = vec3(.2126, .7152, .0722);
	vec3 tint = diffuse * mix(vec3(.78, 1.0, 1.33), vec3(.97, 1.0, 1.12), openness);
	tint *= dot(diffuse, luma) / max(dot(tint, luma), .000001);
	return mix(diffuse, tint, gain * .80) * (1.0 + gain * mix(-.16, .62, openness));
}

vec3 gaf_local_diffuse(vec3 diffuse, vec3 position, vec3 normal) {
	float first = gaf_diffuse_region_gain(position, gaf_local_diffuse_region, gaf_local_diffuse_source.w);
	float second = gaf_diffuse_region_gain(position, gaf_local_diffuse_additional_region, gaf_local_diffuse_additional_source.w);
	if (first <= 0.0 && second <= 0.0) return diffuse;
	if (second <= 0.0) return gaf_diffuse_from_opening(diffuse, position, normal, gaf_local_diffuse_source.xyz, first);
	vec3 extra = gaf_diffuse_from_opening(diffuse, position, normal, gaf_local_diffuse_additional_source.xyz, second);
	if (first <= 0.0) return extra;
	// Blend competing opening estimates smoothly when map regions overlap.
	vec3 primary = gaf_diffuse_from_opening(diffuse, position, normal, gaf_local_diffuse_source.xyz, first);
	return mix(primary, extra, second / (first + second));
}

// Portable scenes keep Godot's ambient light and add the signed local change.
vec3 gaf_local_environment_delta(vec3 albedo, float metallic, vec3 position, vec3 normal) {
	if (gaf_local_diffuse_ambient == vec3(0.0)) return vec3(0.0);
	vec3 local = gaf_local_diffuse(gaf_local_diffuse_ambient, position, normal);
	return albedo * (1.0 - metallic) * (local - gaf_local_diffuse_ambient);
}
