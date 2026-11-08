#include "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/foliage_wind_math.gdshaderinc"
uniform bool review_source_wind=false;
uniform sampler2D review_grass_noise : filter_nearest, repeat_enable;
uniform vec2 review_world_origin_cm=vec2(0.0);
uniform vec2 review_wind_axis=vec2(1.0,0.0);
uniform float review_wind_gain=0.0;
uniform float review_wind_pin_m=0.0;
uniform float review_wind_ramp_m=0.01;
uniform float review_wind_max_m=0.0;
uniform float review_wind_time_bias=0.0;
uniform float review_wind_speed=1.0;
uniform float review_wind_spatial=0.0;
vec3 gaf_source_grass_wind(vec3 world_position,vec3 pivot,float elapsed){
	vec2 world_cm=world_position.xz*vec2(100.0,-100.0)+review_world_origin_cm;
	float clock=(elapsed+review_wind_time_bias)*review_wind_speed;
	vec2 large_uv=fract(vec2(clock*.1,-clock*.1))+world_cm*review_wind_spatial;
	vec2 fine_uv=fract(vec2(-clock*.2,clock*.1))+world_cm*review_wind_spatial*100.0;
	vec2 samples=vec2(textureLod(review_grass_noise,large_uv,0.0).r,textureLod(review_grass_noise,fine_uv,0.0).g);
	vec3 relative=world_position-pivot;
	vec3 z_up=vec3(relative.x,-relative.z,relative.y);
	vec3 delta=foliage_background_wpo(z_up,review_wind_axis,samples,review_wind_gain,review_wind_pin_m,review_wind_ramp_m,0.0,0.0,review_wind_max_m);
	return vec3(delta.x,delta.z,-delta.y);
}
