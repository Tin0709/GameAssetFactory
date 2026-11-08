#[compute]
#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform writeonly image3D volume;
layout(set=0,binding=1) uniform sampler2D noise_field;
layout(std140,set=0,binding=2) uniform Parameters{
 vec4 origin;vec4 origin_dx;vec4 origin_dy;
 vec4 ray;vec4 ray_dx;vec4 ray_dy;
 vec4 medium; // density, height falloff, base height, time
 vec4 scatter; // linear RGB, energy
 vec4 subject; // world XYZ, warm strength
 vec4 warm; // linear RGB, range
 vec4 integration; // start distance, far view-depth, noise strength, reserved
} p;
void main(){
 ivec3 size=imageSize(volume);ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
 if(any(greaterThanEqual(pixel,size.xy)))return;
 vec2 uv=(vec2(pixel)+0.5)/vec2(size.xy);
 vec3 origin=p.origin.xyz+p.origin_dx.xyz*uv.x+p.origin_dy.xyz*uv.y;
 vec3 ray=p.ray.xyz+p.ray_dx.xyz*uv.x+p.ray_dy.xyz*uv.y;
 float ray_length=length(ray);float near_z=p.integration.x/ray_length;
 vec3 scattered=vec3(0.0);float optical=0.0;float previous=0.0;
 imageStore(volume,ivec3(pixel,0),vec4(0.0,0.0,0.0,1.0));
 for(int i=1;i<32;i++){
  float d=pow(float(i)/31.0,2.0)*p.integration.y;
  float start=max(previous,near_z);
  if(d>start){
   vec3 a=origin+ray*start;vec3 b=origin+ray*d;vec3 point=(a+b)*0.5;
   float h0=clamp(-(a.y-p.medium.z)*p.medium.y,-16.0,2.0);
   float h1=clamp(-(b.y-p.medium.z)*p.medium.y,-16.0,2.0);
   float height=abs(h1-h0)>.0001?(exp(h1)-exp(h0))/(h1-h0):exp(h0);
   float n=textureLod(noise_field,(point.xz+vec2(p.medium.w*.045,-p.medium.w*.025))/256.0+.5,0.0).r;
   float bank=smoothstep(.30,.68,n);float variation=mix(1.0,bank*bank*1.8,p.integration.z);
   float tau=p.medium.x*height*variation*(d-start)*ray_length;
   float warmth=p.subject.w*pow(max(0.0,1.0-length(point-(p.subject.xyz+vec3(0.0,1.4,0.0)))/p.warm.w),2.0);
   vec3 light=p.scatter.rgb*p.scatter.w+p.warm.rgb*(warmth*.25);
   scattered+=exp(-optical)*(1.0-exp(-tau))*light;optical+=tau;
  }
  imageStore(volume,ivec3(pixel,i),vec4(scattered,exp(-optical)));previous=d;
 }
}
