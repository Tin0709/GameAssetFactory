shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D smoke_mask : filter_nearest, repeat_disable;
uniform vec4 dust_tint : source_color;
uniform float camera_range_squared;
uniform bool crop_smoke_atlas = false;
uniform vec4 cell_bounds[32];
varying flat vec3 sprite_data;

void vertex() {
	float cell = INSTANCE_CUSTOM.x;
	if (crop_smoke_atlas) {
		vec4 bounds = cell_bounds[int(cell)];
		vec2 center = (bounds.xy + bounds.zw) * 0.5 - vec2(0.5);
		VERTEX.xy = VERTEX.xy * (bounds.zw - bounds.xy) + vec2(center.x, -center.y);
		UV = mix(bounds.xy, bounds.zw, UV);
	}
	VERTEX.xy *= INSTANCE_CUSTOM.z;
	vec3 to_camera = MODEL_MATRIX[3].xyz - CAMERA_POSITION_WORLD;
	if (dot(to_camera, to_camera) > camera_range_squared) {
		VERTEX = vec3(0.0);
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	sprite_data = vec3(mod(cell, 8.0), floor(cell / 8.0), INSTANCE_CUSTOM.y);
}

void fragment() {
	vec2 uv = (UV + sprite_data.xy) / vec2(8.0, 4.0);
	ALBEDO = dust_tint.rgb;
	ALPHA = texture(smoke_mask, uv).a * sprite_data.z;
}
