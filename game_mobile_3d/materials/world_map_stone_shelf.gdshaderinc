global uniform vec3 gaf_stone_shelf_state;
global uniform sampler2D gaf_stone_shelf_field : filter_nearest, repeat_disable;

float gaf_stone_shelf_multiplier(vec2 world_xz) {
	if (gaf_stone_shelf_state.z <= 0.0) return 1.0;
	vec2 grid_position = world_xz - gaf_stone_shelf_state.xy;
	ivec2 cell = ivec2(floor(grid_position));
	ivec2 size = textureSize(gaf_stone_shelf_field, 0);
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, size))) return 1.0;

	// Each texel keeps four corner values. Adjacent shelves at the same height share their edge values.
	vec4 corners = texelFetch(gaf_stone_shelf_field, cell, 0);
	vec2 t = fract(grid_position);
	float weight = mix(mix(corners.r, corners.g, t.x), mix(corners.b, corners.a, t.x), t.y);
	return 1.0 + gaf_stone_shelf_state.z * ((255.0 * weight - 128.0) / 127.0);
}
