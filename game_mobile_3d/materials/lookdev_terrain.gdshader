shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D root_shade : filter_linear, repeat_disable;
uniform vec3 player_position;
varying vec3 world_position;
varying float top;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top = step(0.7, NORMAL.y);
}

void fragment() {
	vec3 source = texture(atlas, UV).rgb;
	// Compress the repeating atlas speckle contrast without replacing its pixel detail.
	source = mix(source, mix(source, vec3(0.16, 0.29, 0.075), 0.65), top);
	vec2 p = world_position.xz;
	float field = sin(p.x * 0.24 + sin(p.y * 0.21)) * sin(p.y * 0.17 - 0.7);
	vec2 pixel = floor(p * 5.0);
	float grain = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 tint = mix(vec3(0.58, 0.76, 0.67), vec3(0.86, 0.90, 0.69), field * 0.5 + 0.5);
	float roots = texture(root_shade, (p + 20.0) / 40.0).r;
	float contact = 1.0 - smoothstep(0.16, 0.63, length((p - player_position.xz) / vec2(1.0, 0.78)));
	float grounding = (1.0 - roots * 0.24) * (1.0 - contact * 0.26);
	vec3 top_color = source * tint * (0.97 + grain * 0.06) * grounding;
	// A restrained cool earth tint makes the block sides readable at the boundary.
	vec3 side_color = source * vec3(0.90, 0.89, 0.85);
	ALBEDO = mix(side_color, top_color, top);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
