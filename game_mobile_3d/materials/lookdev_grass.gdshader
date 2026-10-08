shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

varying vec3 root_position;
varying float blade_height;
varying float patch_variation;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_strength : hint_range(0.0, 2.0) = 1.0;
uniform float wind_phase = 0.0;
uniform float interaction_radius : hint_range(0.2, 1.5) = 0.90;
uniform float review_wind_gain : hint_range(1.0, 4.0) = 3.0;
uniform float review_interaction_gain : hint_range(1.0, 3.0) = 1.85;
uniform float review_max_bend : hint_range(0.1, 0.25) = 0.18;
uniform vec4 motion_start[8]; // start XZ, age from birth, tip strength (metres)
uniform vec4 motion_end[8];   // end XZ, age from last movement, attack seconds

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
		// Soft normalization also stays continuous when outward and forward push cancel.
		direction /= sqrt(dot(direction, direction) + 0.15 * 0.15);
		total += direction * weight * motion_start[i].w;
		total_weight += weight;
	}
	// Overlapping path samples do not multiply bend amplitude.
	return total / max(1.0, total_weight);
}

void vertex() {
	// glTF flips Blender UV V while converting geometry Y to Godot -Z.
	// Imported UV2 therefore encodes Godot root XZ directly as (root + 0.5).
	vec3 local_root = vec3(UV2.x - 0.5, 0.0, UV2.y - 0.5);
	vec3 world_root = (MODEL_MATRIX * vec4(local_root, 1.0)).xyz;
	root_position = world_root;
	float t = COLOR.g;
	blade_height = t;
	patch_variation = INSTANCE_CUSTOM.r;
	float bend_mask = COLOR.r;
	vec2 direction = wind_direction / max(length(wind_direction), 0.0001);
	vec2 crosswind = vec2(-direction.y, direction.x);
	float spatial_phase = sin(dot(world_root.xz, vec2(0.19, 0.13))) * 0.16;
	float variation = mix(0.92, 1.08, INSTANCE_CUSTOM.r);
	// Approved four-second Blender loop: 1.8cm along wind, 0.7cm crosswind.
	vec2 breeze = (direction * 0.018 * sin(wind_phase + spatial_phase - 0.28 * t)
		- crosswind * 0.007 * sin(wind_phase + spatial_phase + PI / 3.0 - 0.23 * t)) * wind_strength * variation;
	vec2 offset = (breeze * review_wind_gain + player_bend(world_root.xz) * review_interaction_gain) * bend_mask;
	// Keep short v4 leaves within a 30-degree maximum deflection.
	float safe_bend = min(review_max_bend, VERTEX.y * 0.5);
	offset *= min(1.0, safe_bend / max(length(offset), 0.0001));
	// Convert world bend through the instance basis; rotations keep shared wind coherent.
	// Patch X/Z scales are unity, so transpose is the cheaper inverse for XZ wind.
	vec3 local_offset = transpose(mat3(MODEL_MATRIX)) * vec3(offset.x, 0.0, offset.y);
	float height = VERTEX.y;
	VERTEX.xz += local_offset.xz;
	// Mild arc shortening prevents a visibly stretched root-to-tip silhouette.
	VERTEX.y = sqrt(max(height * height - dot(local_offset.xz, local_offset.xz), 0.0));
	vec2 slope = 2.0 * local_offset.xz / max(height, 0.05);
	NORMAL = normalize(vec3(NORMAL.x + slope.x * NORMAL.y,
		NORMAL.y - dot(slope, NORMAL.xz), NORMAL.z + slope.y * NORMAL.y));
}

void fragment() {
	vec3 source = texture(atlas, UV).rgb;
	float field = sin(root_position.x * 0.24 + sin(root_position.z * 0.21)) * sin(root_position.z * 0.17 - 0.7);
	// Authored v4 meadow colors stay intact: only restrained cool/sunlit variation.
	vec3 palette = mix(vec3(0.81, 0.94, 1.04), vec3(1.06, 1.04, 0.93), field * 0.5 + 0.5);
	float root_to_tip = mix(0.94, 1.04, smoothstep(0.0, 1.0, blade_height));
	ALBEDO = source * palette * root_to_tip * mix(0.96, 1.04, patch_variation);
	// Both sides receive useful sky/key light. Upward bias preserves blade facets
	// while avoiding nearly black backface triangles on the gameplay camera.
	vec3 face_normal = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(mix(face_normal, up_view, 0.58));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
