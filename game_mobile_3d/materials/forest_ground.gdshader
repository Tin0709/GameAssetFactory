shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 meadow_a : source_color = vec4(0.24,0.37,0.15,1.0);
uniform vec4 meadow_b : source_color = vec4(0.36,0.48,0.21,1.0);
uniform vec4 soil_a : source_color = vec4(0.52,0.40,0.24,1.0);
uniform vec4 soil_b : source_color = vec4(0.66,0.53,0.33,1.0);
uniform vec3 player_position;
varying vec3 world_position;
varying float top_face;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float field(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	top_face = step(0.6,NORMAL.y);
}
void fragment() {
	vec2 p = world_position.xz;
	vec2 pixel = floor(p*8.0)/8.0;
	float broad = field(pixel*0.28);
	float cluster = field(floor(p*3.0)*0.37);
	float grain = hash21(floor(p*10.0));
	float lane = min(abs(pixel.x-3.4*sin(pixel.y*0.16)),abs(pixel.y-(7.0+2.6*sin(pixel.x*0.20))));
	float broken_edge = (field(pixel*3.4)-0.5)*0.8 + (cluster-0.5)*0.22;
	float dirt = (1.0-smoothstep(0.96,1.22,lane+broken_edge))*step(world_position.y,1.08);
	vec3 meadow = mix(meadow_a.rgb,meadow_b.rgb,clamp(broad*0.8+cluster*0.28,0.0,1.0));
	vec3 soil = mix(soil_a.rgb,soil_b.rgb,field(pixel*1.3)*0.70 + step(0.87,grain)*0.16);
	vec3 top_color = mix(meadow,soil,dirt)*(0.97+grain*0.06);
	// Raised earth has a mossy lip, dark mineral bands and sparse broad pixel seams.
	float band = step(0.87,fract(world_position.y*2.0));
	vec3 cliff = mix(soil_a.rgb*0.49,soil_b.rgb*0.70,broad)*(1.0-band*0.10);
	float lip = smoothstep(0.70,0.94,fract(world_position.y+0.02));
	cliff = mix(cliff,meadow*0.68,lip);
	float player_contact = 1.0-smoothstep(0.10,0.48,length((p-player_position.xz)/vec2(1.0,0.78)));
	ALBEDO = mix(cliff,top_color,top_face)*(1.0-player_contact*0.18)*COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
