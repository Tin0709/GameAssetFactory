shader_type spatial;
#ifdef GAF_GROVE_REVEAL_COVERAGE
render_mode alpha_to_coverage_and_one;
uniform bool spruce_gap_coverage = false;
uniform float spruce_gap_coverage_weight = 1.0;
uniform sampler2D spruce_leaf_gap_mask : filter_nearest, repeat_disable;
#endif
#ifdef GAF_GROVE_PLAYER_CUE
stencil_mode write, compare_always, 122;
uniform float player_cue_weight = 0.0;
#endif
#include "res://materials/world_map_wind.gdshaderinc"
#include "res://materials/world_map_crown_wind.gdshaderinc"
#ifdef GAF_WORLD_TREE_SKY
#include "res://materials/world_map_spruce_sky.gdshaderinc"
global uniform float gaf_grove_sky_strength;
varying float tree_sky;
uniform float crown_dusk_occlusion = 0.0;
uniform float crown_ambient_depth = 0.0;
#endif
#ifdef GAF_WORLD_TREE_IRRADIANCE
uniform vec4 bark_irradiance = vec4(0.0);
uniform vec3 bark_irradiance_tint = vec3(1.0);
uniform vec3 bark_diffuse_return = vec3(0.0);
uniform float twilight_leaf_lamp_shoulder = 0.0;
varying float crown_local_lamp_receiver;
#endif
#include "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/leaf_material_v001/leaf_material.gdshaderinc"
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

uniform bool reveal_player = false;
uniform float grove_mist_strength = 0.0;
uniform bool use_source_atlas = false;
uniform sampler2D source_atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D spruce_leaf_mips : source_color, filter_linear_mipmap, repeat_disable;
uniform float spruce_leaf_filter = 0.0;
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
varying flat float atlas_leaf;

#ifdef GAF_WORLD_DIRECT_CLOUD
#include "res://materials/world_map_clouds.gdshaderinc"
varying vec3 grove_world;
#endif

