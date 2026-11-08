// Original Mobile response using existing GAF direct-light/cloud helpers.
#include "res://materials/world_map_clouds.gdshaderinc"
#define GAF_WORLD_FOLIAGE_LOBE_ONLY
#include "res://materials/world_map_foliage_light.gdshaderinc"
uniform float study_grass_up_weight=0.0;
uniform float study_transmission=0.1248;
varying vec3 study_face;
varying float study_tip_weight;
varying float study_cloud;
float grass_fresnel(float x){float q=1.0-x;float q2=q*q;return q2*q2*q;}
void light(){
	float front=clamp(dot(NORMAL,LIGHT),0.0,1.0);
	float nv=clamp(dot(NORMAL,VIEW),0.0,1.0);
	float lh=clamp(dot(LIGHT,normalize(LIGHT+VIEW)),0.0,1.0);
	float grazing=2.0*ROUGHNESS*lh*lh-0.5;
	vec3 response=vec3(front*(1.0+grazing*grass_fresnel(nv))*(1.0+grazing*grass_fresnel(front)));
	if(LIGHT_IS_DIRECTIONAL){
		response+=world_foliage_lobe(study_face,LIGHT,VIEW,front,study_tip_weight,study_transmission);
	}
	float cloud=LIGHT_IS_DIRECTIONAL?study_cloud:1.0;
	DIFFUSE_LIGHT+=response*LIGHT_COLOR*(ATTENUATION*cloud/PI);
}
