// Original baked GAF irradiance, terrain-only. No native source coefficients.
varying vec3 terrain_sky_light;
#ifdef GAF_TERRAIN_NIGHT_SKY
varying vec3 terrain_night_sky_light;
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
vec3 terrain_indirect(vec3 color,float metallic,float visibility,float cloud,float contact){
	vec3 sky = terrain_sky_light;
#ifdef GAF_TERRAIN_NIGHT_SKY
	if (night_sky_state.x > 0.0) sky = terrain_night_sky_light;
#endif
	vec3 irradiance = sky * terrain_ambient_scale * terrain_ambient_tint * visibility + terrain_sun_bounce * terrain_key_radiance * cloud;
#ifdef GAF_TERRAIN_NIGHT_SKY
	if (ground_grade == 3 && night_sky_state.y > 0.0) {
		float luma = dot(irradiance, vec3(.2126, .7152, .0722));
		irradiance = mix(irradiance, vec3(luma), night_sky_state.y);
	}
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
