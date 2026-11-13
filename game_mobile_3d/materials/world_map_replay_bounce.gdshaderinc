// Bounded bounce for the decorative Arena Replay statue.
global uniform vec4 gaf_replay_bounce;
global uniform vec4 gaf_replay_surface;
global uniform sampler3D gaf_replay_surface_field : filter_linear, repeat_disable;

vec3 gaf_replay_incident(vec3 world_position, vec3 normal) {
	if (gaf_replay_bounce.w <= 0.0) {
		return vec3(0.0);
	}
	vec3 toward = gaf_replay_bounce.xyz - world_position;
	float distance_squared = dot(toward, toward);
	float fade = max(1.0 - distance_squared / (3.9 * 3.9), 0.0);
	float facing = max(dot(normal, toward) * inversesqrt(max(distance_squared, 0.2)), 0.0);
	float legacy = gaf_replay_bounce.w * fade * fade * (0.078 + 0.922 * facing);
	if (gaf_replay_surface.w > 0.0 && distance_squared < 39.0625) {
		ivec3 texels = textureSize(gaf_replay_surface_field, 0);
		float face_height = float(texels.y / 6);
		vec3 grid = (world_position - gaf_replay_surface.xyz) * 4.0;
		vec3 axes = abs(normal);
		if (max(max(axes.x, axes.y), axes.z) > 0.9 &&
			all(greaterThanEqual(grid, vec3(0.0))) &&
			all(lessThanEqual(grid, vec3(float(texels.x), face_height, float(texels.z)) - 1.0))) {
			int face = axes.y > 0.9 ? (normal.y > 0.0 ? 0 : 1) :
				(axes.x > 0.9 ? (normal.x > 0.0 ? 2 : 3) : (normal.z > 0.0 ? 4 : 5));
			vec3 index = grid + 0.5 * axes;
			index.y += float(face) * face_height;
			vec2 field = textureLod(gaf_replay_surface_field, index / vec3(texels), 0.0).rg;
			float baked = 4.0 * field.r * field.r * gaf_replay_bounce.w;
			legacy = mix(legacy, baked,
				gaf_replay_surface.w * smoothstep(0.15, 0.85, field.g));
		}
	}
	return vec3(1.0, 0.29, 0.02) * legacy;
}
