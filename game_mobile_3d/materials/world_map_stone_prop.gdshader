shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D source_atlas : source_color, filter_linear_mipmap, repeat_disable;

#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

#ifdef GAF_PROP_CUTOUT
#include "res://materials/world_map_spruce_sky.gdshaderinc"
varying float prop_sky;

void vertex() {
	vec3 point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	prop_sky = gaf_spruce_sky(point, INV_VIEW_MATRIX[3].xyz);
}
#endif

void fragment() {
	vec4 source = texture(source_atlas, UV);
#ifdef GAF_PROP_CUTOUT
	if (source.a < 0.5) {
		discard;
	}
#endif
	ALBEDO = source.rgb;
	ROUGHNESS = 1.0;
#ifdef GAF_PROP_CUTOUT
	AO = 0.96 * mix(0.55, 1.0, gaf_ground_canopy_sky(prop_sky));
	AO_LIGHT_AFFECT = 0.0;
#else
	AO = 0.88;
#endif
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
