shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D interaction_field : filter_linear, repeat_disable;
uniform float wind_time=0.0;
uniform float wind_strength=1.0;
uniform float interaction_strength=1.0;
uniform float family_response=1.0;
uniform float field_extent=34.0;
varying float height_fraction;
varying vec3 planted_root;

void vertex(){
	// Export contract: UV2=immutable local root XZ, COLOR=(t,length,phase,1).
	float t=COLOR.r;
	float blade_length=COLOR.g;
	height_fraction=t;
	vec3 root=(MODEL_MATRIX*vec4(UV2.x,0.0,UV2.y,1.0)).xyz;
	planted_root=root;
	vec2 direction=normalize(vec2(0.825,0.565));
	vec2 crosswind=vec2(-direction.y,direction.x);
	float spatial=dot(root.xz,direction);
	float phase=spatial*0.58+INSTANCE_CUSTOM.r*0.38;
	float gust=0.5+0.5*sin(wind_time*1.130973-spatial*0.23);
	// Authored faster/broader motion from the user's TikTok visual preference.
	float main_sway=0.20+0.29*sin(wind_time*5.340708-phase)
		+0.105*sin(wind_time*8.482300+spatial*0.31);
	vec2 wind=(direction*main_sway*(0.78+0.22*gust)
		+crosswind*0.15*sin(wind_time*4.084070-spatial*0.36))*wind_strength*family_response;
	vec2 uv=(root.xz+field_extent*0.5)/field_extent;
	vec2 contact=textureLod(interaction_field,uv,0.0).rg*interaction_strength*mix(0.90,1.18,step(0.9,family_response));
	vec2 combined=wind+contact;
	float angle=min(length(combined),1.18);
	vec2 world_direction=combined/max(length(combined),0.00001);
	vec3 local_direction=normalize(transpose(mat3(MODEL_MATRIX))*vec3(world_direction.x,0.0,world_direction.y)+vec3(0.0,0.0000001,0.0));
	// Exact circular centerline: fixed root, bounded arc shortening, no stretch.
	float curve=angle*t;
	float offset=blade_length*(1.0-cos(curve))/max(angle,0.00001);
	VERTEX.xz+=local_direction.xz*offset;
	VERTEX.y+=blade_length*(sin(curve)/max(angle,0.00001)-t);
	// Small coherent card-tip ripple, subordinate to broad whole-blade sway.
	VERTEX.xz+=local_direction.xz*(blade_length*pow(t,4.0)*0.009*sin(wind_time*10.681415+COLOR.b*6.283185+phase))*wind_strength;
	vec3 axis=normalize(vec3(local_direction.z,0.0000001,-local_direction.x));
	NORMAL=normalize(NORMAL*cos(curve)+cross(axis,NORMAL)*sin(curve)+axis*dot(axis,NORMAL)*(1.0-cos(curve)));
}

void fragment(){
	vec4 texel=texture(atlas,UV);
	ALPHA=texel.a;ALPHA_SCISSOR_THRESHOLD=0.5;
	float variation=0.97+0.06*sin(planted_root.x*0.19+planted_root.z*0.27);
	ALBEDO=texel.rgb*variation*mix(0.96,1.03,height_fraction);
	vec3 face=FRONT_FACING?NORMAL:-NORMAL;
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL=normalize(mix(face,up,0.56));
	ROUGHNESS=1.0;SPECULAR=0.0;
}
