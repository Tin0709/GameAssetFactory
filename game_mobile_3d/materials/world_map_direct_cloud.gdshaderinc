#include "res://materials/world_map_far_terrain_shadow.gdshaderinc"
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
global uniform float gaf_stone_wall_return;
global uniform vec4 gaf_stone_sunset_region;
global uniform vec4 gaf_stone_sunset_beam;
global uniform vec4 gaf_stone_sun_warmth;
global uniform float gaf_stone_warmth_luma_trim;
global uniform vec2 gaf_path_sun_response;
global uniform vec2 gaf_path_sun_core;
global uniform vec3 gaf_path_sun_core_direction;
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
	float shadow_attenuation = GAF_RESOLVE_TERRAIN_SHADOW;
	float point_transfer=gaf_point_transfer(LIGHT_IS_DIRECTIONAL,LIGHT,SCREEN_UV,FRAGCOORD.z,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX,LIGHT_COLOR.b);
	float point_attenuation=shadow_attenuation*point_transfer;
	vec3 key_color = LIGHT_COLOR * gaf_opening_gain(LIGHT_IS_DIRECTIONAL, shadow_attenuation * cloud_transmission);
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
	float ground_fill = 1.0;
	if (LIGHT_IS_DIRECTIONAL && surface_top > .998
			&& max(gaf_ground_shadow_fill_reduction.x, gaf_ground_shadow_fill_reduction.y) > 0.0) {
		if (ground_grade == 3) {
			ground_fill = gaf_ground_shadow_fill_multiplier(gaf_ground_shadow_fill_reduction.y, shadow_attenuation);
		} else if ((ground_grade == 1 || ground_grade == 2)
				&& ALBEDO.g > ALBEDO.r * 1.22 && ALBEDO.g > ALBEDO.b * 1.35) {
			ground_fill = gaf_ground_shadow_fill_multiplier(gaf_ground_shadow_fill_reduction.x, shadow_attenuation);
		}
	}
	float path_weight = 0.0;
	float path_core_weight = 0.0;
	if (LIGHT_IS_DIRECTIONAL && ground_grade == 2 && surface_top > .998 && use_source_terrain
			&& dot(gaf_path_sun_response + gaf_path_sun_core, vec2(1.0)) > 0.0
			&& distance(INV_VIEW_MATRIX[3].xyz, gaf_point_kernel_camera) <= .005) {
		// Match the dirt part of the blended shoulder and keep the neighboring grass.
		float dirt = smoothstep(1.02, 1.22, ALBEDO.r / max(ALBEDO.g, .0001));
		vec3 world_key = mat3(INV_VIEW_MATRIX) * LIGHT;
		if (dot(world_key, gaf_shadow_diffuse_sun.xyz) > .9999) {
			path_weight = dirt;
			ground_fill *= gaf_ground_shadow_fill_multiplier(path_weight * gaf_path_sun_response.x, shadow_attenuation);
		}
		if (dot(world_key, gaf_path_sun_core_direction) > .9999) {
			path_core_weight = dirt;
		}
	}
	vec3 shadow_diffuse = gaf_shadow_diffuse(LIGHT_IS_DIRECTIONAL, LIGHT, INV_VIEW_MATRIX,
		shadow_attenuation, cloud_transmission, nl, terrain_direct_contact);
	if (terrain_stone_foot > 0.0 && shadow_diffuse.g > 0.0) {
		float shade = 1.0 - smoothstep(.03, .30, shadow_attenuation * nl);
		shadow_diffuse *= 1.0 - gaf_stone_foot_fill * terrain_stone_foot * shade;
	}
	DIFFUSE_LIGHT += shadow_diffuse * ground_fill;
	// The same directional light and shadow term shape both the original key and the warmth.
	if (ground_grade == 3 && LIGHT_IS_DIRECTIONAL && gaf_stone_sun_warmth.w > 0.0
			&& dot(mat3(INV_VIEW_MATRIX) * LIGHT, gaf_stone_sun_warmth.xyz) > 0.9999
			&& distance(INV_VIEW_MATRIX[3].xyz, gaf_point_kernel_camera) <= 0.005) {
		float open_sun = smoothstep(.38, .91, shadow_attenuation * cloud_transmission);
		float facing = smoothstep(.08, .43, nl);
		vec3 warm_key = key_color * (1.0 + gaf_stone_sun_warmth.w * open_sun * facing * vec3(1.15, .72, .08));
		if (gaf_stone_warmth_luma_trim > 0.0) {
			const vec3 luma = vec3(.2126, .7152, .0722);
			float relative_luma = dot(key_color, luma) / max(dot(warm_key, luma), 0.00001);
			warm_key *= mix(1.0, relative_luma, gaf_stone_warmth_luma_trim);
		}
		key_color = warm_key;
	}
	if (ground_grade == 3 && LIGHT_IS_DIRECTIONAL && gaf_stone_sunset_beam.w > 0.0
			&& dot(mat3(INV_VIEW_MATRIX) * LIGHT, gaf_stone_sunset_beam.xyz) > 0.9999
			&& distance(INV_VIEW_MATRIX[3].xyz, gaf_point_kernel_camera) <= 0.005) {
		vec2 offset = (stone_sunset_position - gaf_stone_sunset_region.xy) / gaf_stone_sunset_region.zw;
		float region = 1.0 - smoothstep(0.08, 1.0, dot(offset, offset));
		float direct = smoothstep(0.16, 0.80, shadow_attenuation) * smoothstep(0.09, 0.45, nl);
		key_color *= 1.0 - gaf_stone_sunset_beam.w * region * direct;
	}
	if (ground_grade == 3 && LIGHT_IS_DIRECTIONAL &&
		max(gaf_stone_shade_fill.w, max(gaf_stone_wall_return, gaf_sheltered_stone_return)) > 0.0 &&
		max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b)) > 0.0 &&
		dot(mat3(INV_VIEW_MATRIX) * LIGHT, gaf_stone_shade_fill.xyz) > 0.9999 &&
		distance(INV_VIEW_MATRIX[3].xyz, gaf_point_kernel_camera) <= 0.005) {
		float shade = 1.0 - smoothstep(.04, .68, shadow_attenuation);
		if (gaf_stone_shade_fill.w > 0.0) {
			// Use the receiver's existing sky and contact terms on sun-facing rock in shadow.
			float facing = smoothstep(.03, .38, nl);
			if (gaf_stone_shade_reach > 0.0) {
				// Indirect fill can reach a face even when it points away from the sun.
				float open_sky = smoothstep(.45, .97, terrain_canopy_sky);
				facing = mix(facing, max(facing, .48 + .22 * open_sky), gaf_stone_shade_reach);
			}
			vec3 sky = terrain_opening_incident;
			vec3 fill = mix(sky, vec3(dot(sky, vec3(.2126, .7152, .0722))), .40);
			DIFFUSE_LIGHT += fill * (facing * shade * gaf_stone_shade_fill.w * ground_fill);
		}
#ifdef GAF_TERRAIN_NIGHT_SKY
		if (max(gaf_stone_wall_return, gaf_sheltered_stone_return) > 0.0 && shade > 0.0) {
			// Use the map's directional diffuse cache while protecting flat tops and direct light.
			const vec3 luma = vec3(.2126, .7152, .0722);
			float wall = 1.0 - smoothstep(.06, .25, abs((mat3(INV_VIEW_MATRIX) * NORMAL).y));
			vec3 source = terrain_day_bounce * cloud_transmission;
			float source_y = dot(source, luma);
			if (gaf_stone_wall_return > 0.0) {
				vec3 returned = mix(source, vec3(source_y), .30);
				DIFFUSE_LIGHT += returned * terrain_direct_contact * (wall * shade * gaf_stone_wall_return);
			}
			if (gaf_sheltered_stone_return > 0.0 && wall > 0.0 && shadow_attenuation < .36) {
				// Fill the part of the shaded receiver's sky contribution that lacks a
				// directional return. Preserve contrast where the baked return is already strong.
				vec3 sky = terrain_opening_incident;
				float sky_y = dot(sky, luma);
				float existing_return = source_y * (1.0 + gaf_stone_wall_return * shade);
				float gap = max(.72 * sky_y - existing_return, 0.0);
				vec3 tint = mix(vec3(1.0), sky / max(sky_y, .00001), .45);
				float inner_shade = 1.0 - smoothstep(.035, .36, shadow_attenuation);
				float recovery = min(gap * gaf_sheltered_stone_return, .085);
				DIFFUSE_LIGHT += tint * (recovery * wall * inner_shade * terrain_direct_contact);
			}
		}
#endif
	}
	float opening_fill = gaf_diffuse_opening_weight(LIGHT_IS_DIRECTIONAL, LIGHT, LIGHT_COLOR, INV_VIEW_MATRIX, shadow_attenuation * cloud_transmission);
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
#ifdef GAF_WORLD_TREE_IRRADIANCE
		if (twilight_leaf_lamp_shoulder > 0.0 && crown_local_lamp_receiver > 0.5
				&& point_transfer < 1.0 && gaf_is_player_point(LIGHT_IS_DIRECTIONAL, LIGHT_COLOR.b)) {
			// This is a response of the leaf to the verified hip light.
			float reflected = dot(incident * ALBEDO, vec3(.2126, .7152, .0722));
			incident *= 1.0 - twilight_leaf_lamp_shoulder * smoothstep(.002, .025, reflected);
		}
