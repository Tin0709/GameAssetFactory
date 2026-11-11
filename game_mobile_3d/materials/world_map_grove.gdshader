shader_type spatial;
#include "res://materials/world_map_wind.gdshaderinc"
#include "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/leaf_material_v001/leaf_material.gdshaderinc"
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

uniform bool reveal_player = false;
uniform float grove_mist_strength = 0.0;
uniform bool use_source_atlas = false;
uniform sampler2D source_atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D source_leaf_weights : filter_nearest, repeat_disable;
uniform float source_leaf_hue = 0.0;
uniform float source_leaf_tint_mix = 0.0;
instance uniform bool source_leaf_mask = false;
instance uniform int source_crown_mask_base = -1;
uniform sampler2D source_crown_weights : filter_nearest, repeat_disable;
uniform sampler2D source_crown_pattern : filter_linear, repeat_enable;
uniform vec2 source_crown_wind = vec2(0.0);
uniform bool crown_wind_enabled = false;
uniform float crown_wind_amplitude = 0.020;
uniform vec3 player_view;
uniform float native_specular = 0.24;
uniform bool crown_detail = false;
varying vec3 crown_local;
varying float source_leaf_red;

#ifdef GAF_WORLD_DIRECT_CLOUD
#include "res://materials/world_map_clouds.gdshaderinc"
varying vec2 grove_world_xz;
#endif

void vertex() {
	source_leaf_red = 0.0;
	if (source_leaf_mask && source_leaf_tint_mix > 0.0) {
		source_leaf_red = texelFetch(source_leaf_weights, ivec2(VERTEX_ID, 0), 0).r;
	}
	// Evaluate inside each face so its exact block boundary stays deterministic.
	crown_local = VERTEX - NORMAL * 0.004;
	if (use_source_atlas && source_crown_mask_base >= 0 && source_crown_wind.y > 0.0) {
		int index = source_crown_mask_base + VERTEX_ID;
		int width = textureSize(source_crown_weights, 0).x;
		float weight = texelFetch(source_crown_weights, ivec2(index % width, index / width), 0).r;
		if (weight > 0.0) {
			// Anchor wind to the world so gameplay and shadow cameras see one pose.
			vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
			vec3 drift = gaf_leaf_world_drift(source_crown_pattern, world_position,
				MODEL_MATRIX[3].y, source_crown_wind, weight);
			VERTEX += inverse(mat3(MODEL_MATRIX)) * drift;
		}
	} else if (crown_wind_enabled && !use_source_atlas) {
		// One rigid transform for the complete authored crown: voxel blocks
		// retain their shape. Bark stays fixed under the overlapping foliage.
		vec3 root = MODEL_MATRIX[3].xyz;
		vec2 breeze = world_breeze(root) * crown_wind_amplitude;
		mat3 orientation = mat3(normalize(MODEL_MATRIX[0].xyz), normalize(MODEL_MATRIX[1].xyz), normalize(MODEL_MATRIX[2].xyz));
		vec2 bend = (transpose(orientation) * vec3(breeze.x, 0.0, breeze.y)).xz;
		vec3 pivot = vec3(0.0, 2.0, 0.0);
		VERTEX = pivot + rotate_plant(VERTEX - pivot, bend);
		NORMAL = rotate_plant(NORMAL, bend);
	}
#ifdef GAF_WORLD_DIRECT_CLOUD
	grove_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
#endif
}

#if defined(GAF_WORLD_DIRECT_CLOUD) || defined(GAF_WORLD_FOLIAGE_LIGHT)
#define GAF_WORLD_BURLEY
#ifdef GAF_WORLD_FOLIAGE_LIGHT
#define GAF_WORLD_OPAQUE_FOLIAGE
#endif
#include "res://materials/world_map_direct_cloud.gdshaderinc"
#endif

float crown_hash(vec3 cell) {
	vec3 bits = fract(cell * vec3(0.1031, 0.11369, 0.13787));
	bits += dot(bits, bits.yzx + 19.19);
	return fract((bits.x + bits.y) * bits.z);
}

vec3 crown_color(vec3 color) {
	vec3 small_cell = floor(crown_local * vec3(8.0, 9.0, 8.0));
	vec3 cluster_cell = floor((crown_local + vec3(0.12, -0.06, 0.08)) * vec3(2.7, 3.8, 3.1));
	// Fade the small cells first when an overview or smaller render target
	// projects them below a pixel. Neutral input yields the original color.
	vec3 width = fwidth(crown_local);
	float footprint = max(width.x, max(width.y, width.z));
	float broad = mix(crown_hash(cluster_cell), 0.5, smoothstep(0.12, 0.32, footprint));
	float fine = mix(crown_hash(small_cell + vec3(7.0, 11.0, 3.0)), 0.5, smoothstep(0.04, 0.11, footprint));
	float cluster = mix(broad, fine, 0.34);
	float tips = smoothstep(0.55, 0.78, cluster);
	float shade = 1.0 - smoothstep(0.25, 0.47, cluster);
	return color * (1.0 + 0.36 * tips - 0.22 * shade) + tips * vec3(0.020, 0.024, 0.004);
}

void fragment() {
	vec3 albedo = crown_detail ? crown_color(COLOR.rgb) : COLOR.rgb;
	if (use_source_atlas) {
		vec4 texel = texture(source_atlas, UV);
		if (texel.a < 0.3333) discard;
		albedo = texel.rgb;
		if (source_leaf_red > 0.0) {
			albedo = gaf_leaf_color(albedo, source_leaf_hue, source_leaf_red * source_leaf_tint_mix);
		}
	}
	if (reveal_player) {
		// WorldMap uses an orthographic camera. Keep the opening centred on
		// the player even while the camera holds its elevation during a jump.
		vec3 offset = VERTEX - player_view;
		vec2 extent = abs(offset.xy) / vec2(0.70, 1.16);
		float distance_to_player = length(max(extent - 0.48, vec2(0.0)));
		if (offset.z > 0.01 && distance_to_player < 0.80) {
			float opacity = smoothstep(0.35, 0.80, distance_to_player);
			float threshold = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
			if (opacity <= threshold) discard;
		}
	}
	ALBEDO = albedo;
	ROUGHNESS = 0.95;
	SPECULAR = native_specular;
#ifdef GAF_SHARED_MIST
	vec4 mist = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
	FOG = vec4(mist.rgb, mist.a * grove_mist_strength);
#endif
#ifdef GAF_WORLD_DIRECT_CLOUD
	cloud_transmission = world_cloud_shade(vec3(grove_world_xz.x, 0.0, grove_world_xz.y));
#elif defined(GAF_WORLD_FOLIAGE_LIGHT)
	cloud_transmission = 1.0;
#endif
}
