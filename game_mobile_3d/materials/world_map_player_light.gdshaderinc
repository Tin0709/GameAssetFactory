#include "res://materials/world_map_point_kernel.gdshaderinc"
#include "res://materials/world_map_soft_source.gdshaderinc"
#include "res://materials/world_map_sun_opening.gdshaderinc"
// Actor-only Burley/GGX direct response. Ambient/emission remain engine-owned.
// Unlike the older matte-terrain helper, specular lobes are not clipped to 1.
varying float player_cloud;
uniform float player_sun_shoulder = 0.0;
float player_fresnel(float c){float x=1.0-c;float s=x*x;return s*s*x;}
void light(){
	float point_attenuation=ATTENUATION*gaf_point_transfer(LIGHT_IS_DIRECTIONAL,LIGHT,SCREEN_UV,FRAGCOORD.z,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX,LIGHT_COLOR.b);
	vec3 key_color = LIGHT_COLOR * gaf_opening_gain(LIGHT_IS_DIRECTIONAL, ATTENUATION * player_cloud);
	float nl=max(dot(NORMAL,LIGHT),0.0);
	if (LIGHT_IS_DIRECTIONAL && player_sun_shoulder > 0.0) {
		// Ease strong direct sun on Valorie at the edge of a shadow.
		// The local light, indirect light and surface material remain independent.
		float beam = ATTENUATION * player_cloud * nl * dot(LIGHT_COLOR / PI, vec3(.2126,.7152,.0722));
		key_color *= 1.0 - player_sun_shoulder * smoothstep(.12,.62,beam);
	}
	// Original selective wrap, not native screen-space diffusion. Integral of
	// max(N.L+w,0)/(1+w)^2 over the sphere is PI: redistribute, do not add a lamp.
	if(player_skin_weight>0.){
		float wrapped=max(dot(NORMAL,LIGHT)+.15,0.)/(1.15*1.15);
		float delta=wrapped-nl;
		float visibility=point_attenuation*(LIGHT_IS_DIRECTIONAL?player_cloud:1.);
		DIFFUSE_LIGHT+=key_color*visibility*delta/PI*player_skin_weight;
	}
	if(nl>0.0){
		float nv=max(dot(NORMAL,VIEW),0.0001);
		vec3 h=normalize(LIGHT+VIEW);
		float lh=clamp(dot(LIGHT,h),0.0,1.0);
		float incident=point_attenuation*nl/PI;
		if(LIGHT_IS_DIRECTIONAL)incident*=player_cloud;
		if(METALLIC<1.0){
#ifndef GAF_WORLD_FORCE_LAMBERT
			float grazing=2.0*lh*lh*ROUGHNESS-0.5;
			DIFFUSE_LIGHT+=key_color*incident*(1.0+grazing*player_fresnel(nv))*(1.0+grazing*player_fresnel(nl));
#else
			DIFFUSE_LIGHT+=key_color*incident;
#endif
		}
		float source_angle=gaf_player_soft_angle(LIGHT_IS_DIRECTIONAL,LIGHT,actor_world,INV_VIEW_MATRIX,LIGHT_COLOR.b);
		if(ROUGHNESS>0.0||source_angle>0.){
			float a=ROUGHNESS*ROUGHNESS;
			if(source_angle>0.)a=gaf_soft_lobe_width(ROUGHNESS,lh,source_angle,gaf_point_soft.y);
			float nh=clamp(dot(NORMAL,h),0.0,1.0);
			float k=a/max(1.0-nh*nh+(nh*a)*(nh*a),0.0000001);
			float visibility=0.5/max(mix(2.0*nl*nv,nl+nv,a),0.0000001);
			vec3 f0=mix(vec3(0.16*native_specular*native_specular),ALBEDO,METALLIC);
			float f90=clamp(dot(f0,vec3(16.5)),METALLIC,1.0);
			float normalization = LIGHT_IS_DIRECTIONAL ? mix(1.0, 1.0 / PI, player_sun_specular_normalization) : 1.0;
			SPECULAR_LIGHT+=key_color*incident*k*k*visibility*(f0+(f90-f0)*player_fresnel(lh))*SPECULAR_AMOUNT*normalization;
		}
	}
}
