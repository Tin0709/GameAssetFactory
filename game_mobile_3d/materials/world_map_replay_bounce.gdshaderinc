// Bounded bounce for the decorative Arena Replay statue.
global uniform vec4 gaf_replay_bounce;

vec3 gaf_replay_incident(vec3 world_position, vec3 normal) {
	if (gaf_replay_bounce.w <= 0.0) {
		return vec3(0.0);
	}
	vec3 toward = gaf_replay_bounce.xyz - world_position;
	float distance_squared = dot(toward, toward);
	float fade = max(1.0 - distance_squared / (3.9 * 3.9), 0.0);
	float facing = max(dot(normal, toward) * inversesqrt(max(distance_squared, 0.2)), 0.0);
	return vec3(1.0, 0.29, 0.02) * (gaf_replay_bounce.w * fade * fade * (0.078 + 0.922 * facing));
}
