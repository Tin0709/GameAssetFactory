shader_type spatial;
render_mode specular_disabled;

uniform sampler2DArray tiles : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_source_tiles = false;
varying vec3 block_position;
varying vec3 face_normal;

void vertex() {
	block_position = VERTEX;
	face_normal = NORMAL;
}

void fragment() {
	bool top = face_normal.y > 0.5;
	bool bottom = face_normal.y < -0.5;
	if (use_source_tiles) {
		if (top || bottom) {
			ALBEDO = texture(tiles, vec3(block_position.x, -block_position.z, top ? 0.0 : 2.0)).rgb;
		} else {
			float across = abs(face_normal.x) > 0.5 ? block_position.z : block_position.x;
			float down = clamp(0.5 - block_position.y, 0.03125, 0.96875);
			ALBEDO = texture(tiles, vec3(across, down, 1.0)).rgb;
		}
	} else {
		ALBEDO = top ? vec3(0.16, 0.29, 0.065) : vec3(0.20, 0.115, 0.06);
	}
	ROUGHNESS = 1.0;
}
