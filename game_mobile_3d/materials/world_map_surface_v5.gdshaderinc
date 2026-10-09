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
uniform float contact_shade_strength = 0.30;
uniform float plant_soil_strength = 0.75;
vec3 grade_surface_kind(vec3 source, int grade, float contrast) {
	if (grade == 0) return source;
	bool green = source.g > source.r * 1.13 && source.g > source.b * 1.35;
	vec3 center = vec3(0.24, 0.15, 0.065);
	vec3 target = vec3(0.285, 0.180, 0.075);
	if (grade == 1 && green) {
		center = vec3(0.0856, 0.2168, 0.0342);
		target = vec3(0.107, 0.235, 0.070);
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
vec3 plant_soil_speckles(vec3 grass,vec3 soil,vec3 world,vec4 field) {
	if (field.a<1.5 || abs(field.g-world.y)>0.02) return grass;
	vec2 cell=floor(world.xz),local=fract(world.xz)-0.5;
	vec2 jitter=vec2(edge_hash(cell+7.0),edge_hash(cell+19.0))-0.5;
	float radius=length((local-jitter*0.12)*vec2(1.0,1.1));
	float fade=1.0-smoothstep(0.18,0.58,radius);
	vec2 patch=floor(world.xz*12.0)/12.0;
	float spots=smoothstep(0.38,0.64,edge_noise(patch*7.7+vec2(13.0,41.0)));
	// Root earth stays dark when the sunlit path palette is lifted.
	return mix(grass,soil*vec3(0.72,0.78,0.86),spots*fade*plant_soil_strength);
}
float surface_height_at(vec2 world_xz) {
	vec2 cell=floor(world_xz)-path_map_origin;
	if (any(lessThan(cell,vec2(0.0))) || any(greaterThanEqual(cell,path_map_size))) return -10000.0;
	vec4 data=texture(path_surface_map,(cell+0.5)/path_map_size);
	return data.a>0.5 ? data.g : -10000.0;
}
float plant_contact_shade(vec3 world) {
	float shade=0.0;
	// Include neighbouring cells: the soft footprint must cross block boundaries.
	for (int z=-1;z<=1;z++) {
		for (int x=-1;x<=1;x++) {
			vec2 cell=floor(world.xz)+vec2(float(x),float(z));
			vec2 grid=cell-path_map_origin;
			if (any(lessThan(grid,vec2(0.0))) || any(greaterThanEqual(grid,path_map_size))) continue;
			vec4 patch=texture(path_surface_map,(grid+0.5)/path_map_size);
			if (patch.a<1.5 || abs(patch.g-world.y)>0.02) continue;
			vec2 jitter=(vec2(edge_hash(cell+7.0),edge_hash(cell+19.0))-0.5)*0.12;
			float distance_to_root=length((world.xz-cell-0.5-jitter)*vec2(1.0,1.08));
			float falloff=1.0-smoothstep(0.24,0.78,distance_to_root);
			float strength=patch.a<2.5 ? 0.30 : (patch.a<3.5 ? 0.23 : 0.28);
			// Max, not addition: adjacent patches form a continuous bed, never black rings.
			shade=max(shade,falloff*strength);
		}
	}
	return shade;
}
float ground_foot_contact(float distance_to_wall) {
	// A short core anchors the block. The wider fill is deliberately weak;
	// a broad equally-dark skirt makes a supported block read as hovering.
	float core=1.0-smoothstep(0.0,0.075,distance_to_wall);
	float fill=1.0-smoothstep(0.0,0.32,distance_to_wall);
	return (core*0.28+fill*0.12)/0.30;
}
float terrain_contact_shade(vec3 world,vec3 normal) {
	if (!path_blending || ground_grade==0 || contact_shade_strength<=0.0) return 1.0;
	float occlusion=0.0;
	float plant_contact=0.0;
	if (normal.y>0.9) {
		vec2 local=fract(world.xz);
		plant_contact=plant_contact_shade(world);
		const vec2 directions[4]=vec2[4](vec2(-1,0),vec2(1,0),vec2(0,-1),vec2(0,1));
		vec4 distances=vec4(local.x,1.0-local.x,local.y,1.0-local.y);
		vec2 wall_contact=vec2(0.0);
		for (int i=0;i<4;i++) {
			float higher=surface_height_at(floor(world.xz)+0.5+directions[i])-world.y;
			if (higher>0.05) {
				float contact=ground_foot_contact(distances[i])*min(1.0,higher*2.0);
				if (i<2) wall_contact.x=max(wall_contact.x,contact);
				else wall_contact.y=max(wall_contact.y,contact);
			}
		}
		// Only real enclosing walls contribute. Same-height cells never outline.
		occlusion=min(0.40/0.30,max(wall_contact.x,wall_contact.y)+min(wall_contact.x,wall_contact.y)*0.08);
		// A raised block also touches the ground cell diagonally beyond its tip.
		// Distance to the actual block footprint wraps the contact round that
		// corner, rather than ending in a bright rectangular missing quadrant.
		const vec2 diagonals[4]=vec2[4](vec2(-1,-1),vec2(1,-1),vec2(-1,1),vec2(1,1));
		for (int i=0;i<4;i++) {
			vec2 delta=max(abs(local-(diagonals[i]+0.5))-0.5,vec2(0.0));
			float distance_to_corner=length(delta);
			if (distance_to_corner<0.32) {
				float higher=surface_height_at(floor(world.xz)+0.5+diagonals[i])-world.y;
				if (higher>0.05) {
					float contact=ground_foot_contact(distance_to_corner)*min(1.0,higher*2.0);
					occlusion=max(occlusion,contact);
				}
			}
		}
	} else if (abs(normal.y)<0.1) {
		// Query the exposed side, not the solid column behind the wall.
		vec2 front=world.xz+normal.xz*0.015;
		float neighbour=surface_height_at(front);
		float above=world.y-neighbour;
		if (above>=-0.02 && above<0.30) {
			float height=max(above,0.0);
			occlusion=((1.0-smoothstep(0.0,0.075,height))*0.22+(1.0-smoothstep(0.0,0.30,height))*0.10)/0.30;
		}
		// Adjacent occupied columns on the exposed side form concave corners.
		// Exterior convex edges have no such neighbour and stay untouched.
		vec2 tangent=vec2(-normal.z,normal.x);
		float along=fract(dot(world.xz,tangent));
		vec2 distances=vec2(along,1.0-along);
		for (int i=0;i<2;i++) {
			vec2 direction=tangent*(i==0 ? -1.0 : 1.0);
			float higher=surface_height_at(floor(front)+0.5+direction)-world.y;
			float height_weight=smoothstep(0.025,0.18,higher);
			float corner=(1.0-smoothstep(0.0,0.45,distances[i]))*height_weight*0.95;
			occlusion=max(occlusion,corner);
		}
	}
	return (1.0-occlusion*contact_shade_strength)*(1.0-plant_contact);
}
vec3 shade_world_surface(vec3 source, vec3 world, float top) {
	vec3 original=grade_surface_kind(source,ground_grade,texture_contrast);
	if (top>0.9 && ground_grade==1 && source.g>source.r*1.13 && source.g>source.b*1.35) original=vary_grass_surface(original,world);
	if (!path_blending || top<0.9 || ground_grade==3) return original;
	vec2 grid=floor(world.xz)-path_map_origin;
	if (any(lessThan(grid,vec2(0.0))) || any(greaterThanEqual(grid,path_map_size))) return original;
	vec4 field=texture(path_surface_map,(grid+0.5)/path_map_size);
	if (ground_grade==1 && field.a>1.5) {
		vec3 soil=grade_surface_kind(texture(path_dirt_atlas,world.xz).rgb,2,texture_contrast);
		original=plant_soil_speckles(original,soil,world,field);
	}
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
	grass=plant_soil_speckles(grass,soil,world,field);
	return mix(grass,soil,dirt);
}
