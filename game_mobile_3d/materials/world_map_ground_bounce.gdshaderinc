// Original finite-ground-patch diffuse approximation, not a native MD2 shader.
uniform sampler2D ground_bounce_map : filter_linear, repeat_disable;
uniform vec3 ground_bounce_direction;
uniform float ground_bounce_radius = 3.0;
varying vec3 ground_reflection;

float ground_disk_factor(float height) {
	float t = max(height, 0.001) / ground_bounce_radius;
	// Rational approximation to (atan(1/t)-t/(1+t*t))/PI.
	// Max absolute view-factor error <0.0011; no fragment atan required.
	return (0.5 + 0.204471737 * t)
		/ ((((0.963550362 * t + 1.878226031) * t + 2.141821942) * t + 1.682183020) * t + 1.0);
}

vec3 ground_patch_reflection(vec3 receiver, vec2 point) {
	vec2 uv = (point - path_map_origin) / path_map_size;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) return vec3(0.0);
	vec4 ground = textureLod(path_surface_map, uv, 0.0);
	float height = receiver.y - ground.g;
	// An upper floor cannot radiate down through its solid support.
	if (ground.a < 0.5 || height < 0.0) return vec3(0.0);
	return textureLod(ground_bounce_map, uv, 0.0).rgb * ground_disk_factor(height);
}

vec3 ground_bounce(vec3 receiver, vec3 normal) {
	if (ground_grade != 3 || abs(normal.y) > 0.1) return vec3(0.0);
	vec2 tangent = vec2(-normal.z, normal.x);
	vec2 centre = floor(receiver.xz + normal.xz * 0.015) + vec2(0.5);
	float along = dot(receiver.xz, tangent) - 0.5;
	centre += tangent * (floor(along) + 0.5 - dot(centre, tangent));
	// Blend contributions, not heights: separate terraces never bleed together.
	return mix(ground_patch_reflection(receiver, centre),
		ground_patch_reflection(receiver, centre + tangent), fract(along));
}
