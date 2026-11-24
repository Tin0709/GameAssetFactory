shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;

uniform sampler2D mark_mask : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform mat4 world_to_floor;
uniform vec4 floor_bounds;
varying vec2 floor_position;

void vertex() {
	floor_position = (world_to_floor * MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	if (any(lessThan(floor_position, floor_bounds.xy)) || any(greaterThan(floor_position, floor_bounds.zw))) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = texture(mark_mask, UV).a * tint.a;
}
