shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	// Custom data carries the linear Niagara color divided by its maximum.
	// This exposure conversion keeps the orange-to-red gradient on Mobile.
	ALBEDO = INSTANCE_CUSTOM.rgb * 5.0;
	ALPHA = INSTANCE_CUSTOM.a;
}
