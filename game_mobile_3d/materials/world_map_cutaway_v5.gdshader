shader_type spatial;
#define GAF_WORLD_TERRAIN_PBR
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif
render_mode diffuse_burley, depth_draw_always, cull_disabled;
#include "res://materials/gameplay_cliff_cutaway.gdshaderinc"
#include "res://materials/world_map_surface_v5.gdshaderinc"
#include "res://materials/world_map_terrain_outline.gdshaderinc"
#include "res://materials/world_map_source_terrain.gdshaderinc"
#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_terrain_pbr.gdshaderinc"
#ifdef GAF_WORLD_SPATIAL_TERRAIN
#include "res://materials/world_map_spruce_sky.gdshaderinc"
#include "res://materials/world_map_regional_sky.gdshaderinc"
#define GAF_TERRAIN_NIGHT_SKY
#include "res://materials/world_map_terrain_transport.gdshaderinc"
#include "res://materials/world_map_replay_bounce.gdshaderinc"
#include "res://materials/world_map_player_contact.gdshaderinc"
#endif
#ifdef GAF_WORLD_GROUND_BOUNCE
#include "res://materials/world_map_ground_bounce.gdshaderinc"
#endif
#ifdef GAF_WORLD_CANOPY
#include "res://materials/world_map_canopy.gdshaderinc"
#endif
varying float surface_top;
varying vec3 surface_normal;
#ifdef GAF_WORLD_TERRAIN_SKY
varying float terrain_sky_factor;
#endif

// Only occluding chunks use this material. All other chunks use their imports.
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D smooth_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform bool smooth_sampling = false;
uniform bool use_albedo_texture = false;
uniform bool use_vertex_color = false;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float native_roughness = 1.0;
uniform float native_metallic = 0.0;
// Match the opaque shader: unset ShaderMaterial parameters are null when copied.
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
	terrain_sun_bounce = CUSTOM2.rgb;
#endif
#ifdef GAF_WORLD_TERRAIN_SKY
	terrain_sky_factor = CUSTOM0.x;
#endif
	cutaway_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_top=(MODEL_NORMAL_MATRIX*NORMAL).y;
	surface_normal=MODEL_NORMAL_MATRIX*NORMAL;
}

#ifdef GAF_WORLD_DIRECT_CLOUD
#define GAF_WORLD_BURLEY
#include "res://materials/world_map_direct_cloud.gdshaderinc"
#endif

void fragment() {
#ifdef GAF_WORLD_GROUND_BOUNCE
	ground_reflection = ground_bounce(cutaway_world, normalize(surface_normal));
#endif
#ifdef GAF_WORLD_CANOPY
	vec2 contact = surface_top > 0.9 ? canopy_ao(cutaway_world) : vec2(1.0, CANOPY_DIRECT_AFFECT);
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
		ALBEDO = source_terrain_color(cutaway_world, surface_normal);
	} else {
		if (use_albedo_texture) color *= smooth_sampling ? texture(smooth_atlas, UV) : texture(atlas, UV);
		if (use_vertex_color) color *= COLOR;
		ALBEDO = shade_world_surface(color.rgb, cutaway_world, surface_top);
		ALBEDO = grade_stone_twilight(grade_night_path(ALBEDO, surface_top));
	}
#ifdef GAF_WORLD_SPATIAL_TERRAIN
	float dawn_turf = 0.0;
	if (gaf_dawn_turf_color > 0.0 && use_source_terrain && (ground_grade == 1 || ground_grade == 2) && surface_top > .998) {
		dawn_turf = gaf_dawn_turf_weight(cutaway_world, CAMERA_POSITION_WORLD) * gaf_dawn_turf_coverage(ALBEDO);
		ALBEDO = gaf_dawn_turf_chroma(ALBEDO, vec3(1.68, 1.0, 2.37), 0.68 * dawn_turf);
	}
#endif
	vec3 outline_ray = PROJECTION_MATRIX[3][3] > 0.5 ? -INV_VIEW_MATRIX[2].xyz : normalize(cutaway_world - CAMERA_POSITION_WORLD);
	ALBEDO *= terrain_outline(cutaway_world, surface_normal, outline_ray);
#ifdef GAF_WORLD_DIRECT_CLOUD
	cloud_transmission=world_cloud_shade(cutaway_world);
#else
	ALBEDO*=world_cloud_shade(cutaway_world);
#endif
	float receiver_contact=terrain_contact_shade(cutaway_world,surface_normal);
#ifdef GAF_WORLD_SPATIAL_TERRAIN
	terrain_direct_contact=terrain_colored_visibility ? 1.0 : receiver_contact;
#else
	ALBEDO*=receiver_contact;
#endif
	// Chunk bounds include low ground beside high walls. Fade only above the
	// player's lower body; otherwise transparent floor exposes buried faces and
	// draws a rectangular seam where the neighbouring chunk stays opaque.
	float wall_height=smoothstep(cutaway_start.y-0.3,cutaway_start.y+0.3,cutaway_world.y);
	ALPHA = color.a * mix(1.0,cliff_visibility(),wall_height);
	vec2 packed_pbr=terrain_pbr(UV);
	ROUGHNESS = native_roughness*packed_pbr.y;
	METALLIC = native_metallic*packed_pbr.x;
	SPECULAR = native_specular;
	EMISSION=terrain_emission(UV);
#ifdef GAF_WORLD_SPATIAL_TERRAIN
	float sole = surface_normal.y > 0.9 ? gaf_player_contact(cutaway_world, CAMERA_POSITION_WORLD) : 1.0;
	if (gaf_diffuse_opening.w > 0.0) {
		terrain_opening_incident = terrain_opening_fill(ALBEDO, receiver_contact, sole);
	}
	vec3 diffuse_fill = terrain_indirect(ALBEDO,METALLIC,AO,cloud_transmission,receiver_contact,surface_top)*sole;
	EMISSION += gaf_dawn_turf_chroma(diffuse_fill, vec3(1.42, 1.0, .65), .55 * dawn_turf);
	EMISSION+=ALBEDO*(1.0-METALLIC)*gaf_replay_incident(cutaway_world,surface_normal)*receiver_contact*sole;
	if(terrain_rough_reflection)EMISSION+=terrain_reflected(normalize(NORMAL),normalize(VIEW),ROUGHNESS,AO,cloud_transmission,receiver_contact,native_specular);
#endif
#ifdef GAF_SHARED_MIST
	FOG=gaf_surface_mist(SCREEN_UV,-VERTEX.z,INV_VIEW_MATRIX[3].xyz,-INV_VIEW_MATRIX[2].xyz,vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1]));
#endif
}
