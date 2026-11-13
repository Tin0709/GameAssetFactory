// Only the terrain materials include this. Coverage follows real height
// changes between map columns and excludes edges against empty space.
uniform float terrain_outline_strength = 0.0;
uniform float terrain_outline_width = 1.0;

vec2 outline_column(ivec2 cell) {
	ivec2 extent = ivec2(path_map_size);
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, extent))) {
		return vec2(0.0);
	}
	return texelFetch(path_surface_map, cell, 0).ga;
}

float outline_strip(float distance, float world_per_pixel, float footprint) {
	// Average the strip coverage over the projected pixel footprint.
	float half_pixel = max(footprint * 0.5, 0.00001);
	return clamp((terrain_outline_width * world_per_pixel - abs(distance) + half_pixel) / (2.0 * half_pixel), 0.0, 1.0);
}

// A lower column can be hidden behind a higher one. Follow the camera ray
// along the step to distinguish a visible interior join from a skyline.
bool outline_has_terrain_behind(vec3 point, vec3 ray) {
	ivec2 cell = ivec2(floor(point.xz));
	ivec2 stride = ivec2(sign(ray.xz));
	vec2 interval = 1.0 / max(abs(ray.xz), vec2(0.00001));
	vec2 local = fract(point.xz);
	vec2 next_hit = mix(local, 1.0 - local, step(vec2(0.0), ray.xz)) * interval;
	for (int i = 0; i < 32; i++) {
		vec2 column = outline_column(cell);
		if (column.y <= 0.0) return false;
		float end = min(next_hit.x, next_hit.y);
		if (point.y + ray.y * end <= column.x + 0.002) return true;
		if (next_hit.x < next_hit.y) {
			cell.x += stride.x;
			next_hit.x += interval.x;
		} else {
			cell.y += stride.y;
			next_hit.y += interval.y;
		}
	}
	return false;
}

float outline_top_edge(ivec2 cell, ivec2 outward, vec3 point, vec3 ray, float coverage) {
	if (coverage <= 0.0) return 0.0;
	vec2 column = outline_column(cell + outward);
	float step_height = point.y - column.x;
	if (column.y <= 0.0 || abs(step_height) <= 0.01) return 0.0;
	if (step_height > 0.0 && dot(ray.xz, vec2(outward)) > 0.00001) {
		vec2 border = vec2(cell) + max(vec2(outward), vec2(0.0));
		vec2 axis = abs(vec2(outward));
		point.xz = mix(point.xz, border, axis) + vec2(outward) * 0.0001;
		if (!outline_has_terrain_behind(point, ray)) return 0.0;
	}
	return coverage * (step_height > 0.0 ? 1.0 : 0.46);
}

float terrain_outline(vec3 world, vec3 normal, vec3 ray) {
	if (terrain_outline_strength <= 0.0 || path_map_size.x <= 0.0 || normal.y < -0.9) return 1.0;
	vec3 dx = dFdx(world);
	vec3 dy = dFdy(world);
	vec3 pixel = sqrt(dx * dx + dy * dy);
	vec3 footprint = abs(dx) + abs(dy);
	vec2 grid = world.xz - path_map_origin;
	float edge = 0.0;
	if (normal.y > 0.9) {
		ivec2 cell = ivec2(floor(grid));
		vec2 local = fract(grid);
		vec2 side = step(vec2(0.5), local) * 2.0 - 1.0;
		vec3 point = vec3(grid.x, world.y, grid.y);
		edge = max(
			outline_top_edge(cell, ivec2(int(side.x), 0), point, ray, outline_strip(min(local.x, 1.0 - local.x), pixel.x, footprint.x)),
			outline_top_edge(cell, ivec2(0, int(side.y)), point, ray, outline_strip(min(local.y, 1.0 - local.y), pixel.z, footprint.z)));
	} else if (max(abs(normal.x), abs(normal.z)) > 0.9) {
		ivec2 outward = ivec2(round(normal.xz));
		ivec2 cell = ivec2(floor(grid - vec2(outward) * 0.002));
		vec2 wall = outline_column(cell);
		vec2 floor_column = outline_column(cell + outward);
		if (wall.y <= 0.0 || floor_column.y <= 0.0 || wall.x <= floor_column.x + 0.01
				|| world.y < floor_column.x - 0.002) return 1.0;
		float top_edge = outline_strip(wall.x - world.y, pixel.y, footprint.y) * 0.72;
		float base_edge = outline_strip(world.y - floor_column.x, pixel.y, footprint.y) * 0.44;
		edge = max(top_edge, base_edge);
	}
	return 1.0 + terrain_outline_strength * 0.56 * edge;
}
