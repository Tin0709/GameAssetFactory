// Original WorldMap direct-light response. Godot still resolves ambient, fog and shadows.
varying float cloud_transmission;
#ifdef GAF_WORLD_OPAQUE_FOLIAGE
#define GAF_WORLD_FOLIAGE_LOBE_ONLY
#include "res://materials/world_map_foliage_light.gdshaderinc"
uniform float foliage_transmission = 0.185;
#endif

#ifdef GAF_WORLD_BURLEY
float world_cloud_fresnel(float cosine) {
	float complement = 1.0 - cosine;
	float square = complement * complement;
	return square * square * complement;
}
#endif

void light() {
#ifdef GAF_WORLD_GROUND_BOUNCE
	vec3 source_direction = normalize((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz);
	if (LIGHT_IS_DIRECTIONAL && dot(source_direction, ground_bounce_direction) > 0.9999) {
		// Source radiance was baked with unit white sun. Current light color,
		// energy and shared local cloud modulation apply exactly once here.
		DIFFUSE_LIGHT += LIGHT_COLOR * (ground_reflection * cloud_transmission / PI);
	}
#endif
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
#ifdef GAF_WORLD_OPAQUE_FOLIAGE
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 response = world_foliage_lobe(NORMAL, LIGHT, VIEW, nl, 1.0, foliage_transmission);
		DIFFUSE_LIGHT += response * LIGHT_COLOR * (ATTENUATION * cloud_transmission / PI);
	}
#endif
	if (nl > 0.0) {
		vec3 incident = LIGHT_COLOR * (ATTENUATION * nl / PI);
#ifdef GAF_WORLD_SPATIAL_TERRAIN
		incident*=terrain_direct_contact;
#endif
		if (LIGHT_IS_DIRECTIONAL) incident *= cloud_transmission;
#ifdef GAF_WORLD_BURLEY
		float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
#ifdef GAF_WORLD_TERRAIN_PBR
		if(terrain_pbr_enabled)nv=max(nv,0.0001);
#endif
		vec3 half_vector = normalize(LIGHT + VIEW);
		float lh = clamp(dot(LIGHT, half_vector), 0.0, 1.0);
		if (METALLIC < 1.0) {
#ifndef GAF_WORLD_FORCE_LAMBERT
			float grazing = 2.0 * ROUGHNESS * lh * lh - 0.5;
			DIFFUSE_LIGHT += incident * (1.0 + grazing * world_cloud_fresnel(nv))
				* (1.0 + grazing * world_cloud_fresnel(nl));
#else
			DIFFUSE_LIGHT += incident;
#endif
		}
		// Isotropic GGX for the current opaque actor and matte terrain.
		if (ROUGHNESS > 0.0) {
			float alpha = ROUGHNESS * ROUGHNESS;
			float nh = clamp(dot(NORMAL, half_vector), 0.0, 1.0);
			float alpha_nh = nh * alpha;
			float distribution = alpha / max(1.0 - nh * nh + alpha_nh * alpha_nh, 0.000001);
			float visibility = min(0.5 / max(mix(2.0 * nl * nv, nl + nv, alpha), 0.000001), 1.0);
#ifdef GAF_WORLD_TERRAIN_PBR
			if(terrain_pbr_enabled)visibility=0.5/max(mix(2.0*nl*nv,nl+nv,alpha),0.000001);
#endif
			vec3 f0 = mix(vec3(0.16 * native_specular * native_specular), ALBEDO, METALLIC);
			float f90 = clamp(16.5 * (f0.r + f0.g + f0.b), METALLIC, 1.0);
			vec3 fresnel = mix(f0, vec3(f90), world_cloud_fresnel(lh));
			float distribution_squared=min(distribution*distribution,PI);
#ifdef GAF_WORLD_TERRAIN_PBR
			if(terrain_pbr_enabled)distribution_squared=distribution*distribution;
#endif
			SPECULAR_LIGHT += incident * fresnel * (distribution_squared * visibility * SPECULAR_AMOUNT);
		}
#else
		DIFFUSE_LIGHT += incident;
#endif
	}
}
