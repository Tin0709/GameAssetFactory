shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://materials/world_map_surface.gdshaderinc"
#include "res://materials/world_map_clouds.gdshaderinc"
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
void fragment() {
	vec4 color = albedo_tint;
	if (use_albedo_texture) color *= smooth_sampling ? texture(smooth_atlas, UV) : texture(atlas, UV);
	if (use_vertex_color) color *= COLOR;
	ALBEDO = shade_world_surface(color.rgb,surface_world,surface_top)*world_cloud_shade(surface_world);
	ALBEDO*=terrain_contact_shade(surface_world,surface_normal);
	ROUGHNESS = native_roughness;
	METALLIC = native_metallic;
	SPECULAR = native_specular;
}
