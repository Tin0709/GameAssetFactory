shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	// Niagara multiplies the initial RGB of 10 by the Polaris User.Color.
	ALBEDO = vec3(12.0370483, 17.9309952, 20.0);
	ALPHA = COLOR.a;
}
