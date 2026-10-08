shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_strength : hint_range(0.0, 2.0) = 1.0;
uniform float wind_phase = 0.0;
uniform float interaction_radius : hint_range(0.2, 1.5) = 0.85;
uniform float interaction_gain : hint_range(0.0, 3.0) = 1.3;
uniform float max_head_bend : hint_range(0.0, 0.2) = 0.12;
uniform vec4 motion_start[8];
uniform vec4 motion_end[8];

vec2 player_bend(vec2 root) {
	vec2 total = vec2(0.0);
	float total_weight = 0.0;
	for (int i = 0; i < 8; i++) {
		if (motion_start[i].w <= 0.0 || motion_end[i].z >= 0.8) { continue; }
		vec2 segment = motion_end[i].xy - motion_start[i].xy;
		float length_squared = dot(segment, segment);
		float along = clamp(dot(root - motion_start[i].xy, segment) / max(length_squared, 0.000001), 0.0, 1.0);
		vec2 away = root - (motion_start[i].xy + segment * along);
		float distance_to_path = length(away);
		float falloff = 1.0 - smoothstep(0.0, interaction_radius, distance_to_path);
		float attack = smoothstep(0.0, motion_end[i].w, motion_start[i].z);
		float recovery = 1.0 - smoothstep(0.12, 0.8, motion_end[i].z);
		float weight = falloff * attack * recovery;
		vec2 movement = segment / max(sqrt(length_squared), 0.0001);
		vec2 direction = away / max(distance_to_path, 0.05) + movement * 0.45;
		direction /= sqrt(dot(direction, direction) + 0.15 * 0.15);
		total += direction * weight * motion_start[i].w;
		total_weight += weight;
	}
	return total / max(1.0, total_weight);
}

vec3 turn(vec3 point, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return point * c + cross(axis, point) * s + axis * dot(axis, point) * (1.0 - c);
}

void vertex() {
	// UV0: normalized attachment height, 1 - shared head height after glTF V flip. Every petal/center
	// uses mask 1. UV2: the individual flower's root XZ + .5 after Godot import.
	vec3 local_root = vec3(UV2.x - 0.5, 0.0, UV2.y - 0.5);
	vec3 world_root = (MODEL_MATRIX * vec4(local_root, 1.0)).xyz;
	vec2 direction = wind_direction / max(length(wind_direction), 0.0001);
	vec2 crosswind = vec2(-direction.y, direction.x);
	float phase = wind_phase + sin(dot(world_root.xz, vec2(0.19, 0.13))) * 0.16;
	vec2 breeze = (direction * 0.014 * sin(phase)
		- crosswind * 0.006 * sin(phase + PI / 3.0)) * wind_strength;
	vec2 bend = breeze + player_bend(world_root.xz) * interaction_gain;
	float magnitude = length(bend);
	// Instances retain unit scale. Bound head-centre travel and tilt at 30 degrees.
	float head_height = max(1.0 - UV.y, 0.001);
	float travel = min(magnitude, min(max_head_bend, head_height * 0.5));
	float angle = asin(travel / head_height) * clamp(UV.x, 0.0, 1.0);
	vec3 local_direction = transpose(mat3(MODEL_MATRIX)) * vec3(bend.x, 0.0, bend.y) / max(magnitude, 0.000001);
	vec3 axis = vec3(local_direction.z, 0.0, -local_direction.x);
	// A shared rotation keeps the complete head rigid: no detached yellow center
	// or per-petal stretching. Stem rings curve; each leaf has one attachment mask.
	if (magnitude > 0.000001) {
		VERTEX = local_root + turn(VERTEX - local_root, axis, angle);
		NORMAL = normalize(turn(NORMAL, axis, angle));
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
