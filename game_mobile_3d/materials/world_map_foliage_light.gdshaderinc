#include "res://materials/world_map_point_kernel.gdshaderinc"
// Bounded direct transmission for WorldMap's authored foliage.
vec3 world_foliage_lobe(vec3 face, vec3 light_dir, vec3 view_dir, float front, float weight, float strength) {
	float back = max(-dot(face, light_dir), 0.0);
	float through_view = max(-dot(view_dir, light_dir), 0.0);
	float scatter = back * (0.55 + 0.45 * through_view * through_view);
	return vec3(1.0, 0.91, 0.64) * min(1.0 - front, scatter * weight * strength);
}

#ifndef GAF_WORLD_FOLIAGE_LOBE_ONLY
uniform float foliage_transmission : hint_range(0.0, 0.5) = 0.0;
varying vec3 foliage_face;
varying float foliage_weight;
#ifdef GAF_WORLD_DIRECT_CLOUD
varying float cloud_transmission;
#endif

void light() {
	float point_attenuation=ATTENUATION*gaf_point_transfer(LIGHT_IS_DIRECTIONAL,LIGHT,SCREEN_UV,FRAGCOORD.z,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
	float front = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	vec3 irradiance = LIGHT_COLOR * (point_attenuation / PI);
	vec3 response = vec3(front);
	if (LIGHT_IS_DIRECTIONAL) {
#ifdef GAF_WORLD_DIRECT_CLOUD
		irradiance *= cloud_transmission;
#endif
		// Foliage face comes from the view-facing normal before artistic smoothing.
		response += world_foliage_lobe(foliage_face, LIGHT, VIEW, front, foliage_weight, foliage_transmission);
	}
	DIFFUSE_LIGHT += irradiance * response;
}
#endif
