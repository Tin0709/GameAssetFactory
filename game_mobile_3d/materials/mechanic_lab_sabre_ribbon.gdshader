shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 3.8 * smoothstep(0.10, 0.44, COLOR.a);
	ALPHA = COLOR.a;
}
