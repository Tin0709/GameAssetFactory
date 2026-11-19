shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://materials/mechanic_lab_health_fill.gdshaderinc"

instance uniform float health_ratio = 1.0;
instance uniform float delayed_ratio = 1.0;
uniform bool use_batched_health = false;
varying vec2 bar_fill;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bar_fill = use_batched_health ? INSTANCE_CUSTOM.rg : vec2(health_ratio, delayed_ratio);
}

void fragment() {
	ALBEDO = health_bar_colour(UV, bar_fill);
	ALPHA = 1.0;
}
