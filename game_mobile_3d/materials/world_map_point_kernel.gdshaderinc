// Original algebraic bridge from Godot's quartic range window to a
// source-verified squared-radius window. No native shader code is embedded.
#ifndef GAF_POINT_KERNEL_HELPER
#define GAF_POINT_KERNEL_HELPER
global uniform vec4 gaf_point_kernel;
global uniform vec3 gaf_point_kernel_camera;
float gaf_point_transfer(bool directional,vec3 light_dir,vec2 screen,float depth,mat4 inverse_projection,mat4 inverse_view){
 if(directional||gaf_point_kernel.w<=0.)return 1.;
 if(distance(inverse_view[3].xyz,gaf_point_kernel_camera)>.005)return 1.;
 vec4 view=inverse_projection*vec4(screen*2.-1.,depth,1.);
 vec3 world=(inverse_view*vec4(view.xyz/view.w,1.)).xyz;
 vec3 offset=gaf_point_kernel.xyz-world;
 float length2=dot(offset,offset);
 vec3 direction=(inverse_view*vec4(light_dir,0.)).xyz;
 if(length2>.000001&&dot(direction,offset*inversesqrt(length2))<.9999)return 1.;
 float q=length2/(gaf_point_kernel.w*gaf_point_kernel.w);
 float denominator=1.+max(q,0.);
 return 1./(denominator*denominator);
}
#endif
