shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform float albedo_gain = 0.66;
varying vec3 world_position;
float hash31(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float fleck = hash31(floor(world_position*8.0));
	float patch = hash31(floor(world_position*vec3(3.0,5.0,3.0)));
	ALBEDO = COLOR.rgb*(0.93+patch*0.10+step(0.82,fleck)*0.06)*albedo_gain;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}
