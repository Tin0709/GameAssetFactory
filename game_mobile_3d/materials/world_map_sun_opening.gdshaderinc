global uniform float gaf_sun_opening_gain;

// Lift the direct beam in lit openings using the existing geometric and
// projected visibility. Sky, bounce and local light stay separately owned.
float gaf_opening_gain(bool directional, float visibility) {
	if (!directional || gaf_sun_opening_gain <= 0.0) {
		return 1.0;
	}
	return 1.0 + gaf_sun_opening_gain * smoothstep(0.60, 0.88, visibility);
}
