// Original arc adapter evaluated in each card's pitched rest frame.
// Preserves the existing arc's chord length instead of adding an upright delta
// to an already inclined stem. Not a claim of native Niagara equivalence.
vec3 gaf_grass_rest_arc(vec3 rest_direction, vec2 heading, float planar, float vertical) {
	vec3 rest = normalize(rest_direction);
	vec3 lateral = vec3(heading.x, 0.0, heading.y);
	vec3 tangent = normalize(lateral - rest * dot(lateral, rest));
	return tangent * planar + rest * vertical;
}
