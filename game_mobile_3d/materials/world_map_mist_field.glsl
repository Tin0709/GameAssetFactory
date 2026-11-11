#[compute]
#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform writeonly image3D volume;
layout(set=0,binding=1) uniform sampler2D noise_field;
layout(set=0,binding=3) uniform sampler3D light_field;
layout(std140,set=0,binding=2) uniform Parameters{
 vec4 origin;    // World ray origin; near entry distance in w.
 vec4 origin_dx; // Horizontal origin delta; near extinction in w.
 vec4 origin_dy; // Vertical origin delta; near reference height in w.
 vec4 ray;       // World ray direction, near scatter gain
 vec4 ray_dx;    // Ray delta, near scatter world X
 vec4 ray_dy;    // Ray delta, near scatter world Z
 vec4 medium; // density, height falloff, base height, time
 vec4 scatter; // linear RGB, energy
 vec4 subject; // world XYZ, warm strength
 vec4 warm; // linear RGB, range
 vec4 integration; // start distance, far view-depth, noise strength, recovered radial warm source
 vec4 light_origin; // world lattice origin, enabled
 vec4 light_step; // world lattice spacing, occlusion floor
 vec4 light_size; // world lattice dimensions, near-layer fade start
 vec4 path_position_range;
 vec4 path_rgb_gain;
} p;
const float FOREST_SCATTER_FULL_RADIUS_M = 6.0;
const float FOREST_SCATTER_END_RADIUS_M = 15.0;
float scatter_visibility(vec3 point){
 if(p.light_origin.w<.5)return 1.;
 vec3 cell=(point-p.light_origin.xyz)/p.light_step.xyz;
 if(any(lessThan(cell,vec3(0)))||any(greaterThan(cell,p.light_size.xyz-1.)))return 1.;
 float v=textureLod(light_field,(cell+.5)/p.light_size.xyz,0.).r;
 // Recovered finish core; producer here is our static world field, not the
 // original radial screen-space blur. Never modify optical extinction.
 return p.light_step.w+(1.-p.light_step.w)*v*v;
}
// Independently authored radial source. Source proof establishes exponent2;
// using it in this original participating medium is a reconstruction.
float local_point_weight(vec3 offset,float radius,bool recovered){
 float remaining=recovered?max(0.,1.-dot(offset,offset)/(radius*radius)):max(0.,1.-length(offset)/radius);
 return remaining*remaining;
}
vec3 path_light(vec3 point){
 if(p.path_rgb_gain.w<=0.)return vec3(0.);
 vec3 offset=point-p.path_position_range.xyz;
 return p.path_rgb_gain.rgb*(p.path_rgb_gain.w*local_point_weight(offset,p.path_position_range.w,true));
}
float near_optical(vec3 origin,vec3 ray,float ray_length,float start,float end){
 float strength=p.origin_dx.w;
 if(strength<=0.)return 0.;
 float entry=p.origin.w/ray_length;
 float exit=p.integration.x/ray_length;
 float a=max(start,entry);
 float b=min(end,exit);
 if(b<=a)return 0.;
 float h0=clamp(-(origin.y+ray.y*a-p.origin_dy.w)*p.medium.y,-16.,2.);
 float h1=clamp(-(origin.y+ray.y*b-p.origin_dy.w)*p.medium.y,-16.,2.);
 float height=abs(h1-h0)>.0001?(exp(h1)-exp(h0))/(h1-h0):exp(h0);
 float fraction=((a+b)*.5-entry)/max(exit-entry,.0001);
 // Preserve the entry fit and extend the middle of the layer before the far bank.
 float fade=1.-smoothstep(clamp(p.light_size.w,.4,.95),1.,fraction);
 return strength*height*fade*(b-a)*ray_length;
}
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
  float nearby=near_optical(origin,ray,ray_length,previous,d);
  if(nearby>0.){
   float entry=p.origin.w/ray_length;
   vec3 point=origin+ray*((max(previous,entry)+min(d,near_z))*.5);
   float warmth=p.subject.w*local_point_weight(point-(p.subject.xyz+vec3(0.0,1.4,0.0)),p.warm.w,p.integration.w>.5);
   vec3 light=p.scatter.rgb*p.scatter.w+p.warm.rgb*(warmth*.25);
   if(p.ray.w>0.0){
    vec2 delta=point.xz-vec2(p.ray_dx.w,p.ray_dy.w);
    float region=1.0-smoothstep(FOREST_SCATTER_FULL_RADIUS_M*FOREST_SCATTER_FULL_RADIUS_M,
      FOREST_SCATTER_END_RADIUS_M*FOREST_SCATTER_END_RADIUS_M,dot(delta,delta));
    light+=p.scatter.rgb*p.scatter.w*(p.ray.w*region);
   }
   light=light*scatter_visibility(point)+path_light(point);
   scattered+=exp(-optical)*(1.0-exp(-nearby))*light;optical+=nearby;
  }
  float start=max(previous,near_z);
  if(d>start){
   vec3 a=origin+ray*start;vec3 b=origin+ray*d;vec3 point=(a+b)*0.5;
   float h0=clamp(-(a.y-p.medium.z)*p.medium.y,-16.0,2.0);
   float h1=clamp(-(b.y-p.medium.z)*p.medium.y,-16.0,2.0);
   float height=abs(h1-h0)>.0001?(exp(h1)-exp(h0))/(h1-h0):exp(h0);
   float n=textureLod(noise_field,(point.xz+vec2(p.medium.w*.045,-p.medium.w*.025))/256.0+.5,0.0).r;
   float bank=smoothstep(.30,.68,n);float variation=mix(1.0,bank*bank*1.8,p.integration.z);
   float tau=p.medium.x*height*variation*(d-start)*ray_length;
   float warmth=p.subject.w*local_point_weight(point-(p.subject.xyz+vec3(0.0,1.4,0.0)),p.warm.w,p.integration.w>.5);
   vec3 light=p.scatter.rgb*p.scatter.w+p.warm.rgb*(warmth*.25);
   light=light*scatter_visibility(point)+path_light(point);
   scattered+=exp(-optical)*(1.0-exp(-tau))*light;optical+=tau;
  }
  imageStore(volume,ivec3(pixel,i),vec4(scattered,exp(-optical)));previous=d;
 }
}

