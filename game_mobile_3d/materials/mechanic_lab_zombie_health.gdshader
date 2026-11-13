shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float health_ratio = 1.0;
instance uniform float delayed_ratio = 1.0;
uniform bool use_batched_health = false;
varying vec2 bar_fill;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bar_fill = use_batched_health ? INSTANCE_CUSTOM.rg : vec2(health_ratio, delayed_ratio);
}

void fragment() {
	vec2 interior = (UV - vec2(0.025, 0.19)) / vec2(0.95, 0.62);
	bool inside = all(greaterThanEqual(interior, vec2(0.0))) && all(lessThanEqual(interior, vec2(1.0)));
	vec3 fill = mix(vec3(0.70, 0.035, 0.04), vec3(1.0, 0.24, 0.11), 1.0 - interior.y);
	vec3 track = interior.x < bar_fill.y ? vec3(0.98, 0.70, 0.28) : vec3(0.12, 0.04, 0.05);
	ALBEDO = inside ? (interior.x < bar_fill.x ? fill : track) : vec3(0.03, 0.017, 0.023);
	ALPHA = 1.0;
}
