// Scene-local, reversible grade of authored texels. No replacement texture/UV.
uniform int ground_grade = 0; // 1 grass/dirt, 2 dirt, 3 mineral
uniform float texture_contrast = 0.58;
uniform sampler2D path_surface_map : filter_nearest, repeat_disable;
uniform sampler2D path_grass_atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_dirt_atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform bool path_blending = false;
uniform vec2 path_map_origin = vec2(0.0);
uniform vec2 path_map_size = vec2(1.0);
uniform float grass_variation_strength = 0.16;
uniform float contact_shade_strength = 0.13;
vec3 grade_surface_kind(vec3 source, int grade, float contrast) {
	if (grade == 0) return source;
	bool green = source.g > source.r * 1.13 && source.g > source.b * 1.35;
	vec3 center = vec3(0.24, 0.15, 0.065);
	vec3 target = vec3(0.245, 0.171, 0.082);
	if (grade == 1 && green) {
		center = vec3(0.0856, 0.2168, 0.0342);
		target = vec3(0.125, 0.218, 0.067);
	} else if (grade == 3) {
		center = vec3(0.24, 0.27, 0.27);
		target = vec3(0.180, 0.230, 0.245);
	}
	return max(vec3(0.0), target + (source - center) * contrast);
}
float edge_hash(vec2 p) { return fract(sin(dot(p,vec2(43.71,117.19)))*17341.131); }
float edge_noise(vec2 p) {
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(edge_hash(i),edge_hash(i+vec2(1,0)),f.x),mix(edge_hash(i+vec2(0,1)),edge_hash(i+vec2(1,1)),f.x),f.y);
}
vec3 vary_grass_surface(vec3 color,vec3 world) {
	// World anchored, low-amplitude colour noise; independent of wind/cloud time.
	float macro=edge_noise(world.xz*0.24+vec2(71.3,29.7));
	float detail=edge_noise(world.xz*1.9+vec2(3.1,53.6));
	float variation=(macro*0.72+detail*0.28-0.5)*grass_variation_strength;
	return color*vec3(1.0+variation,1.0+variation*0.83,1.0+variation*0.55);
}
float surface_height_at(vec2 world_xz) {
	vec2 cell=floor(world_xz)-path_map_origin;
	if (any(lessThan(cell,vec2(0.0))) || any(greaterThanEqual(cell,path_map_size))) return -10000.0;
	vec4 data=texture(path_surface_map,(cell+0.5)/path_map_size);
	return data.a>0.5 ? data.g : -10000.0;
}
float terrain_contact_shade(vec3 world,vec3 normal) {
	if (!path_blending || ground_grade==0 || contact_shade_strength<=0.0) return 1.0;
	float occlusion=0.0;
	if (normal.y>0.9) {
		vec2 local=fract(world.xz);
		const vec2 directions[4]=vec2[4](vec2(-1,0),vec2(1,0),vec2(0,-1),vec2(0,1));
		vec4 distances=vec4(local.x,1.0-local.x,local.y,1.0-local.y);
		for (int i=0;i<4;i++) {
			float higher=surface_height_at(floor(world.xz)+0.5+directions[i])-world.y;
			if (higher>0.05) occlusion=max(occlusion,(1.0-smoothstep(0.0,0.38,distances[i]))*min(1.0,higher*2.0));
		}
	} else if (abs(normal.y)<0.1) {
		// Shade the wall foot only where a real neighbouring terrace meets it.
		float neighbour=surface_height_at(world.xz+normal.xz*0.015);
		float above=world.y-neighbour;
		if (above>=-0.02 && above<0.32) occlusion=(1.0-smoothstep(0.0,0.32,max(above,0.0)))*0.75;
	}
	return 1.0-occlusion*contact_shade_strength;
}
vec3 shade_world_surface(vec3 source, vec3 world, float top) {
	vec3 original=grade_surface_kind(source,ground_grade,texture_contrast);
	if (top>0.9 && ground_grade==1 && source.g>source.r*1.13 && source.g>source.b*1.35) original=vary_grass_surface(original,world);
	if (!path_blending || top<0.9 || ground_grade==3) return original;
	vec2 grid=floor(world.xz)-path_map_origin;
	if (any(lessThan(grid,vec2(0.0))) || any(greaterThanEqual(grid,path_map_size))) return original;
	vec4 field=texture(path_surface_map,(grid+0.5)/path_map_size);
	int mask=int(round(field.r));
	if (mask==0 || abs(field.g-world.y)>0.02) return original;
	vec2 local=fract(world.xz);
	float distance_to_other=10.0;
	const vec2 offsets[8]=vec2[8](vec2(-1,-1),vec2(0,-1),vec2(1,-1),vec2(-1,0),vec2(1,0),vec2(-1,1),vec2(0,1),vec2(1,1));
	for (int i=0;i<8;i++) {
		if ((mask & (1<<i))==0) continue;
		vec2 delta=max(abs(local-(offsets[i]+0.5))-0.5,vec2(0.0));
		distance_to_other=min(distance_to_other,length(delta));
	}
	float signed_distance=field.b>1.5 ? distance_to_other : -distance_to_other;
	// Fixed 10cm clusters break the grid edge; the road centre remains unbroken.
	vec2 patch=floor(world.xz*10.0)/10.0;
	float noise=edge_noise(patch*2.8)*0.70+edge_noise(patch*7.1)*0.30;
	float dirt=smoothstep(-0.035,0.035,signed_distance+(noise-0.54)*0.64);
	vec3 grass=grade_surface_kind(texture(path_grass_atlas,world.xz).rgb,1,texture_contrast);
	grass=vary_grass_surface(grass,world);
	vec3 soil=grade_surface_kind(texture(path_dirt_atlas,world.xz).rgb,2,texture_contrast);
	return mix(grass,soil,dirt);
}
