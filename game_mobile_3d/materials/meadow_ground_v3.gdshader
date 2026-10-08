shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 meadow_a : source_color = vec4(0.40,0.54,0.25,1.0);
uniform vec4 meadow_b : source_color = vec4(0.53,0.65,0.34,1.0);
uniform vec4 soil_a : source_color = vec4(0.57,0.43,0.26,1.0);
uniform vec4 soil_b : source_color = vec4(0.72,0.57,0.35,1.0);
uniform vec4 rock_a : source_color = vec4(0.30,0.40,0.43,1.0);
uniform vec4 rock_b : source_color = vec4(0.40,0.50,0.52,1.0);
uniform vec3 player_position;
varying vec3 world_position;
varying vec3 face_normal;
varying float terrace_top;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float field(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);
}
void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	face_normal=NORMAL;
	terrace_top=UV2.x;
}
void fragment() {
	vec2 p=world_position.xz;
	vec2 pixel=floor(p*10.0)/10.0;
	float broad=field(pixel*.27);
	float cluster=field(floor(p*3.0)*.39);
	float grain=hash21(floor(p*9.0));
	float lane=min(abs(pixel.x-3.4*sin(pixel.y*.16)),abs(pixel.y-(7.0+2.6*sin(pixel.x*.20))));
	float broken=(field(pixel*2.9)-.5)*1.05+(cluster-.5)*.3;
	float dirt=1.0-smoothstep(.94,1.22,lane+broken);
	float worn=smoothstep(.54,.76,field(pixel*.81))*smoothstep(1.2,1.8,lane)*.38;
	vec3 meadow=mix(meadow_a.rgb,meadow_b.rgb,clamp(broad*.65+cluster*.43,0.0,1.0));
	vec3 soil=mix(soil_a.rgb,soil_b.rgb,field(floor(p*5.0)*.37)*.8+grain*.13);
	vec3 top=mix(meadow,soil,max(dirt,worn))*(.975+grain*.05);
	// Each terrain face carries its actual top in UV2.x, including half-metre steps.
	float below=max(0.0,terrace_top-world_position.y);
	vec2 wall=vec2(dot(world_position.xz,abs(face_normal.zx)),world_position.y);
	vec2 wall_pixel=floor(wall*10.0)/10.0;
	float wall_patch=field(wall_pixel*2.1);
	float fringe=.13+field(vec2(floor(wall.x*10.0)*.48,terrace_top))*.20;
	float turf=1.0-smoothstep(fringe-.035,fringe+.035,below);
	float earth_depth=.62+field(wall_pixel*.9)*.43;
	float stone=smoothstep(earth_depth-.06,earth_depth+.06,below);
	vec3 mineral=mix(rock_a.rgb,rock_b.rgb,wall_patch)*(.96+hash21(floor(wall*12.0))*.08);
	vec3 cliff=mix(soil*.77,mineral,stone);
	cliff=mix(cliff,meadow*.87,turf);
	float contact=1.0-smoothstep(.12,.43,length((p-player_position.xz)/vec2(1.0,.78)));
	ALBEDO=mix(cliff,top,step(.6,face_normal.y))*COLOR.rgb*(1.0-contact*.14);
	ROUGHNESS=1.0; SPECULAR=0.0;
}
