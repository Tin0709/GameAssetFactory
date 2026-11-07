shader_type spatial;
#ifdef GAF_WORLD_LEAF_SAMPLING
render_mode cull_disabled, diffuse_lambert, specular_disabled, alpha_to_coverage;
#else
render_mode cull_disabled, diffuse_lambert, specular_disabled;
#endif
#include "res://materials/world_map_wind.gdshaderinc"
#include "res://materials/world_map_clouds.gdshaderinc"
varying vec3 leaf_world;
#ifdef GAF_WORLD_LEAF_SAMPLING
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
#else
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
#endif
uniform vec4 albedo_tint : source_color = vec4(1.0);
void vertex() {
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	leaf_world=world;
	// Same continuous field and base for all touching blocks, including half blocks.
	float height=max(0.0,world.y-INSTANCE_CUSTOM.r);
	float weight=smoothstep(0.0,1.4,height);
	vec3 root=vec3(world.x,INSTANCE_CUSTOM.r,world.z);
	vec2 offset=(world_breeze(world)*0.048+world_passage(root)*0.55)*weight;
	VERTEX+=inverse(mat3(MODEL_MATRIX))*vec3(offset.x,0.0,offset.y);
}
#ifdef GAF_WORLD_FOLIAGE_LIGHT
#include "res://materials/world_map_foliage_light.gdshaderinc"
#else
#ifdef GAF_WORLD_DIRECT_CLOUD
#include "res://materials/world_map_direct_cloud.gdshaderinc"
#endif
#endif

void fragment() {
	vec4 source=texture(atlas,UV)*albedo_tint;
	ALBEDO=source.rgb;
#ifdef GAF_WORLD_DIRECT_CLOUD
	cloud_transmission=world_cloud_shade(leaf_world);
#else
	ALBEDO*=world_cloud_shade(leaf_world);
#endif
	ALPHA=source.a;
	ALPHA_SCISSOR_THRESHOLD=0.5;
#ifdef GAF_WORLD_LEAF_SAMPLING
	ALPHA_ANTIALIASING_EDGE=0.3;
	ALPHA_TEXTURE_COORDINATE=UV*vec2(textureSize(atlas,0));
#endif
#ifdef GAF_WORLD_FOLIAGE_LIGHT
	foliage_face = normalize(NORMAL);
	foliage_weight = 1.0;
#endif
	vec3 face=FRONT_FACING ? NORMAL : -NORMAL;
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL=normalize(mix(face,up,0.16));
	ROUGHNESS=1.0;
	SPECULAR=0.0;
}
