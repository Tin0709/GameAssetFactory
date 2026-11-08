// Original baked GAF irradiance, terrain-only. No native source coefficients.
varying vec3 terrain_sky_light;
varying vec3 terrain_sun_bounce;
varying float terrain_direct_contact;
uniform vec3 terrain_key_radiance=vec3(0);
uniform float terrain_ambient_scale=1.0;
vec3 terrain_indirect(vec3 color,float metallic,float visibility,float cloud){
	return color*(1.0-metallic)*(terrain_sky_light*terrain_ambient_scale*visibility+terrain_sun_bounce*terrain_key_radiance*cloud);
}
