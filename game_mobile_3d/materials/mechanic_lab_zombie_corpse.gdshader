shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin : source_color, filter_nearest, repeat_disable;
instance uniform float desaturation = 0.0;
instance uniform float dissolve = 0.0;
instance uniform float fragment_travel = 0.0;
uniform vec3 fragment_directions[19];

float noise_cell(vec2 cell) {
	vec3 seed = fract(vec3(cell.xyx) * 0.1031);
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

void vertex() {
	if (fragment_travel > 0.0) {
		VERTEX += fragment_directions[min(BONE_INDICES.x, 18u)] * fragment_travel;
	}
}

void fragment() {
	// Use atlas coordinates so the breakup remains attached to the ragdoll.
	vec2 pixel = UV * vec2(textureSize(skin, 0));
	float breakup = noise_cell(floor(pixel * 0.5)) * 0.42
		+ noise_cell(floor(pixel * 0.19)) * 0.58;
	if (breakup < dissolve) {
		discard;
	}
	vec3 color = texture(skin, UV).rgb;
	float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(color, vec3(gray), desaturation);
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
}
