shader_type spatial;
render_mode diffuse_burley, depth_draw_always, cull_disabled;
#include "res://materials/gameplay_cliff_cutaway.gdshaderinc"
#include "res://materials/world_map_surface.gdshaderinc"
#include "res://materials/world_map_clouds.gdshaderinc"
varying float surface_top;
varying vec3 surface_normal;

// Only occluding chunks use this material. All other chunks use their imports.
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D smooth_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform bool smooth_sampling = false;
uniform bool use_albedo_texture = false;
uniform bool use_vertex_color = false;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float native_roughness = 1.0;
uniform float native_metallic = 0.0;
uniform float native_specular = 0.5;

void vertex() {
	cutaway_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_top=(MODEL_NORMAL_MATRIX*NORMAL).y;
	surface_normal=MODEL_NORMAL_MATRIX*NORMAL;
}

void fragment() {
	vec4 color = albedo_tint;
	if (use_albedo_texture) color *= smooth_sampling ? texture(smooth_atlas, UV) : texture(atlas, UV);
	if (use_vertex_color) color *= COLOR;
	ALBEDO = shade_world_surface(color.rgb,cutaway_world,surface_top)*world_cloud_shade(cutaway_world);
	ALBEDO*=terrain_contact_shade(cutaway_world,surface_normal);
	ALPHA = color.a * cliff_visibility();
	ROUGHNESS = native_roughness;
	METALLIC = native_metallic;
	SPECULAR = native_specular;
}
