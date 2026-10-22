shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D ground_atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D interaction_field : filter_linear, repeat_disable;
uniform sampler2D interaction_previous : filter_linear, repeat_disable;
uniform float interaction_alpha=1.0;
uniform float lighting_grade=0.0;
uniform float wind_time=0.0;
uniform float wind_strength=1.28;
uniform float interaction_strength=1.50;
uniform float family_response=1.0;
uniform float field_extent=34.0;
varying float height_fraction;
varying vec3 planted_root;
varying vec3 ground_albedo;

void vertex(){
	// Export contract: UV2=immutable local root XZ, COLOR=(t,length,phase,1).
	float t=COLOR.r;
	float blade_length=COLOR.g;
	height_fraction=t;
	vec3 root=(MODEL_MATRIX*vec4(UV2.x,0.0,UV2.y,1.0)).xyz;
	planted_root=root;
	// Unit ground blocks repeat UV=(world XZ modulo 1). Sample at the fixed
	// root once per vertex; the root tint must not swim with the bending tips.
	ground_albedo=textureLod(ground_atlas,fract(root.xz),0.0).rgb;
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
	vec2 contact=mix(textureLod(interaction_previous,uv,0.0).rg,
		textureLod(interaction_field,uv,0.0).rg,interaction_alpha)
		*interaction_strength*mix(0.90,1.18,step(0.9,family_response));
	vec2 combined=wind+contact;
	float magnitude=length(combined);
	// Soft bend limit: stronger strokes keep moving instead of hitting a flat
	// hard-clamped plateau. Value and slope stay continuous at1.10rad.
	float excess=max(magnitude-1.10,0.0);
	float angle=min(magnitude,1.10)+0.35*excess/(0.35+excess);
	vec2 world_direction=combined/max(magnitude,0.00001);
	vec3 local_direction=normalize(transpose(mat3(MODEL_MATRIX))*vec3(world_direction.x,0.0,world_direction.y)+vec3(0.0,0.0000001,0.0));
	// Exact circular centerline: fixed root, bounded arc shortening, no stretch.
	float curve=angle*t;
	float offset=angle>0.0001?blade_length*(1.0-cos(curve))/angle:0.5*blade_length*angle*t*t;
	VERTEX.xz+=local_direction.xz*offset;
	VERTEX.y+=angle>0.0001?blade_length*(sin(curve)/angle-t):-blade_length*angle*angle*t*t*t/6.0;
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
	// Match the actual terrain at the base, then retain the authored leaf/seed
	// colors above it. No dark root band or extra per-fragment texture sample.
	float root_blend=1.0-smoothstep(0.02,0.62,height_fraction);
	ALBEDO=mix(ALBEDO,ground_albedo,root_blend);
	vec3 face=FRONT_FACING?NORMAL:-NORMAL;
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	vec3 leaf_normal=normalize(mix(face,up,mix(0.56,0.54,lighting_grade)));
	NORMAL=normalize(mix(leaf_normal,up,root_blend));
	ROUGHNESS=1.0;SPECULAR=0.0;
}
