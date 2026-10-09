uniform bool cutaway_enabled = false;
uniform vec3 cutaway_start = vec3(0.0);
uniform vec3 cutaway_end = vec3(0.0);
varying vec3 cutaway_world;

float cliff_visibility() {
	vec3 axis = cutaway_end - cutaway_start;
	float t = dot(cutaway_world - cutaway_start, axis) / max(dot(axis, axis), 0.001);
	vec3 nearest = cutaway_start + axis * t;
	float corridor = (1.0 - smoothstep(2.1, 3.4, distance(cutaway_world, nearest)))
		* smoothstep(0.02, 0.1, t) * (1.0 - smoothstep(0.94, 1.06, t));
	return cutaway_enabled ? mix(1.0, 0.12, corridor) : 1.0;
}
