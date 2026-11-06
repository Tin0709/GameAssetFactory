uniform float wind_phase = 0.0;
uniform float breeze_phase = 0.0;
uniform bool travelling_breeze = false;
uniform float wind_strength = 1.0;
uniform float interaction_strength = 1.0;
uniform vec3 player_position = vec3(0.0);
uniform vec4 motion_start[8];
uniform vec4 motion_end[8];
uniform bool segment_passage_height = false;
uniform vec2 motion_heights[8];
vec2 world_passage(vec3 root) {
	vec2 total = vec2(0.0);
	float weights = 0.0;
	float elevation = segment_passage_height ? 1.0 : 1.0 - smoothstep(0.5, 1.6, abs(root.y - player_position.y));
	for (int i=0; i<8; i++) {
		if (motion_start[i].w <= 0.0 || motion_end[i].z >= 0.8) continue;
		vec2 segment = motion_end[i].xy - motion_start[i].xy;
		float len2 = dot(segment, segment);
		float along = clamp(dot(root.xz-motion_start[i].xy,segment)/max(len2,0.000001),0.0,1.0);
		vec2 away = root.xz - (motion_start[i].xy + segment*along);
		float falloff = 1.0-smoothstep(0.10,0.88,length(away));
		float attack = smoothstep(0.0,motion_end[i].w,motion_start[i].z);
		float recover = 1.0-smoothstep(0.10,0.8,motion_end[i].z);
		float weight = falloff*attack*recover;
		if (segment_passage_height) {
			// A past contact stays on its original path when the player changes floors.
			float path_height = mix(motion_heights[i].x, motion_heights[i].y, along);
			weight *= 1.0 - smoothstep(0.5, 1.6, abs(root.y - path_height));
		}
		vec2 direction = away/max(length(away),0.05) + segment/max(sqrt(len2),0.0001)*0.45;
		direction /= sqrt(dot(direction,direction)+0.0225);
		total += direction * weight * motion_start[i].w;
		weights += weight;
	}
	return total/max(1.0,weights)*elevation*interaction_strength;
}
vec2 world_breeze(vec3 root) {
	if (travelling_breeze) {
		// A broad gust moves over several patches while detail moves across
		// individual clumps. Both bands complete whole cycles in 28 seconds.
		float broad = sin(dot(root.xz, vec2(0.32, 0.20)) - 4.0 * breeze_phase);
		float detail = sin(dot(root.xz, vec2(1.10, -0.87)) - 10.0 * breeze_phase);
		float gust = smoothstep(-0.65, 0.97, broad + 0.18 * detail);
		vec2 heading = vec2(0.848, 0.530);
		vec2 across = vec2(-heading.y, heading.x);
		return (heading * (1.55 * gust - 0.55) + across * (0.14 * detail)) * wind_strength;
	}
	float phase = wind_phase + sin(dot(root.xz,vec2(0.19,0.13)))*0.35;
	return vec2(sin(phase),0.45*sin(phase+1.1))*wind_strength;
}
vec3 rotate_plant(vec3 point,vec2 bend) {
	float angle=length(bend);
	vec3 axis=vec3(bend.y,0.0,-bend.x)/max(angle,0.00001);
	return point*cos(angle)+cross(axis,point)*sin(angle)+axis*dot(axis,point)*(1.0-cos(angle));
}
