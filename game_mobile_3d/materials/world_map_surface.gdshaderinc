// Scene-local, reversible grade of authored texels. No replacement texture/UV.
uniform int ground_grade = 0; // 1 grass/dirt, 2 dirt, 3 mineral
uniform float texture_contrast = 0.58;
vec3 shade_world_surface(vec3 source) {
	if (ground_grade == 0) return source;
	bool green = source.g > source.r * 1.13 && source.g > source.b * 1.35;
	vec3 center = vec3(0.24, 0.15, 0.065);
	vec3 target = vec3(0.245, 0.171, 0.082);
	if (ground_grade == 1 && green) {
		center = vec3(0.0856, 0.2168, 0.0342);
		target = vec3(0.120, 0.190, 0.067);
	} else if (ground_grade == 3) {
		center = vec3(0.24, 0.27, 0.27);
		target = vec3(0.180, 0.230, 0.245);
	}
	return max(vec3(0.0), target + (source - center) * texture_contrast);
}
