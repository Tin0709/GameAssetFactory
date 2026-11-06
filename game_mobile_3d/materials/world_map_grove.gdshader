shader_type spatial;

uniform bool reveal_player = false;
uniform vec3 player_view;
uniform float surface_specular = 0.24;

void fragment() {
	if (reveal_player) {
		// WorldMap uses an orthographic camera. Keep the opening centred on
		// the player even while the camera holds its elevation during a jump.
		vec3 offset = VERTEX - player_view;
		vec2 extent = abs(offset.xy) / vec2(0.70, 1.16);
		float distance_to_player = length(max(extent - 0.48, vec2(0.0)));
		if (offset.z > 0.01 && distance_to_player < 0.80) {
			float opacity = smoothstep(0.35, 0.80, distance_to_player);
			float threshold = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
			if (opacity <= threshold) discard;
		}
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = surface_specular;
}
