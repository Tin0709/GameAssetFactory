// Original two-layer response. Inputs are linear red-channel coverage.
float gaf_cloud_response(float broad, float detail, float strength) {
	float cover = min(smoothstep(0.2, 0.6, broad) + 0.5 * smoothstep(0.0, 0.8, detail), 1.0);
	float direct = 0.9999 * mix(0.2, 1.0, cover);
	return mix(1.0, direct, strength);
}
