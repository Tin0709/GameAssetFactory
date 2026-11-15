shader_type spatial;
#ifdef GAF_OPAQUE_VISTA
render_mode unshaded, depth_draw_opaque;
#else
render_mode unshaded, depth_draw_never;
#endif
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

uniform sampler2D terrain_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 distant_light = vec3(0.0);
#ifdef GAF_OPAQUE_VISTA
uniform vec4 vista_clear_blend = vec4(0.0);
uniform vec4 vista_edges = vec4(0.0);
uniform vec2 vista_depth_fade = vec2(52.0, 71.0);
varying vec2 vista_local_xz;

void vertex() {
	vista_local_xz = VERTEX.xz;
}
#else
uniform float visibility_scale = 0.0;
uniform vec2 subject_screen_uv = vec2(0.5);
#endif

void fragment() {
	vec3 rgb = texture(terrain_atlas, UV).rgb;
	float tone = sqrt(max(dot(rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0));
	float up = max(0.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	ALBEDO = distant_light * mix(0.65, 1.0, tone) * mix(0.84, 1.0, up);
#ifndef GAF_OPAQUE_VISTA
	// Preserve the clear background seen through the nearby cliff cutaway.
	vec2 subject_offset = (SCREEN_UV - subject_screen_uv)
		* vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float outside_subject = smoothstep(0.21, 0.40, length(subject_offset));
	ALPHA = visibility_scale * outside_subject * (1.0 - smoothstep(55.0, 68.0, -VERTEX.z));
#endif
#ifdef GAF_SHARED_MIST
	vec4 air = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz,
		-INV_VIEW_MATRIX[2].xyz, vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
#ifdef GAF_OPAQUE_VISTA
	if (vista_clear_blend.w > 0.0) {
		float side = min(vista_local_xz.x - vista_edges.x, vista_edges.y - vista_local_xz.x);
		float edge = min(side, vista_local_xz.y - vista_edges.z);
		float border = 1.0 - smoothstep(0.0, vista_edges.w, edge);
		float distance_fade = smoothstep(vista_depth_fade.x, vista_depth_fade.y, -VERTEX.z);
		float fade = max(border, distance_fade) * vista_clear_blend.w;
		ALBEDO = mix(ALBEDO, vista_clear_blend.rgb, fade);
		air.a *= 1.0 - fade;
	}
#endif
	FOG = vec4(air.rgb * 0.12, air.a);
#endif
}
