shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying vec3 world_position;
float hash31(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	// Leaf-sized rectangles add texture within broad authored masses, not stripes.
	float patch=hash31(floor(world_position*vec3(3.1,4.4,3.1)));
	float leaf=hash31(floor(world_position*vec3(9.0,12.0,9.0)));
	float fleck=step(.74,leaf)*.10-step(leaf,.18)*.06;
	ALBEDO=COLOR.rgb*(.88+patch*.18+fleck)*.91;
	ROUGHNESS=.96; SPECULAR=0.0;
}