void vertex() {
	source_leaf_red = 0.0;
	if (source_leaf_mask && source_leaf_tint_mix > 0.0) {
		source_leaf_red = texelFetch(source_leaf_weights, ivec2(VERTEX_ID, 0), 0).r;
	}
	// Evaluate inside each face so its exact block boundary stays deterministic.
	crown_local = VERTEX - NORMAL * 0.004;
	atlas_leaf = -1.0;
	if (use_source_atlas && source_crown_mask_base >= 0) {
		int index = source_crown_mask_base + VERTEX_ID;
		int width = textureSize(source_crown_weights, 0).x;
		atlas_leaf = texelFetch(source_crown_weights, ivec2(index % width, index / width), 0).r;
		if (atlas_leaf > 0.0 && source_crown_wind.y > 0.0) {
			// Anchor wind to the world so gameplay and shadow cameras see one pose.
			vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
			vec3 drift = gaf_leaf_world_drift(source_crown_pattern, world_position,
				MODEL_MATRIX[3].y, source_crown_wind, atlas_leaf);
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
#ifdef GAF_WORLD_TREE_SKY
	tree_sky = 1.0;
	if (use_source_atlas && gaf_grove_sky_strength > 0.0) {
		vec3 point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float ceiling = gaf_spruce_sky_region.y + gaf_spruce_sky_extent.y - 1.0;
		float edge = 1.0 - smoothstep(ceiling - 1.0, ceiling, point.y);
		tree_sky = mix(1.0, gaf_spruce_sky(point, INV_VIEW_MATRIX[3].xyz), edge);
	}
#endif
#ifdef GAF_WORLD_DIRECT_CLOUD
	grove_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#endif
}

#if defined(GAF_WORLD_DIRECT_CLOUD) || defined(GAF_WORLD_FOLIAGE_LIGHT)
#define GAF_WORLD_BURLEY
#define GAF_WORLD_CANOPY_DIRECT_SOFTNESS
uniform vec2 canopy_direct_height = vec2(0.0, 1.0);
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
#ifdef GAF_GROVE_REVEAL_COVERAGE
	float coverage = 1.0;
#endif
	// WorldMap uses an orthographic camera. Centre the opening on the actor
	// even while the camera holds its elevation during a jump.
	float distance_to_player = 0.80;
	if (reveal_player && VERTEX.z - player_view.z > 0.01) {
		vec2 extent = abs(VERTEX.xy - player_view.xy) / vec2(0.70, 1.16);
		distance_to_player = length(max(extent - 0.48, vec2(0.0)));
	}
	vec3 albedo = crown_detail ? crown_color(COLOR.rgb) : COLOR.rgb;
	vec2 atlas_uv = UV;
	if (use_source_atlas) {
		// Compressed boundary UVs can select a texel in the adjacent atlas half.
		float inset = 0.5 / float(textureSize(source_atlas, 0).x);
		if (atlas_leaf > 0.5) {
			atlas_uv.x = min(atlas_uv.x, 0.5 - inset);
		} else if (atlas_leaf >= 0.0) {
			atlas_uv.x = max(atlas_uv.x, 0.5 + inset);
		}
		vec4 texel = texture(source_atlas, atlas_uv);
		if (spruce_leaf_filter > 0.0 && atlas_leaf > 0.5) {
			vec2 leaf_uv = vec2(atlas_uv.x * 2.0, atlas_uv.y);
			vec2 dx = dFdx(vec2(UV.x * 2.0, UV.y));
			vec2 dy = dFdy(vec2(UV.x * 2.0, UV.y));
			vec2 leaf_size = vec2(textureSize(spruce_leaf_mips, 0));
			float footprint = max(length(dx * leaf_size), length(dy * leaf_size));
			float weight = spruce_leaf_filter * smoothstep(0.48, 1.16, footprint);
			if (weight > 0.0) {
				vec4 filtered = textureGrad(spruce_leaf_mips, leaf_uv, dx, dy);
				// Retain more of the original holes as the crown gets smaller.
				float alpha_weight = weight * mix(0.70, 0.46, smoothstep(1.15, 2.0, footprint));
				texel.rgb = mix(texel.a < 0.3333 ? filtered.rgb : texel.rgb, filtered.rgb, 0.65 * weight);
				texel.a = mix(texel.a, filtered.a, alpha_weight);
			}
		}
		if (texel.a < 0.3333) {
#ifdef GAF_GROVE_REVEAL_COVERAGE
			// Never fill gaps inside the existing player opening.
			if (!spruce_gap_coverage || spruce_gap_coverage_weight <= 0.0
					|| atlas_leaf < 0.5 || distance_to_player < 0.80) {
				discard;
			}
			vec2 leaf_uv = vec2(atlas_uv.x * 2.0, atlas_uv.y);
			float rank = texture(spruce_leaf_gap_mask, leaf_uv).r;
			if (rank <= 0.0 || rank > spruce_gap_coverage_weight) {
				discard;
			}
			coverage = 0.5;
			texel.rgb = textureLod(spruce_leaf_mips, leaf_uv, 0.0).rgb;
#else
			discard;
#endif
		}
		albedo = texel.rgb;
		if (source_leaf_red > 0.0) {
			albedo = gaf_leaf_color(albedo, source_leaf_hue, source_leaf_red * source_leaf_tint_mix);
		}
	}
	if (distance_to_player < 0.80) {
		float opacity = smoothstep(0.35, 0.80, distance_to_player);
#ifdef GAF_GROVE_PLAYER_CUE
		opacity = mix(opacity, 1.0, player_cue_weight);
#endif
		float threshold = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
#ifdef GAF_GROVE_REVEAL_COVERAGE
		// Share the transition across two MSAA samples, with the original
		// per-pixel threshold selecting the fractional remainder.
		float samples = opacity * 2.0;
		coverage = 0.5 * (floor(samples) + (fract(samples) > threshold ? 1.0 : 0.0));
#else
		if (opacity <= threshold) discard;
#endif
	}
#ifdef GAF_GROVE_REVEAL_COVERAGE
	ALPHA = coverage;
	ALPHA_SCISSOR_THRESHOLD = 0.001;
	// Mobile adds the scissor threshold to the edge before computing coverage.
	ALPHA_ANTIALIASING_EDGE = coverage == 0.5 ? 0.499 : 0.0;
	ALPHA_TEXTURE_COORDINATE = FRAGCOORD.xy;
#endif
#ifdef GAF_WORLD_TREE_SKY
	float ambient_visibility = 1.0;
	if (use_source_atlas && gaf_grove_sky_strength > 0.0) {
		// Warm atlas bark receives stronger shade than the green crown.
		float wood = smoothstep(1.05, 1.30, albedo.r / max(albedo.g, 0.001));
		float amount = gaf_grove_sky_strength * mix(0.29411765, 1.0, wood);
		ambient_visibility = mix(1.0, tree_sky, amount);
	}
	// The validated tree atlases reserve the left half for leaf triangles.
	if (use_source_atlas && atlas_uv.x < 0.5) {
		ambient_visibility *= 1.0 - crown_dusk_occlusion;
		if (crown_ambient_depth > 0.0) {
			// Upper faces retain more sky fill than vertical and downward-facing leaves.
			float up = clamp((mat3(INV_VIEW_MATRIX) * NORMAL).y, 0.0, 1.0);
			ambient_visibility *= 1.0 - crown_ambient_depth * mix(1.0, 0.45, up);
		}
	}
	AO = ambient_visibility;
	AO_LIGHT_AFFECT = 0.0;
#endif
#ifdef GAF_WORLD_TREE_IRRADIANCE
	IRRADIANCE = vec4(0.0);
	if (use_source_atlas && atlas_uv.x >= .5 && bark_irradiance.w > 0.0) {
		const vec3 luma = vec3(.2126, .7152, .0722);
		vec3 world_normal = mat3(INV_VIEW_MATRIX) * NORMAL;
		vec3 base = bark_irradiance.rgb;
		// Cosine convolution of the first-order sky owned by WorldMapAmbient.
		float horizon = dot(world_normal.xz, vec2(.616, -.788));
		base += (2.0 / 3.0) * base * (vec3(.15, .25, .45) * world_normal.y + .18 * horizon);
		vec3 target = base * bark_irradiance_tint;
		target *= dot(albedo * base, luma) / max(dot(albedo * target, luma), .00001);
		IRRADIANCE = vec4(target, bark_irradiance.w);
	}
	if (use_source_atlas && atlas_uv.x >= .5 && bark_diffuse_return != vec3(0.0)) {
		float height = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y - MODEL_MATRIX[3].y;
		float above_contact = smoothstep(.12, .92, height);
		float visibility = mix(.40, 1.0, tree_sky);
		EMISSION += albedo * bark_diffuse_return * (above_contact * visibility);
	}
#endif
	ALBEDO = albedo;
#ifdef GAF_WORLD_TREE_IRRADIANCE
	crown_local_lamp_receiver = use_source_atlas && atlas_uv.x < 0.5 ? 1.0 : 0.0;
#endif
#ifdef GAF_WORLD_CANOPY_DIRECT_SOFTNESS
	canopy_direct_coverage = 0.0;
	if (canopy_direct.w > 0.0 && use_source_atlas && atlas_uv.x < 0.5) {
		float elevation = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
		canopy_direct_coverage = smoothstep(canopy_direct_height.x, canopy_direct_height.y, elevation);
	}
#endif
	ROUGHNESS = 0.95;
	SPECULAR = native_specular;
#ifdef GAF_SHARED_MIST
	vec4 mist = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
	FOG = vec4(mist.rgb, mist.a * grove_mist_strength);
#endif
#ifdef GAF_WORLD_DIRECT_CLOUD
	cloud_transmission = world_cloud_shade(grove_world);
#elif defined(GAF_WORLD_FOLIAGE_LIGHT)
	cloud_transmission = 1.0;
#endif
}
