shader_type spatial;
#define GAF_WORLD_TERRAIN_PBR
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif
render_mode cull_disabled, diffuse_burley;
#include "res://materials/world_map_surface_v5.gdshaderinc"
#include "res://materials/world_map_terrain_outline.gdshaderinc"
#include "res://materials/world_map_source_terrain.gdshaderinc"
#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_terrain_pbr.gdshaderinc"
#ifdef GAF_WORLD_FLAT_TURF
#include "res://materials/world_map_turf_ambient.gdshaderinc"
#endif
#ifdef GAF_WORLD_SPATIAL_TERRAIN
#include "res://materials/world_map_regional_sky.gdshaderinc"
#define GAF_TERRAIN_NIGHT_SKY
#include "res://materials/world_map_terrain_transport.gdshaderinc"
#include "res://materials/world_map_replay_bounce.gdshaderinc"
#include "res://materials/world_map_local_diffuse.gdshaderinc"
#include "res://materials/world_map_player_contact.gdshaderinc"
#endif
#ifdef GAF_WORLD_GROUND_BOUNCE
#include "res://materials/world_map_ground_bounce.gdshaderinc"
#endif
#ifdef GAF_WORLD_CANOPY
#include "res://materials/world_map_canopy.gdshaderinc"
#endif
varying vec3 surface_world;
varying float surface_top;
varying vec3 surface_normal;
#ifdef GAF_WORLD_TERRAIN_SKY
varying float terrain_sky_factor;
#endif
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D smooth_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform bool smooth_sampling = false;
uniform bool use_albedo_texture = false;
uniform bool use_vertex_color = false;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float native_roughness = 1.0;
uniform float native_metallic = 0.0;
uniform float native_specular = 0.0;
void vertex() {
#ifdef GAF_WORLD_SPATIAL_TERRAIN
	vec3 world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	int receiver = int(CUSTOM1.a);
	vec3 sky = gaf_regional_sky(CUSTOM1.rgb, terrain_ambient_tint, world_point.xz, receiver);
	terrain_canopy_sky = gaf_spruce_sky(world_point, INV_VIEW_MATRIX[3].xyz);
	float canopy = gaf_ground_canopy_sky(terrain_canopy_sky);
	terrain_sky_light = sky * canopy;
	terrain_night_sky_light = gaf_night_sky(sky, receiver) * canopy;
	terrain_day_bounce = gaf_day_bounce(receiver);
	stone_diffuse_log = gaf_stone_diffuse_sample(receiver, MODEL_NORMAL_MATRIX * NORMAL);
	stone_twilight_factor = gaf_stone_twilight_sample(receiver, (MODEL_NORMAL_MATRIX * NORMAL).y);
	terrain_sun_bounce = CUSTOM2.rgb;
#endif
#ifdef GAF_WORLD_TERRAIN_SKY
	terrain_sky_factor = CUSTOM0.x;
#endif
	surface_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	surface_top=(MODEL_NORMAL_MATRIX*NORMAL).y;
	surface_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
#ifdef GAF_WORLD_DIRECT_CLOUD
#define GAF_WORLD_BURLEY
#include "res://materials/world_map_direct_cloud.gdshaderinc"
#endif

void fragment() {
#ifdef GAF_WORLD_GROUND_BOUNCE
	ground_reflection = ground_bounce(surface_world, normalize(surface_normal));
#endif
#ifdef GAF_WORLD_CANOPY
	vec2 contact = surface_top > 0.9 ? canopy_ao(surface_world) : vec2(1.0, CANOPY_DIRECT_AFFECT);
	AO = contact.x;
	AO_LIGHT_AFFECT = contact.y;
#endif
#ifdef GAF_WORLD_TERRAIN_SKY
	if (ground_grade == 3 && abs(surface_normal.y) < 0.1) {
		AO = clamp(terrain_sky_factor, 0.0, 1.0);
		AO_LIGHT_AFFECT = 0.0;
	}
#endif
	vec4 color = albedo_tint;
	if (use_source_terrain) {
		ALBEDO = source_terrain_color(surface_world, surface_normal);
	} else {
		if (use_albedo_texture) color *= smooth_sampling ? texture(smooth_atlas, UV) : texture(atlas, UV);
		if (use_vertex_color) color *= COLOR;
		ALBEDO = shade_world_surface(color.rgb, surface_world, surface_top);
		ALBEDO = grade_stone_twilight(grade_night_path(ALBEDO, surface_top));
	}
#if defined(GAF_WORLD_SPATIAL_TERRAIN) || defined(GAF_WORLD_FLAT_TURF)
	float dawn_turf = 0.0;
	if (gaf_dawn_turf_color > 0.0 && use_source_terrain && (ground_grade == 1 || ground_grade == 2) && surface_top > .998) {
		dawn_turf = gaf_dawn_turf_weight(surface_world, CAMERA_POSITION_WORLD) * gaf_dawn_turf_coverage(ALBEDO);
		ALBEDO = gaf_dawn_turf_chroma(ALBEDO, vec3(1.68, 1.0, 2.37), 0.68 * dawn_turf);
	}
#endif
	vec3 outline_ray = PROJECTION_MATRIX[3][3] > 0.5 ? -INV_VIEW_MATRIX[2].xyz : normalize(surface_world - CAMERA_POSITION_WORLD);
	ALBEDO *= terrain_outline(surface_world, surface_normal, outline_ray);
#ifdef GAF_WORLD_DIRECT_CLOUD
	cloud_transmission=world_cloud_shade(surface_world);
#else
	ALBEDO*=world_cloud_shade(surface_world);
#endif
	float receiver_contact=terrain_contact_shade(surface_world,surface_normal);
	vec2 packed_pbr=terrain_pbr(UV);
	ROUGHNESS = native_roughness*packed_pbr.y;
	METALLIC = native_metallic*packed_pbr.x;
	SPECULAR = native_specular;
	EMISSION=terrain_emission(UV);
#ifdef GAF_WORLD_SPATIAL_TERRAIN
	terrain_direct_contact=terrain_colored_visibility ? 1.0 : receiver_contact;
	float sole = surface_top > 0.9 ? gaf_player_contact(surface_world, CAMERA_POSITION_WORLD) : 1.0;
	if (gaf_diffuse_opening.w > 0.0 || (ground_grade == 3 && gaf_stone_shade_fill.w > 0.0)) {
		terrain_opening_incident = terrain_opening_fill(ALBEDO, receiver_contact, sole);
	}
	vec3 diffuse_fill = terrain_indirect(ALBEDO,METALLIC,AO,cloud_transmission,receiver_contact,surface_top,CAMERA_POSITION_WORLD)*sole;
	diffuse_fill = gaf_local_diffuse(diffuse_fill, surface_world, surface_normal);
	EMISSION += gaf_dawn_turf_chroma(diffuse_fill, vec3(1.42, 1.0, .65), .55 * dawn_turf);
	EMISSION+=ALBEDO*(1.0-METALLIC)*gaf_replay_incident(surface_world,surface_normal)*receiver_contact*sole;
	if (terrain_rough_reflection) {
		vec3 reflected = terrain_reflected(normalize(NORMAL), normalize(VIEW), ROUGHNESS, AO, cloud_transmission, receiver_contact, native_specular);
		EMISSION += gaf_stone_reflection_balance(reflected, diffuse_fill);
	}
#else
	ALBEDO*=receiver_contact;
#endif
#ifdef GAF_SHARED_MIST
	FOG=gaf_surface_mist(SCREEN_UV,-VERTEX.z,INV_VIEW_MATRIX[3].xyz,-INV_VIEW_MATRIX[2].xyz,vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1]));
#endif
}
