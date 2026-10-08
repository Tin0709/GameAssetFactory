shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec3 player_position;
uniform bool dirt_surface = false;
varying vec3 world_position;
varying float top;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top = step(0.7, NORMAL.y);
}

void fragment() {
	vec2 p = world_position.xz;
	vec3 source = texture(atlas, UV).rgb;
	// Sample the authored meadow tile in an irregular world-pixel order. This
	// retains its palette/detail while removing repeated diagonal atlas stamps.
	vec2 pixel = floor(p * 8.0);
	vec2 random_uv = fract(sin(vec2(dot(pixel, vec2(12.9898, 78.233)), dot(pixel, vec2(39.346, 11.135)))) * 43758.5453);
	if (top > 0.5 && !dirt_surface) {
		source = texture(atlas, vec2(0.36) + random_uv * 0.26).rgb;
	}
	// Slow irregular color fields break tile repetition without an XZ diamond grid.
	float field = sin(p.x * 0.24 + sin(p.y * 0.21)) * sin(p.y * 0.17 - 0.7);
	float grain = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 tint = mix(vec3(0.79, 0.93, 1.04), vec3(1.06, 1.04, 0.93), field * 0.5 + 0.5);
	if (dirt_surface) { tint = mix(vec3(0.92, 0.96, 1.02), vec3(1.05, 1.02, 0.94), field * 0.5 + 0.5); }
	float contact = 1.0 - smoothstep(0.16, 0.59, length((p - player_position.xz) / vec2(1.0, 0.78)));
	vec3 top_color = source * tint * (0.985 + grain * 0.03) * (1.0 - contact * 0.22);
	vec3 side_color = source * vec3(0.94, 0.96, 1.0);
	ALBEDO = mix(side_color, top_color, top);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
