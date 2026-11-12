shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;

instance uniform float player_hit_flash = 0.0;

void fragment() {
	ALBEDO = vec3(1.25, 0.025, 0.035);
	ALPHA = player_hit_flash * 0.72;
}
