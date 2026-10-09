shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
#include "res://materials/world_map_wind.gdshaderinc"
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
void vertex() {
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	// Same continuous field and base for all touching blocks, including half blocks.
	float height=max(0.0,world.y-INSTANCE_CUSTOM.r);
	float weight=smoothstep(0.0,1.4,height);
	vec3 root=vec3(world.x,INSTANCE_CUSTOM.r,world.z);
	vec2 offset=(world_breeze(world)*0.048+world_passage(root)*0.55)*weight;
	VERTEX+=inverse(mat3(MODEL_MATRIX))*vec3(offset.x,0.0,offset.y);
}
void fragment() {
	vec4 source=texture(atlas,UV)*albedo_tint;
	ALBEDO=source.rgb;
	ALPHA=source.a;
	ALPHA_SCISSOR_THRESHOLD=0.5;
	vec3 face=FRONT_FACING ? NORMAL : -NORMAL;
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL=normalize(mix(face,up,0.16));
	ROUGHNESS=1.0;
	SPECULAR=0.0;
}
