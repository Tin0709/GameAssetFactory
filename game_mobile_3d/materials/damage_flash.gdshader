shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
instance uniform float hit_strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	ALBEDO = vec3(1.0, 0.045, 0.025);
	ALPHA = hit_strength * 0.58;
}
