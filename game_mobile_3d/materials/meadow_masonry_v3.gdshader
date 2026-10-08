shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying vec3 world_position;
varying vec3 object_normal;
float hash31(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; object_normal=NORMAL; }
void fragment() {
	float pixels=hash31(floor(world_position*vec3(9.0,12.0,9.0)));
	float blocks=hash31(floor(world_position*vec3(2.3,3.8,2.3)));
	float moss=step(.57,blocks)*smoothstep(.25,.82,object_normal.y);
	vec3 stone=COLOR.rgb*vec3(.91,1.01,1.08)*(.86+blocks*.19+pixels*.08);
	vec3 green=vec3(.20,.28,.085)*(.8+pixels*.3);
	ALBEDO=mix(stone,green,moss*.48);
	ROUGHNESS=.97; SPECULAR=0.0;
}
