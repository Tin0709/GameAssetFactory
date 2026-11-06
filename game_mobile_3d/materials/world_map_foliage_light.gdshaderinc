// Bounded direct transmission for WorldMap's authored foliage.
uniform float foliage_transmission : hint_range(0.0, 0.5) = 0.0;
varying vec3 foliage_face;
varying float foliage_weight;
#ifdef GAF_WORLD_DIRECT_CLOUD
varying float cloud_transmission;
#endif

void light() {
	float front = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	vec3 irradiance = LIGHT_COLOR * (ATTENUATION / PI);
	vec3 response = vec3(front);
	if (LIGHT_IS_DIRECTIONAL) {
#ifdef GAF_WORLD_DIRECT_CLOUD
		irradiance *= cloud_transmission;
#endif
		// Foliage face comes from the view-facing normal before artistic smoothing.
		float back = max(-dot(foliage_face, LIGHT), 0.0);
		float through_view = max(-dot(VIEW, LIGHT), 0.0);
		float scatter = back * (0.55 + 0.45 * through_view * through_view);
		response += vec3(1.0, 0.91, 0.64) * min(1.0 - front, scatter * foliage_weight * foliage_transmission);
	}
	DIFFUSE_LIGHT += irradiance * response;
}
