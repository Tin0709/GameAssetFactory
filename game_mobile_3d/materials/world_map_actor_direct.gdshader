shader_type spatial;
render_mode cull_disabled;
#define GAF_WORLD_BURLEY
#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_local_diffuse.gdshaderinc"

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float native_roughness = 1.0;
uniform float native_metallic = 0.0;
uniform float native_specular = 0.5;
#include "res://materials/world_map_direct_cloud.gdshaderinc"

varying vec3 actor_world;

void vertex() {
	actor_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = texture(atlas, UV).rgb * albedo_tint.rgb;
	ROUGHNESS = native_roughness;
	METALLIC = native_metallic;
	SPECULAR = native_specular;
	cloud_transmission = world_cloud_shade(actor_world);
	EMISSION += gaf_local_environment_delta(ALBEDO, METALLIC, actor_world, mat3(INV_VIEW_MATRIX) * NORMAL);
}
