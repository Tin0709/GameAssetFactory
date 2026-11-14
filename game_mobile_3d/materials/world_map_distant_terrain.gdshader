shader_type spatial;
render_mode unshaded, depth_draw_never;
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

uniform sampler2D terrain_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 distant_light = vec3(0.0);
uniform float visibility_scale = 0.0;

void fragment() {
	vec3 rgb = texture(terrain_atlas, UV).rgb;
	float tone = sqrt(max(dot(rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0));
	float up = max(0.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	ALBEDO = distant_light * mix(0.65, 1.0, tone) * mix(0.84, 1.0, up);
	ALPHA = visibility_scale * (1.0 - smoothstep(55.0, 68.0, -VERTEX.z));
#ifdef GAF_SHARED_MIST
	vec4 air = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz,
		-INV_VIEW_MATRIX[2].xyz, vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
	FOG = vec4(air.rgb * 0.12, air.a);
#endif
}
