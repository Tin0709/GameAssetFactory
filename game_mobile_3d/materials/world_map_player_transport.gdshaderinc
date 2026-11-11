// Original ambient cube approximation, sampled from this map's own offline rays.
// Incoming diffuse and broad specular proxy are separate; not Lumen/raytraced reflections.
uniform bool player_local_light=false;
uniform bool player_rough_reflection=false;
uniform vec3 player_probe_sky[18];
uniform vec3 player_probe_sun[18];
uniform float player_probe_base=0.;
uniform float player_probe_scale=1.;
uniform vec3 player_probe_tint=vec3(1);
uniform vec3 player_probe_key=vec3(0);
uniform bool skin_wrap_enabled=false;
uniform sampler2D skin_profile_mask:hint_default_black,filter_nearest,repeat_disable;
varying float player_skin_weight;
vec3 player_axis_light(int axis,float height,float cloud,float sky_visibility){
 int lo=height<1.?0:6;
 float f=height<1.?clamp((height-.25)/.75,0.,1.):clamp((height-1.)/.8,0.,1.);
 vec3 s=mix(player_probe_sky[lo+axis],player_probe_sky[lo+6+axis],f);
 vec3 b=mix(player_probe_sun[lo+axis],player_probe_sun[lo+6+axis],f);
 return s*player_probe_scale*player_probe_tint*sky_visibility+b*player_probe_key*cloud;
}
vec3 player_cube_light(vec3 n,float height,float cloud,float sky_visibility){
 vec3 w=n*n;
 return w.x*player_axis_light(n.x>=0.?0:1,height,cloud,sky_visibility)
	+w.y*player_axis_light(n.y>=0.?2:3,height,cloud,sky_visibility)
	+w.z*player_axis_light(n.z>=0.?4:5,height,cloud,sky_visibility);
}
