shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.9, 0.79, 0.58, 1.0);
uniform float progress = 0.0;
uniform int clip_count = 0;
uniform vec3 clip_planes[8];

varying vec2 floor_position;

void vertex() {
	floor_position = VERTEX.xz;
}

void fragment() {
	for (int i = 0; i < clip_count; i++) {
		if (dot(floor_position, clip_planes[i].xy) + clip_planes[i].z < 0.0) {
			discard;
		}
	}
	vec2 offset = UV * 2.0 - 1.0;
	float sector = floor(atan(offset.y, offset.x) * 3.81972);
	float step_edge = mod(sector * sector + 3.0 * sector, 5.0) * 0.012;
	float radius = mix(0.20, 0.90, 1.0 - pow(1.0 - progress, 2.0));
	float distance_from_front = length(offset) - radius + step_edge;
	float front = 1.0 - smoothstep(0.023, 0.085, abs(distance_from_front));
	float skirt = 1.0 - smoothstep(0.0, 0.18, abs(distance_from_front + 0.08));
	ALBEDO = tint.rgb;
	ALPHA = max(front * 0.44, skirt * 0.20) * (1.0 - smoothstep(0.05, 1.0, progress));
}
