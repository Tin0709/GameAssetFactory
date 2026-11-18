#ifndef GAF_FAR_TERRAIN_SHADOW_INCLUDE
#define GAF_FAR_TERRAIN_SHADOW_INCLUDE
#ifdef GAF_FAR_TERRAIN_SHADOWS
global uniform sampler2D gaf_far_depth : filter_nearest, repeat_disable;
global uniform sampler2D gaf_far_depth_next : filter_nearest, repeat_disable;
global uniform vec4 gaf_far_x;
global uniform vec4 gaf_far_y;
global uniform vec4 gaf_far_z;
global uniform vec4 gaf_far_x_next;
global uniform vec4 gaf_far_y_next;
global uniform vec4 gaf_far_z_next;
global uniform vec4 gaf_far_filter;
global uniform vec4 gaf_far_filter_next;
global uniform vec4 gaf_far_key; // toward the live source, w=enabled
global uniform vec4 gaf_far_fit; // narrow radius in m, radius blend, key blend

const vec2 gaf_far_taps[13] = {
	vec2(0.0), vec2(.45,0.0), vec2(-.45,0.0), vec2(0.0,.45), vec2(0.0,-.45),
	vec2(.86,0.0), vec2(-.86,0.0), vec2(0.0,.86), vec2(0.0,-.86),
	vec2(.608,.608), vec2(.608,-.608), vec2(-.608,.608), vec2(-.608,-.608)
};

float gaf_far_sample(sampler2D tile, vec4 world, vec4 tile_x, vec4 tile_y, vec4 tile_z, vec4 filter_data) {
	vec2 uv = vec2(dot(world,tile_x), dot(world,tile_y));
	float receiver = dot(world,tile_z);
	float angle = dot(gaf_far_key.xyz, normalize(tile_z.xyz));
	float travel = (.5 - receiver) * filter_data.z / max(angle, .90);
	uv += travel * vec2(dot(gaf_far_key.xyz,tile_x.xyz), dot(gaf_far_key.xyz,tile_y.xyz));
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) {
		return 1.0;
	}
	float target = receiver + .09 / filter_data.z;
	float dist = clamp((.5 - receiver) * filter_data.z, 0.0, filter_data.x * 1.35);
	float radius = mix(gaf_far_fit.x, .008726868 * dist, gaf_far_fit.y);
	float spread = max(.35 * filter_data.w, radius / filter_data.y);
	float share = 0.0;
	for (int tap = 0; tap < 13; tap++) {
		float caster = textureLod(tile, uv + gaf_far_taps[tap] * spread, 0.0).r;
		share += caster < .0005 || caster <= target ? 1.0 : 0.0;
	}
	return share / 13.0;
}

float gaf_far_attenuation(float native, bool directional, vec3 light_dir, mat4 inv_view, mat4 inv_proj, vec2 screen, float fragment_depth) {
	if (gaf_far_key.w <= 0.0 || !directional || native <= .0001 ||
			dot(mat3(inv_view) * light_dir, gaf_far_key.xyz) < .99999) {
		return native;
	}
	vec4 view = inv_proj * vec4(screen * 2.0 - 1.0, fragment_depth, 1.0);
	vec4 world = inv_view * vec4(view.xyz / view.w, 1.0);
	float blend = gaf_far_fit.z;
	if (blend <= .0001) {
		return native * gaf_far_sample(gaf_far_depth,world,gaf_far_x,gaf_far_y,gaf_far_z,gaf_far_filter);
	}
	if (blend >= .9999) {
		return native * gaf_far_sample(gaf_far_depth_next,world,gaf_far_x_next,gaf_far_y_next,gaf_far_z_next,gaf_far_filter_next);
	}
	float first = gaf_far_sample(gaf_far_depth,world,gaf_far_x,gaf_far_y,gaf_far_z,gaf_far_filter);
	float second = gaf_far_sample(gaf_far_depth_next,world,gaf_far_x_next,gaf_far_y_next,gaf_far_z_next,gaf_far_filter_next);
	return native * mix(first,second,blend);
}
#define GAF_RESOLVE_TERRAIN_SHADOW gaf_far_attenuation(ATTENUATION, LIGHT_IS_DIRECTIONAL, LIGHT, INV_VIEW_MATRIX, INV_PROJECTION_MATRIX, SCREEN_UV, FRAGCOORD.z)
#else
#define GAF_RESOLVE_TERRAIN_SHADOW ATTENUATION
#endif
#endif
