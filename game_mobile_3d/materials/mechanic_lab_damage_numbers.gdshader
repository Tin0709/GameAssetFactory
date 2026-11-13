shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D digits : source_color, filter_nearest, repeat_disable;
varying flat vec2 glyph_data;

void vertex() {
	float scale = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale, INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
	glyph_data = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec4 glyph = texture(digits, vec2((glyph_data.x + UV.x) * 0.1, UV.y));
	ALBEDO = glyph.rgb;
	ALPHA = glyph.a * glyph_data.y;
}
