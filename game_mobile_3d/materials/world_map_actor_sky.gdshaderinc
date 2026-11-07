uniform vec4 sky_block[60];
uniform vec2 sky_heights;
// Original bounce reserve: this is an art parameter, not recovered MD2 GI.
uniform float sky_strength = 0.75;

float actor_block_term(int index, float height, vec3 normal) {
	vec4 c = mix(sky_block[index], sky_block[index + 3], height);
	vec4 q = mix(sky_block[index + 1], sky_block[index + 4], height);
	vec4 r = mix(sky_block[index + 2], sky_block[index + 5], height);
	return clamp(c.x + dot(c.yzw, normal) + dot(q.xyz, normal * normal)
		+ 2.0 * (q.w * normal.x * normal.y + r.x * normal.x * normal.z + r.y * normal.y * normal.z), 0.0, 1.0);
}

float actor_sky_visibility(vec3 position, vec3 normal) {
	float height = clamp((position.y - sky_heights.x) / max(sky_heights.y - sky_heights.x, 0.001), 0.0, 1.0);
	// Dominant occluders do not compound into black when their projections overlap.
	float blocked = 0.0;
	for (int crown = 0; crown < 10; crown++) {
		int index = crown * 6;
		if (sky_block[index].x == 0.0 && sky_block[index + 3].x == 0.0) continue;
		blocked = max(blocked, actor_block_term(index, height, normal));
	}
	return 1.0 - sky_strength * blocked;
}
