shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D source_slash : filter_linear, repeat_disable;
uniform bool use_source_slash = false;

void fragment() {
	float hot = smoothstep(0.09, 0.34, COLOR.a);
	float edge = smoothstep(0.36, 0.94, UV.x);
	float opacity = mix(0.18, 1.0 + hot * 0.50, edge);
	if (use_source_slash) {
		// The source arc occupies a sector in the lower-right of the atlas.
		// Sample it from the bright head of the ribbon to the older tail.
		float angle = radians(mix(44.0, 107.0, UV.y));
		float radius = mix(0.30, 0.64, UV.x);
		vec2 atlas_uv = vec2(0.5) + vec2(cos(angle), sin(angle)) * radius;
		edge = texture(source_slash, atlas_uv).a / (135.0 / 255.0);
		opacity = edge * (1.0 + hot * 0.50);
	}
	ALBEDO = COLOR.rgb * (1.0 + hot * edge * 5.0);
	ALPHA = COLOR.a * opacity;
}
