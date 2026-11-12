// Original Mobile response using existing GAF direct-light/cloud helpers.
#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_sun_opening.gdshaderinc"
#define GAF_WORLD_FOLIAGE_LOBE_ONLY
#include "res://materials/world_map_foliage_light.gdshaderinc"
uniform float study_grass_up_weight=0.0;
uniform float study_transmission=0.1248;
varying vec3 study_face;
varying float study_tip_weight;
varying float study_cloud;
varying vec3 grass_opening_incident;
float grass_fresnel(float x){float q=1.0-x;float q2=q*q;return q2*q2*q;}
void light(){
	float point_transfer=gaf_point_transfer(LIGHT_IS_DIRECTIONAL,LIGHT,SCREEN_UV,FRAGCOORD.z,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX,LIGHT_COLOR.b);
	float front=clamp(dot(NORMAL,LIGHT),0.0,1.0);
	vec3 response=vec3(front);
#ifndef GAF_GRASS_FORCE_LAMBERT
	float nv=clamp(dot(NORMAL,VIEW),0.0,1.0);
	float lh=clamp(dot(LIGHT,normalize(LIGHT+VIEW)),0.0,1.0);
	float grazing=2.0*ROUGHNESS*lh*lh-0.5;
	response*=((1.0+grazing*grass_fresnel(nv))*(1.0+grazing*grass_fresnel(front)));
#endif
	if(LIGHT_IS_DIRECTIONAL){
		response+=world_foliage_lobe(study_face,LIGHT,VIEW,front,study_tip_weight,study_transmission);
	}
	float cloud=LIGHT_IS_DIRECTIONAL?study_cloud:1.0;
	float gain = gaf_opening_gain(LIGHT_IS_DIRECTIONAL, ATTENUATION * cloud);
	float opening_fill = gaf_diffuse_opening_weight(LIGHT_IS_DIRECTIONAL, LIGHT, LIGHT_COLOR, INV_VIEW_MATRIX, ATTENUATION * cloud);
	if (opening_fill > 0.0) {
		DIFFUSE_LIGHT += grass_opening_incident * (0.65 * opening_fill);
	}
	vec3 diffuse_color=LIGHT_COLOR * gain;
	// The identity transfer is returned for non-lantern lights and other cameras.
	if (gaf_lantern_grass_tone > 0.0 && point_transfer < 1.0 && gaf_is_player_point(LIGHT_IS_DIRECTIONAL,LIGHT_COLOR.b)) {
		diffuse_color *= gaf_lantern_diffuse_tint(ALBEDO,LIGHT_COLOR,vec3(1.247,1.0,1.078),gaf_lantern_grass_tone);
	}
	DIFFUSE_LIGHT+=response*diffuse_color*(ATTENUATION*point_transfer*cloud/PI);
}
