shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float history_span = 1.0;
uniform float finisher = 0.0;
void fragment() {
	float age_fade = pow(max(0.0, 1.0 - UV.x / history_span), 1.7);
	float tip_edge = smoothstep(0.88, 0.98, UV.y);
	float leading = 1.0 - smoothstep(0.0, 0.09, UV.x);
	float lower_edge = smoothstep(0.0, 0.17, UV.y);
	float core = max(tip_edge * 0.8, leading * 0.72);
	vec3 gold = mix(vec3(1.0, 0.61, 0.18), vec3(1.0, 0.94, 0.76), core);
	ALBEDO = gold;
	EMISSION = gold * (0.30 + core * 0.72 + finisher * 0.18);
	ALPHA = opacity * age_fade * lower_edge * (0.105 + core * 0.62);
}
