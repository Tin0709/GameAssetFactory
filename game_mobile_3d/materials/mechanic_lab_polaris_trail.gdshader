shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	// Niagara multiplies the initial RGB of 10 by the Polaris User.Color.
	// Map that HDR color into the Lab's display range without clipping its hue.
	vec3 source_rgb = vec3(12.0370483, 17.9309952, 20.0);
	ALBEDO = source_rgb / 20.0;
	ALPHA = COLOR.a;
}