#endif
		vec3 diffuse_incident = incident;
#ifdef GAF_WORLD_SPATIAL_TERRAIN
		if (max(path_weight, path_core_weight) > 0.0) {
			float beam = shadow_attenuation * cloud_transmission;
			if (path_weight > 0.0) {
				// Redistribute the existing Sun response in the midrange.
				float edge = smoothstep(.12, .47, beam) * (1.0 - smoothstep(.62, .93, beam));
				diffuse_incident *= 1.0 + gaf_path_sun_response.y * (path_weight * edge);
			}
			if (path_core_weight > 0.0 && beam > .46) {
				// The warm key requires both an opening in the shadow and projected transmission.
				float core = path_core_weight * smoothstep(.46, .90, beam);
				vec3 warmth = gaf_diffuse_chroma_scale(ALBEDO, incident, vec3(1.38, 1.04, .72), gaf_path_sun_core.y * core);
				diffuse_incident *= warmth * (1.0 + gaf_path_sun_core.x * core);
			}
		}
#endif
#if defined(GAF_WORLD_SPATIAL_TERRAIN) || defined(GAF_WORLD_FLAT_TURF)
		if (gaf_turf_sun_chroma.w > 0.0 && use_source_terrain && surface_top > 0.998 &&
				(ground_grade == 1 || ground_grade == 2) &&
				ALBEDO.g > ALBEDO.r * 1.22 && ALBEDO.g > ALBEDO.b * 1.35) {
			float tint = gaf_turf_sun_weight(LIGHT_IS_DIRECTIONAL, LIGHT, INV_VIEW_MATRIX, shadow_attenuation * cloud_transmission);
			if (tint > 0.0) diffuse_incident *= gaf_diffuse_chroma_scale(ALBEDO, incident, vec3(1.67, 1.0, 1.75), tint);
		}
		if (gaf_lantern_grass_tone > 0.0 && point_transfer < 1.0 && surface_top > 0.998 && ground_grade == 1
			&& gaf_is_player_point(LIGHT_IS_DIRECTIONAL,LIGHT_COLOR.b)) {
			// Only the green side of the grass/soil blend receives the turf correction.
			float turf = min(smoothstep(1.04,1.10,ALBEDO.g/max(ALBEDO.r,0.0001)),
				smoothstep(1.1,1.2,ALBEDO.g/max(ALBEDO.b,0.0001)));
			if (turf > 0.0) diffuse_incident *= gaf_diffuse_chroma_scale(ALBEDO,LIGHT_COLOR,
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
