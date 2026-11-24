shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float charge_age = 0.0;
varying float onset;

void vertex() {
	onset = 1.0 - smoothstep(0.0, 0.14, charge_age);
	// Keep the small glint facing the display camera with normal depth testing.
	vec3 center = MODELVIEW_MATRIX[3].xyz;
	vec2 offset = VERTEX.xy * mix(0.66, 1.0, onset);
	POSITION = PROJECTION_MATRIX * vec4(center + vec3(offset, 0.0), 1.0);
}

void fragment() {
	vec2 cell = abs(floor(UV * 11.0) - vec2(5.0));
	float distance = cell.x + cell.y;
	float core = 1.0 - step(1.5, distance);
	float rays = (1.0 - step(0.5, min(cell.x, cell.y))) * (1.0 - smoothstep(2.0, 5.0, distance));
	float glow = (1.0 - smoothstep(1.0, 6.0, distance)) * 0.28;
	ALBEDO = mix(vec3(0.12, 0.91, 1.5), vec3(1.65, 1.75, 1.8), core);
	ALPHA = max(core, max(rays * 0.82, glow)) * mix(0.74, 1.0, onset);
}
