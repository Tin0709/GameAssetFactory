shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D source_atlas : source_color, filter_linear_mipmap, repeat_disable;

#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

void fragment() {
	ALBEDO = texture(source_atlas, UV).rgb;
	ROUGHNESS = 1.0;
	AO = 0.88;
#ifdef GAF_SHARED_MIST
	FOG = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
#endif
}

#ifdef GAF_FAR_TERRAIN_SHADOWS
#include "res://materials/world_map_far_terrain_shadow.gdshaderinc"
float stone_fresnel(float cosine) {
	float remaining = 1.0 - cosine;
	float square = remaining * remaining;
	return square * square * remaining;
}
void light() {
	float facing = max(dot(NORMAL,LIGHT),0.);
	float eye = max(dot(NORMAL,VIEW),.0001);
	float light_half = clamp(dot(LIGHT,normalize(VIEW+LIGHT)),0.,1.);
	float grazing = 2.0 * light_half * light_half * ROUGHNESS - .5;
	float response = facing * (1. + grazing * stone_fresnel(eye)) * (1. + grazing * stone_fresnel(facing));
	float visibility = GAF_RESOLVE_TERRAIN_SHADOW;
	DIFFUSE_LIGHT += LIGHT_COLOR * (response * visibility / PI);
}
#endif
