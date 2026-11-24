shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float opacity_scale = 1.0;

void fragment() {
	// Niagara multiplies the initial RGB of 10 by the Polaris User.Color.
	// Map that HDR color into the Lab's display range without clipping its hue.
	vec3 source_rgb = vec3(12.0370483, 17.9309952, 20.0);
	vec3 color = source_rgb / 20.0;
	float opacity = COLOR.a;
	if (COLOR.g < 0.5) {
		// The charged Bow reuses the ribbon with a distinct center and rim.
		// Its look is authored for the Lab. The native charged emitter is unavailable.
		float center = 1.0 - abs(UV.x * 2.0 - 1.0);
		float core = smoothstep(0.48, 0.88, center);
		color = mix(color, vec3(0.94, 0.98, 1.0), core);
		opacity *= smoothstep(0.0, 0.24, center) * mix(0.65, 1.0, core);
	}
	ALBEDO = color;
	ALPHA = opacity * opacity_scale;
}
