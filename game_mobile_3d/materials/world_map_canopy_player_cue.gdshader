shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_inverted, cull_back;
stencil_mode read, compare_equal, 122;

uniform sampler2D opacity_texture : filter_nearest, repeat_disable;
uniform float cutoff = 0.0;
uniform float cue_weight : hint_range(0.0, 1.0) = 0.0;
uniform float day_tone_weight : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	vec4 view_vertex = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view_vertex;
	// Test a modest gap to avoid showing the player's hidden surfaces through the player.
	// Keep the actual silhouette position and size.
	vec4 nearer = PROJECTION_MATRIX * (view_vertex + vec4(0.0, 0.0, 0.8, 0.0));
	POSITION = vec4(clip.xy, (nearer.z / nearer.w) * clip.w, clip.w);
}

void fragment() {
	if (cutoff > 0.0 && texture(opacity_texture, UV).a < cutoff) {
		discard;
	}
	ALBEDO = mix(vec3(0.030, 0.047, 0.068), vec3(0.031, 0.044, 0.047), day_tone_weight);
	ALPHA = 0.52 * cue_weight;
}
