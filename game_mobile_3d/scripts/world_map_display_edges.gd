extends RefCounted
## Independently authored edge-oriented display resampling, no temporal history.
## Local contrast / edge search / coverage follows the public FXAA principles.
## Controls are observed reference values. It is NOT bit-exact native FXAA.
const FRAGMENT="""#version 450
layout(set=0,binding=0) uniform sampler2D encoded_scene;
layout(set=0,binding=1,std430) readonly buffer Baseline{vec4 base[];};
layout(push_constant,std430) uniform Settings{vec4 settings;vec4 air;};
layout(location=0) out vec4 result;
const vec3 luma_weights=vec3(.299,.587,.114);
const float distances[12]=float[12](1.,1.5,2.,2.,2.,2.,2.,2.,2.,2.,4.,8.);
vec3 read_color(vec2 at){
 vec2 half_pixel=.5/vec2(textureSize(encoded_scene,0));
 return textureLod(encoded_scene,clamp(at,half_pixel,1.-half_pixel),0.).rgb;
}
float brightness(vec2 at){return dot(read_color(at),luma_weights);}
vec3 linear_display(vec3 c){return mix(c/12.92,pow((c+.055)/1.055,vec3(2.4)),greaterThan(c,vec3(.04045)));}
void main(){
 vec2 pixel=1./vec2(textureSize(encoded_scene,0));vec2 uv=gl_FragCoord.xy*pixel;
 vec3 original=read_color(uv);float m=dot(original,luma_weights);
 float n=brightness(uv-vec2(0,pixel.y)),s=brightness(uv+vec2(0,pixel.y));
 float w=brightness(uv-vec2(pixel.x,0)),e=brightness(uv+vec2(pixel.x,0));
 float low=min(m,min(min(n,s),min(w,e))),high=max(m,max(max(n,s),max(w,e)));
 float range=high-low;
 if(range<max(.0833,high*.166)){result=vec4(linear_display(original),1.);return;}
 float nw=brightness(uv-pixel),ne=brightness(uv+vec2(pixel.x,-pixel.y));
 float sw=brightness(uv+vec2(-pixel.x,pixel.y)),se=brightness(uv+pixel);
 float horizontal_strength=abs(nw+sw-2.*w)+2.*abs(n+s-2.*m)+abs(ne+se-2.*e);
 float vertical_strength=abs(nw+ne-2.*n)+2.*abs(w+e-2.*m)+abs(sw+se-2.*s);
 bool horizontal=horizontal_strength>=vertical_strength;
 float near_value=horizontal?n:w,far_value=horizontal?s:e;
 float near_gradient=near_value-m,far_gradient=far_value-m;
 bool negative=abs(near_gradient)>=abs(far_gradient);
 float pair_average=.5*(m+(negative?near_value:far_value));
 float required=.25*max(abs(near_gradient),abs(far_gradient));
 vec2 normal=(horizontal?vec2(0,pixel.y):vec2(pixel.x,0))*(negative?-1.:1.);
 vec2 tangent=horizontal?vec2(pixel.x,0):vec2(0,pixel.y);
 vec2 center=uv+.5*normal;
 vec2 left=center-tangent,right=center+tangent;
 float dl=brightness(left)-pair_average,dr=brightness(right)-pair_average;
 for(int i=1;i<12;i++){
  bool stop_left=abs(dl)>=required,stop_right=abs(dr)>=required;
  if(stop_left&&stop_right)break;
  if(!stop_left)left-=distances[i]*tangent;
  if(!stop_right)right+=distances[i]*tangent;
  if(i<11){if(!stop_left)dl=brightness(left)-pair_average;if(!stop_right)dr=brightness(right)-pair_average;}
 }
 float a=horizontal?uv.x-left.x:uv.y-left.y;
 float b=horizontal?right.x-uv.x:right.y-uv.y;
 float endpoint=a<b?dl:dr;
 bool valid=(endpoint<0.)!=(m-pair_average<0.);
 float edge=valid?.5-min(a,b)/max(a+b,1e-8):0.;
 float mean=((n+s+w+e)*2.+nw+ne+sw+se)/12.;
 float coverage=clamp(abs(mean-m)/max(range,1e-8),0.,1.);
 coverage=coverage*coverage*(3.-2.*coverage);coverage=coverage*coverage*.75;
 vec3 filtered=read_color(uv+max(edge,coverage)*normal);
 // Original phase fade preserves the approved Noon; not a recovered native clock.
 result=vec4(linear_display(mix(original,filtered,base[1].z)),1.);
}
"""
