shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;

instance uniform float hit_flash = 0.0;

void fragment() {
	ALBEDO = vec3(3.2, 1.93, 0.70);
	ALPHA = hit_flash * 0.88;
}
