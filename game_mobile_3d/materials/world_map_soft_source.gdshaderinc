// Independently authored finite-source lobe broadening. It changes the
// direct specular width only; diffuse, material maps and sky stay unchanged.
#ifndef GAF_SOFT_SOURCE_HELPER
#define GAF_SOFT_SOURCE_HELPER
global uniform vec2 gaf_point_soft;
float gaf_soft_lobe_width(float roughness,float view_half,float angular_radius,float minimum_roughness){
 float width=max(roughness,minimum_roughness);
 float base=width*width;
 float spread=angular_radius*angular_radius/(.4+3.6*clamp(view_half,0.,1.));
 return sqrt(clamp(base*base+spread,0.,1.));
}
float gaf_player_soft_angle(bool directional,vec3 light_dir,vec3 world,mat4 inverse_view,float light_blue){
 if(gaf_point_soft.x<=0.||!gaf_is_player_point(directional, light_blue))return 0.;
 if(distance(inverse_view[3].xyz,gaf_point_kernel_camera)>.005)return 0.;
 vec3 offset=gaf_point_kernel.xyz-world;
 float d2=dot(offset,offset);
 vec3 direction=(inverse_view*vec4(light_dir,0.)).xyz;
 if(d2>.000001&&dot(direction,offset*inversesqrt(d2))<.9999)return 0.;
 return clamp(gaf_point_soft.x*inversesqrt(max(d2,.000001)),0.,1.);
}
#endif
