global uniform float gaf_portable_ledge_occlusion;

float portable_ledge_visibility(vec3 position, vec3 normal) {
	if (gaf_portable_ledge_occlusion <= 0.0 || !path_blending || ground_grade != 3 || abs(normal.y) >= .1) {
		return 1.0;
	}
	// The exposed side must have a tread at the foot of the riser.
	float height = position.y - surface_height_at(position.xz + normal.xz * .028);
	float falloff = smoothstep(-.025, .015, height) * (1.0 - smoothstep(.10, .41, height));
	// The material already has a short contact core. Feather the sky loss above it.
	float core = mix(.35, 1.0, smoothstep(.025, .12, height));
	return 1.0 - gaf_portable_ledge_occlusion * falloff * core;
}
