// Actor-only Burley/GGX direct response. Ambient/emission remain engine-owned.
// Unlike the older matte-terrain helper, specular lobes are not clipped to 1.
varying float player_cloud;
float player_fresnel(float c){float x=1.0-c;float s=x*x;return s*s*x;}
void light(){
	float nl=max(dot(NORMAL,LIGHT),0.0);
	if(nl>0.0){
		float nv=max(dot(NORMAL,VIEW),0.0001);
		vec3 h=normalize(LIGHT+VIEW);
		float lh=clamp(dot(LIGHT,h),0.0,1.0);
		float incident=ATTENUATION*nl/PI;
		if(LIGHT_IS_DIRECTIONAL)incident*=player_cloud;
		if(METALLIC<1.0){
#ifndef GAF_WORLD_FORCE_LAMBERT
			float grazing=2.0*lh*lh*ROUGHNESS-0.5;
			DIFFUSE_LIGHT+=LIGHT_COLOR*incident*(1.0+grazing*player_fresnel(nv))*(1.0+grazing*player_fresnel(nl));
#else
			DIFFUSE_LIGHT+=LIGHT_COLOR*incident;
#endif
		}
		if(ROUGHNESS>0.0){
			float a=ROUGHNESS*ROUGHNESS;
			float nh=clamp(dot(NORMAL,h),0.0,1.0);
			float k=a/max(1.0-nh*nh+(nh*a)*(nh*a),0.0000001);
			float visibility=0.5/max(mix(2.0*nl*nv,nl+nv,a),0.0000001);
			vec3 f0=mix(vec3(0.16*native_specular*native_specular),ALBEDO,METALLIC);
			float f90=clamp(dot(f0,vec3(16.5)),METALLIC,1.0);
			SPECULAR_LIGHT+=LIGHT_COLOR*incident*k*k*visibility*(f0+(f90-f0)*player_fresnel(lh))*SPECULAR_AMOUNT;
		}
	}
}
