// Original normal-dependent calibration. Caller supplies private/original SH data.
// MEAN-radiance SH9, right-handed native(x,z,-y)->Godot Y-up. Returns E/pi.
uniform bool gaf_directional_fill_enabled=false;
uniform vec3 gaf_directional_sh[9];
uniform vec3 gaf_directional_residual=vec3(0.0);
vec3 gaf_directional_response(vec3 normal_y){
 vec3 n=vec3(normal_y.x,-normal_y.z,normal_y.y);
 const float k0=.8862269520759583,k1=1.0233267545700073;
 const float k2=.24770796298980713,r3=1.7320507764816284;
 float x=n.x,y=n.y,z=n.z;
 float b[9]=float[9](k0,-y*k1,z*k1,-x*k1,2.*r3*k2*x*y,
  -2.*r3*k2*y*z,k2*(3.*z*z-1.),-2.*r3*k2*x*z,r3*k2*(x*x-y*y));
 vec3 value=vec3(0.);for(int i=0;i<9;i++){value+=gaf_directional_sh[i]*b[i];}
 return 4.*max(value,vec3(0.));
}
vec3 gaf_directional_factor(vec3 normal_y){
 vec3 top=gaf_directional_response(vec3(0.,1.,0.));
 vec3 ratio=gaf_directional_response(normal_y)/max(top,vec3(.000001));
 return mix(ratio,vec3(1.),clamp(gaf_directional_residual,vec3(0.),vec3(1.)));
}
