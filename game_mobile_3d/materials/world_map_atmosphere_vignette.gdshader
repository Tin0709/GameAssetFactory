shader_type canvas_item;
render_mode unshaded, blend_mul;
uniform float strength=0.0;
void fragment(){
	vec2 p=(UV-0.5)*vec2(1.0,0.85);
	float shade=1.0-strength*smoothstep(0.26,0.69,length(p));
	COLOR=vec4(vec3(shade),1.0);
}
