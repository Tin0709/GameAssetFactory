// Independently authored material operations. All palettes and sampled inputs
// are provided by the caller; no reference image, bytecode or asset is embedded.
float vegetation_tip_weight(float v, float offset, float exponent) {
	return 1.0 - clamp(pow(max(v + offset, 0.0), exponent), 0.0, 1.0);
}
float vegetation_ease(float x) {
	return x * x * (3.0 - 2.0 * x);
}
vec3 vegetation_blade_color(vec3 root, vec3 tip, float v, float offset,
		float exponent, float gray) {
	return mix(root, tip, vegetation_tip_weight(v, offset, exponent)) * gray;
}
vec3 vegetation_gust_color(vec3 blade, vec3 gust, float v, float offset,
		float exponent, float coarse, float fine) {
	float detail = vegetation_ease(clamp((fine - 0.1) / 0.9, 0.0, 1.0));
	float spatial = vegetation_ease(clamp((coarse + 0.2 + 0.2 * detail) / 1.4, 0.0, 1.0));
	float weight = 0.75 * spatial * vegetation_tip_weight(v, offset, exponent);
	return clamp(mix(blade, gust, weight), vec3(0.0), vec3(1.0));
}
vec3 vegetation_scattering(vec3 blade, float strength) {
	// Scattering is based on the blade BEFORE the gust/ground color adapters.
	return clamp(blade * strength, vec3(0.0), vec3(1.0));
}
