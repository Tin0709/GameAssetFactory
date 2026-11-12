shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://materials/world_map_mist.gdshaderinc"
uniform sampler2D packed_source : filter_nearest, repeat_disable;
uniform sampler2D coverage_source : filter_nearest, repeat_enable;
uniform ivec2 atlas_cell = ivec2(0);
uniform float emission_scale = 0.0;
uniform float phase_coverage = 0.0;
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	if (texture(coverage_source, UV).r < 0.3333) {
		discard;
	}
	// Stable world-space cutout during the dawn/dusk and noon transitions.
	if (phase_coverage < 1.0) {
		vec2 cell = floor(world_point.xz * 16.0);
		float threshold = fract(sin(dot(cell, vec2(19.19, 93.71))) * 4375.13);
		if (threshold >= phase_coverage) discard;
	}
	ivec2 texel = ivec2(floor(fract(world_point.xz) * 16.0));
	vec4 sample_data = texelFetch(packed_source, atlas_cell * 16 + texel, 0);
	ALBEDO = sample_data.r * vec3(0.391573, 0.817068, 0.975842) + vec3(0.0, 0.013702, 0.024158);
	vec2 normal_xy = sample_data.ba * 2.0 - 1.0;
	NORMAL_MAP = vec3(normal_xy * 0.5 + 0.5, sqrt(max(1.0 - dot(normal_xy,normal_xy),0.0)) * 0.5 + 0.5);
	EMISSION = sample_data.g * vec3(0.078187, 0.212231, 0.278894) * (5.0 * emission_scale);
	ROUGHNESS = 0.4;
	SPECULAR = 0.5;
	FOG = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1]));
}