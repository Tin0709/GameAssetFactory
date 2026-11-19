shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D smoke_mask : filter_nearest, repeat_disable;
uniform vec4 dust_tint : source_color;
uniform float alpha_curve[54];
uniform float alpha_duration;
uniform float camera_range_squared;
uniform float source_step_seconds;
uniform bool crop_smoke_atlas = false;
uniform vec4 cell_bounds[32];
// Integer physics tick modulo 2048, interpolation offset in ticks, seconds per tick.
uniform vec3 contact_clock;
varying flat vec3 sprite_data;

void vertex() {
	// Cell, contact tick modulo 2048, lifetime and drag are fixed for each puff.
	float cell = INSTANCE_CUSTOM.x;
	float lifetime = INSTANCE_CUSTOM.z;
	float drag = INSTANCE_CUSTOM.w;
	float age = max(mod(contact_clock.x - INSTANCE_CUSTOM.y, 2048.0) + contact_clock.y, 0.0) * contact_clock.z;
	// Match the player's semi-implicit velocity solve and tick interpolation.
	float tick = floor(age / source_step_seconds);
	float divisor = 1.0 + drag * source_step_seconds;
	float decay = pow(divisor, -tick);
	float inv_drag = 1.0 / drag;
	float travel = (1.0 - decay) * inv_drag + (age - tick * source_step_seconds) * decay / divisor;
	float lift = (age - travel) * inv_drag;
	vec4 origin = MODEL_MATRIX[3] + MODEL_MATRIX[1] * lift;
	vec3 to_camera = origin.xyz - CAMERA_POSITION_WORLD;
	if (dot(to_camera, to_camera) > camera_range_squared) {
		// Cull the rendered puff without discarding its remaining lifetime.
		POSITION = vec4(2.0, 2.0, 0.0, 1.0);
	} else {
		vec3 sprite_vertex = VERTEX;
		if (crop_smoke_atlas) {
			vec4 bounds = cell_bounds[int(cell)];
			vec2 center = (bounds.xy + bounds.zw) * 0.5 - vec2(0.5);
			sprite_vertex.xy = VERTEX.xy * (bounds.zw - bounds.xy) + vec2(center.x, -center.y);
			UV = mix(bounds.xy, bounds.zw, UV);
		}
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], origin) * vec4(sprite_vertex, 1.0);
	}
	float cursor = clamp(age / (lifetime * alpha_duration), 0.0, 1.0) * 53.0;
	int sample = int(cursor);
	float opacity = mix(alpha_curve[sample], alpha_curve[min(sample + 1, 53)], fract(cursor));
	sprite_data = vec3(mod(cell, 8.0), floor(cell / 8.0), opacity);
}

void fragment() {
	vec2 uv = (UV + sprite_data.xy) / vec2(8.0, 4.0);
	ALBEDO = dust_tint.rgb;
	ALPHA = texture(smoke_mask, uv).a * sprite_data.z;
}
