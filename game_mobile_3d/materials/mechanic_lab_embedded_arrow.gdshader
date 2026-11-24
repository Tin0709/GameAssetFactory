shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D arrow_texture : source_color, filter_nearest;
uniform float pivot_x;
varying float receiver_distance;

void vertex() {
	// Each instance's contact is its local pivot. Subtract the pivot
	// before applying its orientation, so wobble preserves the plane.
	vec3 relative = mat3(MODEL_MATRIX) * (VERTEX - vec3(pivot_x, 0.0, 0.0));
	receiver_distance = dot(INSTANCE_CUSTOM.xyz, relative);
}

void fragment() {
	if (receiver_distance < -0.0005) {
		discard;
	}
	ALBEDO = texture(arrow_texture, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
}
