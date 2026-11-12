global uniform vec4 gaf_player_sole_left;
global uniform vec4 gaf_player_sole_right;
global uniform vec3 gaf_player_sole_camera;

float gaf_sole_occlusion(vec3 point, vec4 foot) {
	vec3 delta = point - foot.xyz;
	float radial = 1.0 - smoothstep(0.12 * 0.12, 0.66 * 0.66, dot(delta.xz, delta.xz));
	float vertical = 1.0 - smoothstep(0.07, 0.38, abs(delta.y));
	return foot.w * radial * vertical;
}

float gaf_player_contact(vec3 point, vec3 camera_position) {
	if (max(gaf_player_sole_left.w, gaf_player_sole_right.w) <= 0.0) return 1.0;
	vec3 camera_delta = camera_position - gaf_player_sole_camera;
	if (dot(camera_delta, camera_delta) > 0.0001) return 1.0;
	return 1.0 - max(gaf_sole_occlusion(point, gaf_player_sole_left), gaf_sole_occlusion(point, gaf_player_sole_right));
}
