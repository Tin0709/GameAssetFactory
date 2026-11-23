global uniform sampler2D gaf_local_diffuse_field : filter_linear, repeat_disable;
global uniform vec4 gaf_local_diffuse_field_rect;
global uniform vec2 gaf_local_diffuse_field_strength;

// Called after including world_map_spruce_sky, which owns the viewport scope.
float gaf_local_diffuse_field_gain(vec3 world_position, vec3 camera_position, float gain) {
	if (gain <= 0.0 || distance(camera_position, gaf_spruce_sky_camera) > .01) return 1.0;
	float deck = 1.0 - smoothstep(.20, .72, abs(world_position.y - gaf_local_diffuse_field_rect.w));
	if (deck <= 0.0) return 1.0;
	vec2 cell = (world_position.xz - gaf_local_diffuse_field_rect.xy) / gaf_local_diffuse_field_rect.z;
	vec2 size = vec2(textureSize(gaf_local_diffuse_field, 0));
	if (any(lessThan(cell, vec2(0.0))) || any(greaterThan(cell, size - 1.0))) return 1.0;
	float encoded = textureLod(gaf_local_diffuse_field, (cell + .5) / size, 0.0).r;
	return exp2((encoded * 255.0 - 128.0) * (1.10 / 127.0) * gain * deck);
}
