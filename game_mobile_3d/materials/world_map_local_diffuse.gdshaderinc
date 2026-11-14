// Original diffuse response to a map-authored opening.
global uniform vec4 gaf_local_diffuse_region;
global uniform vec4 gaf_local_diffuse_source;
global uniform vec3 gaf_local_diffuse_ambient;

vec3 gaf_local_diffuse(vec3 diffuse, vec3 position, vec3 normal) {
	if (gaf_local_diffuse_source.w <= 0.0) return diffuse;
	vec2 offset = (position.xz - gaf_local_diffuse_region.xy) / gaf_local_diffuse_region.zw;
	float envelope = 1.0 - smoothstep(.06, 1.0, dot(offset, offset));
	if (envelope <= 0.0) return diffuse;

	vec3 to_opening = gaf_local_diffuse_source.xyz - position;
	float facing = dot(normal, to_opening) * inversesqrt(max(dot(to_opening, to_opening), 1.0));
	float openness = smoothstep(-.24, .85, facing);
	const vec3 luma = vec3(.2126, .7152, .0722);
	vec3 tint = diffuse * mix(vec3(.78, 1.0, 1.33), vec3(.97, 1.0, 1.12), openness);
	tint *= dot(diffuse, luma) / max(dot(tint, luma), .000001);
	float gain = gaf_local_diffuse_source.w * envelope;
	return mix(diffuse, tint, gain * .80) * (1.0 + gain * mix(-.16, .62, openness));
}

// Portable scenes keep Godot's ambient light and add the signed local change.
vec3 gaf_local_environment_delta(vec3 albedo, float metallic, vec3 position, vec3 normal) {
	if (gaf_local_diffuse_source.w <= 0.0 || gaf_local_diffuse_ambient == vec3(0.0)) return vec3(0.0);
	vec3 local = gaf_local_diffuse(gaf_local_diffuse_ambient, position, normal);
	return albedo * (1.0 - metallic) * (local - gaf_local_diffuse_ambient);
}
