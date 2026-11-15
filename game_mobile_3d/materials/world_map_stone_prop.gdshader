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
