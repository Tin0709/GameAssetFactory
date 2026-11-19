vec3 health_bar_colour(vec2 uv, vec2 ratios) {
	vec2 interior = (uv - vec2(0.025, 0.19)) / vec2(0.95, 0.62);
	bool inside = all(greaterThanEqual(interior, vec2(0.0))) && all(lessThanEqual(interior, vec2(1.0)));
	vec3 fill = mix(vec3(0.70, 0.035, 0.04), vec3(1.0, 0.24, 0.11), 1.0 - interior.y);
	vec3 track = interior.x < ratios.y ? vec3(0.98, 0.70, 0.28) : vec3(0.12, 0.04, 0.05);
	return inside ? (interior.x < ratios.x ? fill : track) : vec3(0.03, 0.017, 0.023);
}
