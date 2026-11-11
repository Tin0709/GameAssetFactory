// Optional private albedo preview. Keep the hashed base surface recipe independent.
uniform bool use_source_terrain = false;
uniform sampler2DArray source_terrain_tiles : source_color, filter_linear_mipmap, repeat_enable;

vec3 source_terrain_sample(vec2 uv, float layer) {
	return texture(source_terrain_tiles, vec3(uv, layer)).rgb;
}

vec3 source_terrain_color(vec3 world, vec3 normal) {
	bool horizontal = abs(normal.y) > 0.9;
	vec2 uv = horizontal ? vec2(world.x, -world.z) :
		vec2(abs(normal.x) > 0.9 ? -world.z * sign(normal.x) : world.x * sign(normal.z), world.y);
	float layer = ground_grade == 3 ? 4.0 : (normal.y > 0.9 ? 3.0 : 2.0);
	if (ground_grade == 1) {
		layer = normal.y > 0.9 ? 0.0 : (horizontal ? 2.0 : 1.0);
		if (!horizontal) {
			// Keep the bottom earth row out of the top grass edge.
			vec2 bounded = vec2(uv.x, clamp(fract(uv.y), 0.03125, 0.96875));
			return textureGrad(source_terrain_tiles, vec3(bounded, layer), dFdx(uv), dFdy(uv)).rgb;
		}
	}
	vec3 base = source_terrain_sample(uv, layer);
	if (!path_blending || normal.y < 0.9 || ground_grade == 3) return base;

	// Follow the existing layout's shoulder coverage with source albedo on both sides.
	vec2 grid = floor(world.xz) - path_map_origin;
	if (any(lessThan(grid, vec2(0.0))) || any(greaterThanEqual(grid, path_map_size))) return base;
	vec4 field = texture(path_surface_map, (grid + 0.5) / path_map_size);
	int mask = int(round(field.r)) & 255;
	if (mask == 0 || abs(field.g - world.y) > 0.02) return base;

	vec2 local = fract(world.xz);
	float distance_to_other = 10.0;
	const vec2 offsets[8] = vec2[8](vec2(-1,-1),vec2(0,-1),vec2(1,-1),vec2(-1,0),vec2(1,0),vec2(-1,1),vec2(0,1),vec2(1,1));
	for (int i = 0; i < 8; i++) {
		if ((mask & (1 << i)) == 0) continue;
		vec2 delta = max(abs(local - (offsets[i] + 0.5)) - 0.5, vec2(0.0));
		distance_to_other = min(distance_to_other, length(delta));
	}
	float signed_distance = field.b > 1.5 ? distance_to_other : -distance_to_other;
	vec2 patch = floor(world.xz * 10.0) / 10.0;
	float noise = edge_noise(patch * 2.8) * 0.70 + edge_noise(patch * 7.1) * 0.30;
	float dirt = smoothstep(-0.035, 0.035, signed_distance + (noise - 0.54) * 0.64);
	if (path_verge > 0.0) {
		float feather = smoothstep(-0.14, 0.15, signed_distance + (noise - 0.62) * 0.86);
		float worn_soil = 1.0 - 0.26 * (1.0 - smoothstep(0.0, 0.52, abs(signed_distance)));
		dirt = mix(dirt, feather * worn_soil, path_verge);
	}
	return mix(source_terrain_sample(uv, 0.0), source_terrain_sample(uv, 3.0), dirt);
}
