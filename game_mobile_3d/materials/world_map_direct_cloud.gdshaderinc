#include "res://materials/world_map_point_kernel.gdshaderinc"
#include "res://materials/world_map_sun_opening.gdshaderinc"
// Original WorldMap direct-light response. Godot still resolves ambient, fog and shadows.
varying float cloud_transmission;
#ifdef GAF_WORLD_CANOPY_DIRECT_SOFTNESS
uniform vec4 canopy_direct = vec4(0.0);
varying float canopy_direct_coverage;
#endif
#ifdef GAF_WORLD_SPATIAL_TERRAIN
global uniform float gaf_stone_shade_reach;
global uniform vec4 gaf_stone_sunset_region;
global uniform vec4 gaf_stone_sunset_beam;
varying vec2 stone_sunset_position;
#endif
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
	float point_transfer=gaf_point_transfer(LIGHT_IS_DIRECTIONAL,LIGHT,SCREEN_UV,FRAGCOORD.z,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX,LIGHT_COLOR.b);
	float point_attenuation=ATTENUATION*point_transfer;
	vec3 key_color = LIGHT_COLOR * gaf_opening_gain(LIGHT_IS_DIRECTIONAL, ATTENUATION * cloud_transmission);
#ifdef GAF_WORLD_CANOPY_DIRECT_SOFTNESS
	if (LIGHT_IS_DIRECTIONAL && canopy_direct_coverage > 0.0 &&
			dot(mat3(INV_VIEW_MATRIX) * LIGHT, canopy_direct.xyz) > 0.9999) {
		key_color *= 1.0 - canopy_direct.w * canopy_direct_coverage;
	}
#endif
#ifdef GAF_WORLD_GROUND_BOUNCE
	vec3 source_direction = normalize((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz);
	if (LIGHT_IS_DIRECTIONAL && dot(source_direction, ground_bounce_direction) > 0.9999) {
		// Source radiance was baked with unit white sun. Current light color,
		// energy and shared local cloud modulation apply exactly once here.
		DIFFUSE_LIGHT += LIGHT_COLOR * (ground_reflection * cloud_transmission / PI);
	}
#endif
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
#ifdef GAF_WORLD_SPATIAL_TERRAIN
	if (ground_grade == 3 && LIGHT_IS_DIRECTIONAL && gaf_stone_sunset_beam.w > 0.0
			&& dot(mat3(INV_VIEW_MATRIX) * LIGHT, gaf_stone_sunset_beam.xyz) > 0.9999
			&& distance(INV_VIEW_MATRIX[3].xyz, gaf_point_kernel_camera) <= 0.005) {
		vec2 offset = (stone_sunset_position - gaf_stone_sunset_region.xy) / gaf_stone_sunset_region.zw;
		float region = 1.0 - smoothstep(0.08, 1.0, dot(offset, offset));
		float direct = smoothstep(0.16, 0.80, ATTENUATION) * smoothstep(0.09, 0.45, nl);
		key_color *= 1.0 - gaf_stone_sunset_beam.w * region * direct;
	}
	if (ground_grade == 3 && LIGHT_IS_DIRECTIONAL && gaf_stone_shade_fill.w > 0.0 &&
		max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b)) > 0.0 &&
		dot(mat3(INV_VIEW_MATRIX) * LIGHT, gaf_stone_shade_fill.xyz) > 0.9999 &&
		distance(INV_VIEW_MATRIX[3].xyz, gaf_point_kernel_camera) <= 0.005) {
		// Use the receiver's existing sky and contact terms on sun-facing rock in shadow.
		float shade = 1.0 - smoothstep(.04, .68, ATTENUATION);
		float facing = smoothstep(.03, .38, nl);
		if (gaf_stone_shade_reach > 0.0) {
			// Indirect fill can reach a face even when it points away from the sun.
			float open_sky = smoothstep(.45, .97, terrain_canopy_sky);
			facing = mix(facing, max(facing, .48 + .22 * open_sky), gaf_stone_shade_reach);
		}
		vec3 sky = terrain_opening_incident;
		vec3 fill = mix(sky, vec3(dot(sky, vec3(.2126, .7152, .0722))), .40);
		DIFFUSE_LIGHT += fill * (facing * shade * gaf_stone_shade_fill.w);
	}
	float opening_fill = gaf_diffuse_opening_weight(LIGHT_IS_DIRECTIONAL, LIGHT, LIGHT_COLOR, INV_VIEW_MATRIX, ATTENUATION * cloud_transmission);
	if (opening_fill > 0.0) {
		DIFFUSE_LIGHT += terrain_opening_incident * (opening_fill * smoothstep(0.0, 0.22, nl));
	}
#endif
#ifdef GAF_WORLD_OPAQUE_FOLIAGE
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 response = world_foliage_lobe(NORMAL, LIGHT, VIEW, nl, 1.0, foliage_transmission);
		DIFFUSE_LIGHT += response * key_color * (point_attenuation * cloud_transmission / PI);
	}
#endif
	if (nl > 0.0) {
		vec3 incident = key_color * (point_attenuation * nl / PI);
#ifdef GAF_WORLD_SPATIAL_TERRAIN
		incident*=terrain_direct_contact;
#endif
		if (LIGHT_IS_DIRECTIONAL) incident *= cloud_transmission;
		vec3 diffuse_incident = incident;
#if defined(GAF_WORLD_SPATIAL_TERRAIN) || defined(GAF_WORLD_FLAT_TURF)
		if (gaf_lantern_grass_tone > 0.0 && point_transfer < 1.0 && surface_top > 0.998 && ground_grade == 1
			&& gaf_is_player_point(LIGHT_IS_DIRECTIONAL,LIGHT_COLOR.b)) {
			// Only the green side of the grass/soil blend receives the turf correction.
			float turf = min(smoothstep(1.04,1.10,ALBEDO.g/max(ALBEDO.r,0.0001)),
				smoothstep(1.1,1.2,ALBEDO.g/max(ALBEDO.b,0.0001)));
			if (turf > 0.0) diffuse_incident *= gaf_lantern_diffuse_tint(ALBEDO,LIGHT_COLOR,
				vec3(1.489,1.0,1.479),turf*gaf_lantern_grass_tone);
		}
#endif
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
			DIFFUSE_LIGHT += diffuse_incident * (1.0 + grazing * world_cloud_fresnel(nv))
				* (1.0 + grazing * world_cloud_fresnel(nl));
#else
			DIFFUSE_LIGHT += diffuse_incident;
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
#ifdef GAF_WORLD_TERRAIN_PBR
			// Explicit source-motivated fit for canonical matte GAF blocks. The
			// authored material and its parameters are retained for comparison.
			if(terrain_dielectric_response && native_specular<=0.)f0=mix(vec3(.04),ALBEDO,METALLIC);
#endif
			float f90 = clamp(16.5 * (f0.r + f0.g + f0.b), METALLIC, 1.0);
			vec3 fresnel = mix(f0, vec3(f90), world_cloud_fresnel(lh));
			float distribution_squared=min(distribution*distribution,PI);
#ifdef GAF_WORLD_TERRAIN_PBR
			if(terrain_pbr_enabled)distribution_squared=distribution*distribution;
#endif
			SPECULAR_LIGHT += incident * fresnel * (distribution_squared * visibility * SPECULAR_AMOUNT);
		}
#else
		DIFFUSE_LIGHT += diffuse_incident;
#endif
	}
}
