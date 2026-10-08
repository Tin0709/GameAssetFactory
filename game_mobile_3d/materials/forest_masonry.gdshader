shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying vec3 world_position;
varying vec3 local_position;
varying vec3 object_normal;
float hash31(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	local_position = VERTEX;
	object_normal = NORMAL;
}
void fragment() {
	float pixels = hash31(floor(world_position*9.0));
	float blocks = hash31(floor(world_position*3.0));
	float patches = hash31(floor(world_position*vec3(2.0,4.0,2.0)));
	float moss = step(0.72,patches)*smoothstep(0.25,0.8,object_normal.y);
	vec3 base = COLOR.rgb;
	vec3 mottled = base*(0.90+blocks*0.13+pixels*0.07);
	ALBEDO = mix(mottled,mottled*vec3(0.67,0.91,0.34),moss*0.75);
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
}
