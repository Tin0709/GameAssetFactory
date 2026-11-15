shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap, repeat_disable;
const float integration = 1.0;
const vec3 grade = vec3(0.67, 0.59, 0.70);

#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif
const float terrace_indirect = 0.8;
varying vec3 terrace_point;
varying float terrace_visibility;
varying float terrace_side_weight;
const float terrace_wall_finish = 0.65;
#include "res://materials/world_map_spruce_sky.gdshaderinc"
void vertex(){
	terrace_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrace_visibility = CUSTOM0.x;
	terrace_side_weight = 1.0 - smoothstep(0.05, 0.35, abs(normalize(MODEL_NORMAL_MATRIX * NORMAL).y));
}
void fragment() {
	vec3 source = texture(source_atlas, UV).rgb;
	float luma = dot(source,vec3(.2126,.7152,.0722));
	ALBEDO = mix(source,mix(vec3(luma),source,0.72)*grade,integration);
	float local_visibility = mix(0.45, 1.0, clamp(terrace_visibility, 0.0, 1.0));
	float canopy = gaf_ground_canopy_sky(gaf_spruce_sky(terrace_point,INV_VIEW_MATRIX[3].xyz));
	AO = mix(1.0,0.82,integration)*mix(1.0,local_visibility*mix(0.55,1.0,canopy),terrace_indirect);
	AO_LIGHT_AFFECT = 0.0;
	float face_luma = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
	vec3 softened_side = mix(vec3(face_luma), ALBEDO, 0.70) * vec3(0.81, 0.85, 0.95);
	ALBEDO = mix(ALBEDO, softened_side, terrace_side_weight * terrace_wall_finish);
	ROUGHNESS = 1.0;
#ifdef GAF_SHARED_MIST
	FOG = gaf_surface_mist(SCREEN_UV,-VERTEX.z,INV_VIEW_MATRIX[3].xyz,-INV_VIEW_MATRIX[2].xyz,
			vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1]));
#endif
}

