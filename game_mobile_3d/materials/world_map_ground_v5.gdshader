shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://materials/world_map_surface_v5.gdshaderinc"
#include "res://materials/world_map_clouds.gdshaderinc"
#ifdef GAF_WORLD_GROUND_BOUNCE
#include "res://materials/world_map_ground_bounce.gdshaderinc"
#endif
#ifdef GAF_WORLD_CANOPY
#include "res://materials/world_map_canopy.gdshaderinc"
#endif
varying vec3 surface_world;
varying float surface_top;
varying vec3 surface_normal;
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
	vec4 color = albedo_tint;
	if (use_albedo_texture) color *= smooth_sampling ? texture(smooth_atlas, UV) : texture(atlas, UV);
	if (use_vertex_color) color *= COLOR;
	ALBEDO = shade_world_surface(color.rgb,surface_world,surface_top);
#ifdef GAF_WORLD_DIRECT_CLOUD
	cloud_transmission=world_cloud_shade(surface_world);
#else
	ALBEDO*=world_cloud_shade(surface_world);
#endif
	ALBEDO*=terrain_contact_shade(surface_world,surface_normal);
	ROUGHNESS = native_roughness;
	METALLIC = native_metallic;
	SPECULAR = native_specular;
}
