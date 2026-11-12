// Original diffuse receiver adjustment. No native shader code or assets.
uniform sampler3D regional_sky_field : filter_linear, repeat_disable;
uniform vec4 regional_sky_bounds;
uniform vec4 regional_sky_roots;
uniform vec4 regional_sky_phase;
uniform vec2 regional_sky_state = vec2(0.0); // strength, grass receiver start

uniform sampler2D night_sky_field : filter_nearest, repeat_disable;
uniform vec2 night_sky_state = vec2(0.0); // spatial fill, stone color balance
uniform vec4 night_sky_roots; // grass origin and extent
uniform int night_sky_grass_start;
uniform sampler3D day_bounce_field : filter_linear, repeat_disable;
uniform vec4 day_bounce_key = vec4(0.0); // Linear key RGB and phase slice.
uniform vec4 day_bounce_roots;
uniform int day_bounce_grass_start;

vec3 gaf_day_bounce(int receiver) {
	if (dot(day_bounce_key.rgb, vec3(1.0)) <= 0.0) return vec3(0.0);
	ivec2 extent = textureSize(day_bounce_field, 0).xy;
	ivec2 cell = ivec2(receiver % extent.x, receiver / extent.x);
	return textureLod(day_bounce_field, vec3((vec2(cell) + 0.5) / vec2(extent), day_bounce_key.w), 0.0).rgb * day_bounce_key.rgb;
}

vec3 gaf_night_sky(vec3 sky, int receiver) {
	if (night_sky_state.x <= 0.0) return sky;
	ivec2 extent = textureSize(night_sky_field, 0);
	ivec2 cell = ivec2(receiver % extent.x, receiver / extent.x);
	return mix(sky, texelFetch(night_sky_field, cell, 0).rgb, night_sky_state.x);
}

vec3 gaf_regional_sky(vec3 incident, vec3 tint, vec2 position_xz, int receiver) {
	if (regional_sky_state.x <= 0.0) return incident;
	float distance_m = length(position_xz - regional_sky_bounds.xy);
	float gain = regional_sky_state.x * (1.0 - smoothstep(regional_sky_bounds.z, regional_sky_bounds.w, distance_m));
	if (gain <= 0.0) return incident;
	vec3 luma_weights = vec3(0.2126, 0.7152, 0.0722) * tint;
	float incident_luma = dot(incident, luma_weights);
	if (incident_luma < 0.00001) return incident;
	ivec2 extent = textureSize(regional_sky_field, 0).xy;
	vec2 cell = vec2(float(receiver % extent.x), float(receiver / extent.x));
	vec3 sky = textureLod(regional_sky_field, vec3((cell + 0.5) / vec2(extent), regional_sky_phase.x), 0.0).rgb;
	float ratio = dot(sky * regional_sky_phase.yzw, luma_weights) / incident_luma;
	return mix(incident, incident * max(1.0, ratio), gain);
}
