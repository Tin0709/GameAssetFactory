// Original WorldMap direct-light response. Godot still resolves ambient, fog and shadows.
varying float cloud_transmission;

#ifdef GAF_WORLD_BURLEY
float world_cloud_fresnel(float cosine) {
	float complement = 1.0 - cosine;
	float square = complement * complement;
	return square * square * complement;
}
#endif

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (nl > 0.0) {
		vec3 incident = LIGHT_COLOR * (ATTENUATION * nl / PI);
		if (LIGHT_IS_DIRECTIONAL) incident *= cloud_transmission;
#ifdef GAF_WORLD_BURLEY
		float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		vec3 half_vector = normalize(LIGHT + VIEW);
		float lh = clamp(dot(LIGHT, half_vector), 0.0, 1.0);
		float grazing = 2.0 * ROUGHNESS * lh * lh - 0.5;
		if (METALLIC < 1.0) {
			DIFFUSE_LIGHT += incident * (1.0 + grazing * world_cloud_fresnel(nv))
				* (1.0 + grazing * world_cloud_fresnel(nl));
		}
		// Isotropic GGX for the current opaque actor and matte terrain.
		if (ROUGHNESS > 0.0) {
			float alpha = ROUGHNESS * ROUGHNESS;
			float nh = clamp(dot(NORMAL, half_vector), 0.0, 1.0);
			float alpha_nh = nh * alpha;
			float distribution = alpha / max(1.0 - nh * nh + alpha_nh * alpha_nh, 0.000001);
			float visibility = min(0.5 / max(mix(2.0 * nl * nv, nl + nv, alpha), 0.000001), 1.0);
			vec3 f0 = mix(vec3(0.16 * native_specular * native_specular), ALBEDO, METALLIC);
			float f90 = clamp(16.5 * (f0.r + f0.g + f0.b), METALLIC, 1.0);
			vec3 fresnel = mix(f0, vec3(f90), world_cloud_fresnel(lh));
			SPECULAR_LIGHT += incident * fresnel * (min(distribution * distribution, PI) * visibility * SPECULAR_AMOUNT);
		}
#else
		DIFFUSE_LIGHT += incident;
#endif
	}
}
