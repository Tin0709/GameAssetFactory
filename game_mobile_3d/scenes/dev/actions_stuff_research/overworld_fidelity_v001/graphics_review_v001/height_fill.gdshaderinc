// Original flat-map approximation, not a recovered GI or occlusion algorithm.
// RGB stores ground irradiance; A stores the highest nearby occluder top in m.
// One height layer cannot describe caves or stacked canopies.
vec3 gaf_resolve_fill(vec4 field, float surface_height, vec3 open_fill,
		float fade_height, bool enabled) {
	if (!enabled) { return field.rgb; }
	if (field.a < 0.0) { return open_fill; }
	float exposed = smoothstep(field.a - max(fade_height, 0.0001), field.a, surface_height);
	return mix(field.rgb, open_fill, exposed);
}
