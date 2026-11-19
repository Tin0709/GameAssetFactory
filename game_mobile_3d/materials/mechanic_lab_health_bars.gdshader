shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, shadows_disabled;

#include "res://materials/mechanic_lab_health_fill.gdshaderinc"

varying vec2 bar_fill;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bar_fill = INSTANCE_CUSTOM.rg;
}

void fragment() {
	ALBEDO = health_bar_colour(UV, bar_fill);
}
