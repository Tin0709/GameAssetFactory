shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D ground_grain:filter_nearest,repeat_enable;
varying vec2 world_xz;
void vertex(){world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
 vec2 uv=world_xz/8.0;
 vec2 grain=texture(ground_grain,uv).rg;
 vec3 ground=COLOR.rgb*(.89+.19*grain.r);
 if(world_xz.y < -49.999 && abs(world_xz.x)<4.0){
  float along=world_xz.y;
  float center=1.9*sin(along*.24)+.55*sin(along*.57);
  float edge=abs(world_xz.x-center)+.32*(grain.g-.5)+.12*(grain.r-.5);
  float path=(1.-smoothstep(.68,1.04,edge))*(1.-smoothstep(63.,69.,-along));
  ground=mix(ground,vec3(.345,.224,.106)*(.85+.23*grain.r),path);
 }
 ALBEDO=ground;
 ROUGHNESS=1.;
}
