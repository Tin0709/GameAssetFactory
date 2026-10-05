shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
