shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	float hot = smoothstep(0.09, 0.34, COLOR.a);
	float edge = smoothstep(0.36, 0.94, UV.x);
	ALBEDO = COLOR.rgb * (1.0 + hot * edge * 5.0);
	ALPHA = COLOR.a * mix(0.18, 1.0 + hot * 0.50, edge);
}
