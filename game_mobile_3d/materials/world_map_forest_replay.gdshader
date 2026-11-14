shader_type spatial;
render_mode cull_back;
#include "res://materials/world_map_mist.gdshaderinc"

uniform sampler2D base_atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D packed_atlas : filter_nearest, repeat_disable;
uniform float radiant_strength = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = texture(base_atlas, UV).rgb;
	ROUGHNESS = 1.0;
	// Blue is the recovered emission mask. Color and level are calibrated for Mobile HDR.
	EMISSION = vec3(1.0, 0.293, 0.0) * texture(packed_atlas, UV).b * radiant_strength;
	FOG = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
}
