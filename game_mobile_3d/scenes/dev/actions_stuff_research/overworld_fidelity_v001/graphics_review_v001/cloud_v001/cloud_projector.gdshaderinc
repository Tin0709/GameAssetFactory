#include "cloud_response.gdshaderinc"

uniform sampler2D gaf_cloud_pattern : filter_linear, repeat_enable;
uniform vec4 gaf_cloud_phase = vec4(0.0);
uniform float gaf_cloud_strength = 0.0;

float gaf_cloud_at(vec3 world_position) {
	vec2 ground = world_position.xz;
	float broad = texture(gaf_cloud_pattern, ground * 0.0125 + gaf_cloud_phase.xy).r;
	float detail = texture(gaf_cloud_pattern, ground * 0.025 + gaf_cloud_phase.zw).g;
	return gaf_cloud_response(broad, detail, gaf_cloud_strength);
}
