shader_type spatial;
render_mode cull_back;
#include "res://materials/world_map_mist.gdshaderinc"

uniform sampler2D fixture_atlas : source_color, filter_nearest, repeat_disable;
uniform float phase_coverage = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (phase_coverage < 1.0) {
		vec3 cell = floor(world_position * 40.0);
		float threshold = fract(sin(dot(cell, vec3(19.19, 41.13, 93.71))) * 4375.13);
		if (threshold >= phase_coverage) discard;
	}
	ALBEDO = texture(fixture_atlas, UV).rgb;
	ROUGHNESS = 1.0;
	FOG = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
}
