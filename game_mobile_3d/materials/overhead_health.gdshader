shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
instance uniform float bar_opacity : hint_range(0.0, 1.0) = 1.0;
void vertex() {
	// World-sized camera-facing rectangle, independent of actor yaw.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 inner_uv = (UV - vec2(0.025, 0.18)) / vec2(0.95, 0.64);
	bool inner = inner_uv.x >= 0.0 && inner_uv.x <= 1.0 && inner_uv.y >= 0.0 && inner_uv.y <= 1.0;
	vec3 fill_color = mix(vec3(0.96, 0.22, 0.12), vec3(0.30, 0.90, 0.38), health_ratio);
	ALBEDO = inner ? (inner_uv.x < health_ratio ? fill_color : vec3(0.12, 0.13, 0.16)) : vec3(0.035, 0.04, 0.05);
	ALPHA = bar_opacity;
}
