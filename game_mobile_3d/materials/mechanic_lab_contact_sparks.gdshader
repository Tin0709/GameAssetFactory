shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D streak_mask : filter_nearest, repeat_disable;

void fragment() {
	ALBEDO = COLOR.rgb * 3.0;
	ALPHA = texture(streak_mask, UV).a * COLOR.a;
}
