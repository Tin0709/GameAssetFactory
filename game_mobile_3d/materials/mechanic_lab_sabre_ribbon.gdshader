shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	float hot = smoothstep(0.09, 0.34, COLOR.a);
	ALBEDO = COLOR.rgb * (1.0 + hot * 5.0);
	ALPHA = min(1.0, COLOR.a * (1.0 + hot * 0.50));
}
