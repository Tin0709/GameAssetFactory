shader_type spatial;
render_mode cull_back;
#include "res://materials/world_map_mist.gdshaderinc"

uniform sampler2D mushroom_diffuse : source_color, filter_nearest, repeat_disable;
uniform sampler2D mushroom_emission : source_color, filter_nearest, repeat_disable;
uniform float emission_gain = 0.0;
uniform float phase_coverage = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (phase_coverage < 1.0) {
		// Use a fixed spatial pattern so a moving camera does not change the fade.
		vec3 cell = floor(world_position * 40.0);
		float threshold = fract(sin(dot(cell, vec3(19.19, 41.13, 93.71))) * 4375.13);
		if (threshold >= phase_coverage) discard;
	}
	ALBEDO = texture(mushroom_diffuse, UV).rgb;
	EMISSION = texture(mushroom_emission, UV).rgb * emission_gain;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
}
