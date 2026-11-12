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

float outline_strip(float distance, float world_per_pixel) {
	float pixels = abs(distance) / max(world_per_pixel, 0.00001);
	return 1.0 - smoothstep(max(terrain_outline_width - 0.55, 0.0),
		terrain_outline_width + 0.45, pixels);
}

float outline_top_edge(ivec2 neighbour, float height, float coverage) {
	if (coverage <= 0.0) return 0.0;
	vec2 column = outline_column(neighbour);
	float step_height = height - column.x;
	if (column.y <= 0.0 || abs(step_height) <= 0.01) return 0.0;
	return coverage * (step_height > 0.0 ? 1.0 : 0.46);
}

float terrain_outline(vec3 world, vec3 normal) {
	if (terrain_outline_strength <= 0.0 || path_map_size.x <= 0.0 || normal.y < -0.9) return 1.0;
	vec3 pixel = length(vec2(dFdx(world.x), dFdy(world.x))) * vec3(1.0, 0.0, 0.0)
		+ length(vec2(dFdx(world.y), dFdy(world.y))) * vec3(0.0, 1.0, 0.0)
		+ length(vec2(dFdx(world.z), dFdy(world.z))) * vec3(0.0, 0.0, 1.0);
	vec2 grid = world.xz - path_map_origin;
	float edge = 0.0;
	if (normal.y > 0.9) {
		ivec2 cell = ivec2(floor(grid));
		vec2 local = fract(grid);
		vec2 side = step(vec2(0.5), local) * 2.0 - 1.0;
		edge = max(
			outline_top_edge(cell + ivec2(int(side.x), 0), world.y, outline_strip(min(local.x, 1.0 - local.x), pixel.x)),
			outline_top_edge(cell + ivec2(0, int(side.y)), world.y, outline_strip(min(local.y, 1.0 - local.y), pixel.z)));
	} else if (max(abs(normal.x), abs(normal.z)) > 0.9) {
		ivec2 outward = ivec2(round(normal.xz));
		ivec2 cell = ivec2(floor(grid - vec2(outward) * 0.002));
		vec2 wall = outline_column(cell);
		vec2 floor_column = outline_column(cell + outward);
		if (wall.y <= 0.0 || floor_column.y <= 0.0 || wall.x <= floor_column.x + 0.01
				|| world.y < floor_column.x - 0.002) return 1.0;
		float top_edge = outline_strip(wall.x - world.y, pixel.y) * 0.72;
		float base_edge = outline_strip(world.y - floor_column.x, pixel.y) * 0.44;
		edge = max(top_edge, base_edge);
	}
	return 1.0 + terrain_outline_strength * 0.56 * edge;
}
