#include "res://materials/world_map_far_terrain_shadow.gdshaderinc"
// Original Mobile response using existing GAF direct-light/cloud helpers.
#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_sun_opening.gdshaderinc"
#define GAF_WORLD_FOLIAGE_LOBE_ONLY
#include "res://materials/world_map_foliage_light.gdshaderinc"
uniform float study_grass_up_weight=0.0;
uniform float study_transmission=0.1248;
#ifdef GAF_FLOWER_DAYLIGHT_RESPONSE
uniform vec4 petal_sun = vec4(0.0);
uniform float petal_shadow_return = 0.0;
#endif
varying vec3 study_face;
varying float study_tip_weight;
varying float study_cloud;
varying vec3 grass_opening_incident;
// Keep both terrain responses in one interpolator on Mobile.
varying flat vec2 grass_terrain_responses;
varying flat float grass_canopy_ground_ev;
varying vec3 grass_canopy_incident;
float grass_fresnel(float x){float q=1.0-x;float q2=q*q;return q2*q2*q;}
void light(){
	float shadow_attenuation = GAF_RESOLVE_TERRAIN_SHADOW;
	float front=clamp(dot(NORMAL,LIGHT),0.0,1.0);
	float cloud=LIGHT_IS_DIRECTIONAL?study_cloud:1.0;
#ifdef GAF_FLOWER_DAYLIGHT_RESPONSE
	bool flower_key = LIGHT_IS_DIRECTIONAL && (petal_sun.w > 0.0 || petal_shadow_return > 0.0) &&
		dot(mat3(INV_VIEW_MATRIX) * LIGHT, petal_sun.xyz) > .9999;
	float head = flower_key ? smoothstep(.53, .82, study_tip_weight) : 0.0;
	if (petal_shadow_return > 0.0 && shadow_attenuation < .72 && head > 0.0) {
		// The local return tapers through the geometric penumbra and under the canopy.
		float shade = 1.0 - smoothstep(.12, .72, shadow_attenuation);
		float canopy = mix(.30, 1.0, study_canopy_sky_at_root);
		float incident = dot(LIGHT_COLOR, vec3(.2126, .7152, .0722)) / PI;
		vec3 bounced_tint = vec3(1.076, .990, .884);
		DIFFUSE_LIGHT += bounced_tint * (incident * canopy * mix(.48, 1.0, cloud) *
			shade * head * petal_shadow_return);
	}
#endif
	float ground_fill = 1.0;
	if (LIGHT_IS_DIRECTIONAL && gaf_ground_shadow_fill_reduction.x > 0.0) {
		ground_fill = gaf_ground_shadow_fill_multiplier(gaf_ground_shadow_fill_reduction.x, shadow_attenuation);
	}
	vec3 shade_fill = gaf_shadow_diffuse(LIGHT_IS_DIRECTIONAL, LIGHT, INV_VIEW_MATRIX,
		shadow_attenuation, cloud, sqrt(front), .82);
	if (gaf_grass_terrace_shadow_state.z > 0.0 && shade_fill.g > 0.0) {
		ground_fill *= mix(1.0, grass_terrain_responses.x, gaf_terrace_shadow_weight(shadow_attenuation));
	}
	vec2 canopy_delta = vec2(0.0);
	if (gaf_canopy_ground_fill.x > 0.0 && shade_fill.g > 0.0 &&
			grass_canopy_ground_ev != 0.0 && shadow_attenuation < .58) {
		canopy_delta = gaf_canopy_ground_delta(grass_canopy_ground_ev, shadow_attenuation);
	}
	DIFFUSE_LIGHT += shade_fill * (ground_fill * (1.0 + canopy_delta.y));
	DIFFUSE_LIGHT += grass_canopy_incident * canopy_delta.x;
	if (grass_terrain_responses.y > 0.0 && shade_fill.g > 0.0 && shadow_attenuation < .58) {
		float coverage = grass_terrain_responses.y * gaf_terrace_shadow_weight(shadow_attenuation);
		vec3 reduction = gaf_near_wall_fill.w * shade_fill * ground_fill + gaf_near_wall_fill.z * grass_canopy_incident;
		DIFFUSE_LIGHT -= reduction * coverage;
	}
	float opening_fill = gaf_diffuse_opening_weight(LIGHT_IS_DIRECTIONAL, LIGHT, LIGHT_COLOR, INV_VIEW_MATRIX, shadow_attenuation * cloud);
	if (opening_fill > 0.0) {
		DIFFUSE_LIGHT += grass_opening_incident * (0.65 * opening_fill);
	}
	// Preserve the fill above when the key cannot contribute to direct lighting.
	if (shadow_attenuation > 0.0 && cloud > 0.0) {
		float point_transfer = gaf_point_transfer(LIGHT_IS_DIRECTIONAL, LIGHT, SCREEN_UV, FRAGCOORD.z,
			INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, LIGHT_COLOR.b);
		vec3 response = vec3(front);
#ifndef GAF_GRASS_FORCE_LAMBERT
		bool burley = true;
#ifdef GAF_FLOWER_LANTERN_LAMBERT
		// White petals in the captured Forest follow the cosine response for the player lamp.
		burley = point_transfer >= 1.0 || !gaf_is_player_point(LIGHT_IS_DIRECTIONAL, LIGHT_COLOR.b);
#endif
		if (burley) {
			float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
			float lh = clamp(dot(LIGHT, normalize(LIGHT + VIEW)), 0.0, 1.0);
			float grazing = 2.0 * ROUGHNESS * lh * lh - 0.5;
			response *= (1.0 + grazing * grass_fresnel(nv)) * (1.0 + grazing * grass_fresnel(front));
		}
#endif
		if (LIGHT_IS_DIRECTIONAL) {
			response += world_foliage_lobe(study_face, LIGHT, VIEW, front, study_tip_weight, study_transmission);
		}
#ifdef GAF_FLOWER_DAYLIGHT_RESPONSE
		if (flower_key && petal_sun.w > 0.0) {
			vec3 world_light = mat3(INV_VIEW_MATRIX) * LIGHT;
			// Blend toward a wider diffuse response on the flower heads.
			float broad_diffuse = .65 * front + .35 * max(world_light.y, 0.0);
			response = mix(response, vec3(broad_diffuse), head * petal_sun.w);
		}
#endif
		float gain = gaf_opening_gain(LIGHT_IS_DIRECTIONAL, shadow_attenuation * cloud);
		vec3 diffuse_color = LIGHT_COLOR * gain;
		float turf_sun = gaf_turf_sun_weight(LIGHT_IS_DIRECTIONAL, LIGHT, INV_VIEW_MATRIX, shadow_attenuation * cloud);
		if (tinted_grass && turf_sun > 0.0) {
			diffuse_color *= gaf_diffuse_chroma_scale(ALBEDO, diffuse_color, vec3(1.25, 1.0, 1.40), turf_sun);
		}
		// The identity transfer is returned for non-lantern lights and other cameras.
		if (tinted_grass && gaf_lantern_grass_tone > 0.0 && point_transfer < 1.0 && gaf_is_player_point(LIGHT_IS_DIRECTIONAL, LIGHT_COLOR.b)) {
			diffuse_color *= gaf_diffuse_chroma_scale(ALBEDO, LIGHT_COLOR, vec3(1.247, 1.0, 1.078), gaf_lantern_grass_tone);
		}
		float patch_scale = gaf_projected_patch_scale(LIGHT_IS_DIRECTIONAL, LIGHT, INV_VIEW_MATRIX,
			cloud, shadow_attenuation, .58);
		DIFFUSE_LIGHT += response * diffuse_color * (shadow_attenuation * point_transfer * cloud * patch_scale / PI);
	}
}
