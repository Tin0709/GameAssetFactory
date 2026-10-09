uniform float wind_phase = 0.0;
uniform float wind_strength = 1.0;
uniform float interaction_strength = 1.0;
uniform vec3 player_position = vec3(0.0);
uniform vec4 motion_start[8];
uniform vec4 motion_end[8];
vec2 world_passage(vec3 root) {
	vec2 total = vec2(0.0);
	float weights = 0.0;
	// Avoid affecting plants on another terrace above or below the player.
	float elevation = 1.0 - smoothstep(0.5, 1.6, abs(root.y - player_position.y));
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
		vec2 direction = away/max(length(away),0.05) + segment/max(sqrt(len2),0.0001)*0.45;
		direction /= sqrt(dot(direction,direction)+0.0225);
		total += direction * weight * motion_start[i].w;
		weights += weight;
	}
	return total/max(1.0,weights)*elevation*interaction_strength;
}
vec2 world_breeze(vec3 root) {
	float phase = wind_phase + sin(dot(root.xz,vec2(0.19,0.13)))*0.35;
	return vec2(sin(phase),0.45*sin(phase+1.1))*wind_strength;
}
vec3 rotate_plant(vec3 point,vec2 bend) {
	float angle=length(bend);
	vec3 axis=vec3(bend.y,0.0,-bend.x)/max(angle,0.00001);
	return point*cos(angle)+cross(axis,point)*sin(angle)+axis*dot(axis,point)*(1.0-cos(angle));
}
