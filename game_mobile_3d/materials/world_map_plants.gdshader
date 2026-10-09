shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
#include "res://materials/world_map_wind.gdshaderinc"
uniform int plant_kind = 0; // short blades / flower / golden tall stems
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform bool use_albedo_texture = false;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float short_height_scale = 0.72;
varying vec3 plant_root;
varying float tip;
void vertex() {
	vec3 local_root=vec3(UV2.x-0.5,0.0,UV2.y-0.5);
	plant_root=(MODEL_MATRIX*vec4(local_root,1.0)).xyz;
	tip=plant_kind==0 ? COLOR.g : UV.x;
	vec2 breeze=world_breeze(plant_root);
	vec2 passage=world_passage(plant_root);
	if (plant_kind==0) {
		VERTEX.y*=short_height_scale;
		vec2 offset=(breeze*0.038+passage*2.1)*COLOR.r;
		float cap=max(VERTEX.y*0.55,0.001);
		offset*=min(1.0,cap/max(length(offset),0.00001));
		vec3 local_offset=inverse(mat3(MODEL_MATRIX))*vec3(offset.x,0.0,offset.y);
		VERTEX.xz+=local_offset.xz;
		VERTEX.y=sqrt(max(VERTEX.y*VERTEX.y-dot(local_offset.xz,local_offset.xz),0.0));
	} else {
		// Authored UV attachment masks are identical across every rigid head/leaf.
		vec2 angles=(breeze*(plant_kind==1 ? 0.10 : 0.12)+passage*2.0)*tip*tip;
		angles*=min(1.0,0.38/max(length(angles),0.00001));
		vec3 local_bend=inverse(mat3(MODEL_MATRIX))*vec3(angles.x,0.0,angles.y);
		VERTEX=local_root+rotate_plant(VERTEX-local_root,local_bend.xz);
		NORMAL=rotate_plant(NORMAL,local_bend.xz);
	}
}
void fragment() {
	vec3 source=plant_kind==0 ? texture(atlas,UV).rgb : COLOR.rgb*albedo_tint.rgb;
	if (plant_kind==0) {
		float field=0.5+0.5*sin(plant_root.x*0.23+sin(plant_root.z*0.18))*sin(plant_root.z*0.27);
		vec3 green=source*vec3(1.05,0.97,1.05)*mix(0.92,1.08,smoothstep(0.0,1.0,tip));
		float straw=smoothstep(0.42,0.85,field)*smoothstep(0.45,0.90,tip)*0.45;
		ALBEDO=mix(green,vec3(0.35,0.33,0.14),straw);
	} else {
		float luma=dot(source,vec3(0.2126,0.7152,0.0722));
		ALBEDO=mix(vec3(luma),source,0.88);
	}
	vec3 face=FRONT_FACING ? NORMAL : -NORMAL;
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	float soft=plant_kind==0 ? 0.72 : (plant_kind==2 ? 0.50 : 0.18);
	NORMAL=normalize(mix(face,up,soft));
	ROUGHNESS=1.0;
	SPECULAR=0.0;
}
