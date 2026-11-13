// Original baked GAF irradiance, terrain-only. No native source coefficients.
#include "res://materials/world_map_turf_ambient.gdshaderinc"
#include "res://materials/world_map_spruce_sky.gdshaderinc"
varying vec3 terrain_sky_light;
varying float terrain_canopy_sky;
#ifdef GAF_TERRAIN_NIGHT_SKY
varying vec3 terrain_night_sky_light;
varying vec3 terrain_day_bounce;
varying float stone_diffuse_log;
uniform sampler2D stone_diffuse_field : filter_nearest, repeat_disable;
uniform float stone_diffuse_strength = 0.0;
uniform float night_stone_top_cool = 0.0;
uniform float night_stone_blue_softness = 0.0;
uniform float dawn_stone_sky_color = 0.0;

float gaf_stone_diffuse_sample(int receiver, vec3 world_normal) {
	if (stone_diffuse_strength <= 0.0 || ground_grade != 3 || abs(world_normal.y) >= 0.1) return 0.0;
	int width = textureSize(stone_diffuse_field, 0).x;
	ivec2 pixel = ivec2(receiver % width, receiver / width);
	// The map stores a bounded log2 ratio over connected coplanar terrain.
	return (texelFetch(stone_diffuse_field, pixel, 0).r * 255.0 - 128.0) * (0.45 / 127.0);
}
#endif
varying vec3 terrain_sun_bounce;
varying float terrain_direct_contact;
varying vec3 terrain_opening_incident;
uniform vec3 terrain_key_radiance=vec3(0);
uniform float terrain_ambient_scale=1.0;
uniform vec3 terrain_ambient_tint=vec3(1);
uniform bool terrain_colored_visibility=false;
// Independently expressed visibility fit, validated against the research oracle.
// Contact is our existing local geometry proxy, NOT a recovered bent-normal field.
vec3 terrain_contact_response(vec3 albedo,float contact){
	float open_fraction=clamp(contact,0.0,0.9990000128746033);
	float blocked=1.0-open_fraction;
	float single=open_fraction*(1.0+blocked/(2.0*sqrt(sqrt(blocked))));
	float returned=27.576936721801758*open_fraction*blocked*sqrt(blocked)
		*exp2(-4.813464164733887*sqrt(sqrt(open_fraction)));
	float return_ratio=returned/max(1.0-single,0.00001);
	vec3 reflectance=clamp(albedo,vec3(0.0),vec3(0.5));
	return vec3(single)+returned*reflectance/max(vec3(1.0)-(1.0-return_ratio)*reflectance,vec3(0.00001));
}
vec3 terrain_indirect(vec3 color,float metallic,float visibility,float cloud,float contact,float face_y){
	vec3 sky = terrain_sky_light;
#ifdef GAF_TERRAIN_NIGHT_SKY
	if (night_sky_state.x > 0.0) sky = terrain_night_sky_light;
	if (ground_grade == 3 && stone_diffuse_strength > 0.0) sky *= exp2(stone_diffuse_log * stone_diffuse_strength);
#endif
	vec3 sky_fill = sky * terrain_ambient_scale * terrain_ambient_tint * visibility;
	sky_fill = gaf_canopy_diffuse_color(sky_fill, terrain_canopy_sky, gaf_canopy_sky_color);
	if (turf_ambient_color != vec3(1.0) && (ground_grade == 1 || ground_grade == 2) && face_y > 0.998) {
		// The authored path shares the terrain shader. Ease out the effect as the albedo crosses into soil.
		float turf = smoothstep(1.04, 1.18, color.g / max(color.r, 0.0001)) *
			smoothstep(1.13, 1.27, color.g / max(color.b, 0.0001));
		sky_fill = mix(sky_fill, gaf_turf_ambient(sky_fill), turf);
	}
	vec3 irradiance = sky_fill + terrain_sun_bounce * terrain_key_radiance * cloud;
#ifdef GAF_TERRAIN_NIGHT_SKY
	if (ground_grade == 3 && night_sky_state.y > 0.0) {
		float luma = dot(irradiance, vec3(.2126, .7152, .0722));
		// Keep more of the incident sky chroma on upward-facing stone.
		float balance = night_sky_state.y * (1.0 - night_stone_top_cool * clamp(face_y, 0.0, 1.0));
		irradiance = mix(irradiance, vec3(luma), balance);
	}
	if (ground_grade == 3 && night_stone_blue_softness > 0.0) {
		float y = dot(irradiance, vec3(0.2126, 0.7152, 0.0722));
		float excess_blue = smoothstep(1.30, 2.05, irradiance.b / max(y, 0.000001));
		float amount = night_stone_blue_softness * excess_blue;
		irradiance = mix(irradiance, vec3(y), 0.46 * amount) * (1.0 - 0.1375 * amount);
	}
	if (ground_grade == 3 && dawn_stone_sky_color > 0.0) {
		// Retain the incident energy and warm light while the shaded stone changes hue.
		const vec3 luma = vec3(.2126,.7152,.0722);
		vec3 ratio = mix(vec3(1.75,1.0,.73), vec3(1.58,1.0,.77), clamp(face_y,0.0,1.0));
		vec3 target = irradiance * ratio;
		target *= dot(irradiance, luma) / max(dot(target, luma), .000001);
		irradiance = mix(irradiance, target, .70 * dawn_stone_sky_color);
	}
	irradiance += terrain_day_bounce;
#endif
	if(terrain_colored_visibility)irradiance*=terrain_contact_response(color,contact);
	return color*(1.0-metallic)*irradiance;
}

vec3 terrain_opening_fill(vec3 albedo, float contact, float sole) {
	vec3 incident = terrain_sky_light * terrain_ambient_scale * terrain_ambient_tint * sole;
	return terrain_colored_visibility ? incident * terrain_contact_response(albedo, contact) : incident;
}
#ifdef GAF_WORLD_TERRAIN_PBR
// Recovered split-sum consumer form; independently integrated GGX LUT.
// Existing diffuse transport is only a low-frequency incident-radiance proxy.
vec3 terrain_reflected(vec3 normal,vec3 view,float rough,float visibility,float cloud,float contact,float source_spec){
	vec3 incident=terrain_sky_light*terrain_ambient_scale*terrain_ambient_tint*visibility+terrain_sun_bounce*terrain_key_radiance*cloud;
	vec2 integrated=texture(terrain_env_brdf,vec2(clamp(dot(normal,view),0.,1.),clamp(rough,0.,1.))).rg;
	float f0=source_spec>0.? .16*source_spec*source_spec:.04;
	return incident*(vec3(f0)*integrated.x+vec3(integrated.y))*clamp(contact,0.,1.);
}
#endif
