// Test the finite segment from the emitter to a pixel in a box's local XZ plane.
bool lab_box_occludes(vec2 centre, vec2 direction, vec2 extent) {
	vec2 inverse_direction = (step(vec2(0.0), direction) * 2.0 - 1.0) / max(abs(direction), vec2(0.000001));
	vec2 lower = (-extent - centre) * inverse_direction;
	vec2 upper = (extent - centre) * inverse_direction;
	vec2 entry = min(lower, upper);
	vec2 exit = max(lower, upper);
	return max(0.0, max(entry.x, entry.y)) <= min(1.0, min(exit.x, exit.y));
}
