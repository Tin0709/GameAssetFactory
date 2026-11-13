shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D smoke_mask : filter_nearest, repeat_disable;
uniform vec4 dust_tint : source_color;
varying flat vec3 sprite_data;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	sprite_data = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	vec2 uv = (UV + sprite_data.xy) / vec2(8.0, 4.0);
	ALBEDO = dust_tint.rgb;
	ALPHA = texture(smoke_mask, uv).a * sprite_data.z;
}
