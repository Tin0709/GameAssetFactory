shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_back;
stencil_mode write, compare_always, 121;

uniform sampler2D opacity_texture : filter_nearest, repeat_disable;
uniform float cutoff = 0.0;

void fragment() {
	if (cutoff > 0.0 && texture(opacity_texture, UV).a < cutoff) {
		discard;
	}
	ALPHA = 0.0;
}
