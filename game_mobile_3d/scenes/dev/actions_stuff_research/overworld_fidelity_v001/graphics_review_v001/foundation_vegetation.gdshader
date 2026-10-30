shader_type spatial;
render_mode cull_disabled, diffuse_burley, ambient_light_disabled;
#include "vegetation_material_math.gdshaderinc"
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D mre_map : filter_nearest, repeat_disable;
uniform sampler2D interaction_field : filter_linear, repeat_disable;
uniform sampler2D interaction_previous : filter_linear, repeat_disable;
uniform sampler2D ground_atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 ground_uv=vec4(0.0);
uniform bool has_mre=false;
uniform bool tinted_grass=false;
uniform bool review_grass_material=false;
uniform vec3 review_backlight_rgb=vec3(0.18);
uniform float review_tip_height=0.0;
uniform float review_tip_falloff=1.0;
uniform sampler2D review_grass_noise : filter_nearest, repeat_enable;
uniform float review_gust_height=0.0;
uniform float review_gust_falloff=1.0;
uniform float review_scatter_strength=1.0;
uniform vec3 review_world_color=vec3(0.0);
uniform vec2 review_world_origin_cm=vec2(0.0);
uniform float review_time=0.0;
varying vec2 review_world_cm;
uniform vec3 base_tint=vec3(0.0);
uniform vec3 tip_tint=vec3(0.0);
uniform float cutoff=0.3333;
uniform float wind_time=0.0;
uniform float wind_intensity=0.0;
uniform vec2 wind_direction=vec2(1.0,0.0);
uniform float frequency=0.375;
uniform float interaction_alpha=1.0;
uniform float interaction_strength=1.0;
uniform float field_extent=34.0;
uniform float lighting_grade=1.0;
varying float height_fraction;
varying vec3 root_color;
varying vec3 wrapped_normal_world;

uniform float review_irradiance_scale=1.0;
uniform vec3 gaf_sky_delta = vec3(0.0);
uniform sampler2D gaf_indirect_field : filter_linear, repeat_disable;
uniform vec2 gaf_field_origin=vec2(-17.0);
uniform float gaf_field_extent=34.0;
uniform float gaf_specular=0.0;
uniform float gaf_fill_up_ratio=0.35;
varying vec3 gaf_diffuse_fill;
varying float gaf_upward;

void vertex(){
	// Full float custom attribute: normalized height, blade height, phase, response.
	review_world_cm=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz*vec2(100.,-100.)+review_world_origin_cm;
	float u=CUSTOM0.x;
	float h=CUSTOM0.y;
	height_fraction=u;
	vec3 root=(MODEL_MATRIX*vec4(UV2.x,0.0,UV2.y,1.0)).xyz;
	vec2 direction=normalize(wind_direction);
	float spatial=dot(root.xz,direction);
	float phase=CUSTOM0.z+spatial*0.6283185+INSTANCE_CUSTOM.r;
	vec2 bend=direction*(0.28*sin(wind_time*frequency*6.2831853+phase)+0.055*sin(wind_time*6.2831853*0.625+spatial*0.34));
	bend+=vec2(-direction.y,direction.x)*0.025*sin(wind_time*6.2831853*0.25+phase);
	bend*=wind_intensity*CUSTOM0.w;
	vec2 field_uv=(root.xz+vec2(field_extent*0.5))/field_extent;
	float inside=step(0.0,field_uv.x)*step(field_uv.x,1.0)*step(0.0,field_uv.y)*step(field_uv.y,1.0);
	vec2 contact=mix(textureLod(interaction_previous,field_uv,0.0).rg,textureLod(interaction_field,field_uv,0.0).rg,interaction_alpha)*inside;
	bend+=contact*interaction_strength;
	float theta=min(length(bend),0.75);
	vec2 heading=bend/max(length(bend),0.000001);
	float planar=h*(1.0-cos(theta*u))/max(theta,0.000001);
	float vertical=h*sin(theta*u)/max(theta,0.000001)-h*u;
	if(theta<0.0001){planar=0.5*h*theta*u*u;vertical=-h*theta*theta*u*u*u/6.0;}
	vec3 world_offset=vec3(heading.x*planar,vertical,heading.y*planar);
	VERTEX+=(inverse(MODEL_MATRIX)*vec4(world_offset,0.0)).xyz;
	if(tinted_grass)NORMAL=normalize(NORMAL*0.35+vec3(0.0,0.65,0.0));
	wrapped_normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	root_color=textureLod(ground_atlas,mix(ground_uv.xy,ground_uv.zw,fract(vec2(root.x,-root.z))),0.0).rgb;
 gaf_diffuse_fill=textureLod(gaf_indirect_field,(root.xz-gaf_field_origin)/gaf_field_extent,0.0).rgb;
 gaf_upward=clamp((MODEL_NORMAL_MATRIX*NORMAL).y,0.0,1.0);
}
void fragment(){
	vec4 texel=texture(atlas,UV);
	vec3 color=texel.rgb;
	vec3 scatter_color=color;
	if(tinted_grass){
		// Preserve the authored upward grass normals on both sides, as in the
		// existing lab. Automatic backface flipping otherwise makes dark stripes.
		NORMAL=normalize(mat3(VIEW_MATRIX)*wrapped_normal_world);
		if(review_grass_material){
		 vec3 blade=vegetation_blade_color(base_tint,tip_tint,UV.y,review_tip_height,review_tip_falloff,texel.r);
		 scatter_color=vegetation_scattering(blade,review_scatter_strength);
		 vec2 coarse=review_world_cm*.00004+vec2(fract(review_time*.1),fract(-review_time*.1));
		 vec2 fine=review_world_cm*.004+vec2(fract(-review_time*.2),fract(review_time*.1));
		 color=vegetation_gust_color(blade,review_world_color,UV.y,review_gust_height,review_gust_falloff,texture(review_grass_noise,coarse).r,texture(review_grass_noise,fine).g);
		}else{color=mix(base_tint,tip_tint,clamp(height_fraction,0.0,1.0))*(vec3(0.65)+0.35*texel.rgb);}
		color=mix(root_color,color,smoothstep(0.0,0.18,height_fraction));
	}
	ALBEDO=color;ALPHA=texel.a;ALPHA_SCISSOR_THRESHOLD=cutoff;
	ROUGHNESS=1.0;SPECULAR=0.0;
	if(has_mre){vec3 packed=texture(mre_map,UV).rgb;METALLIC=packed.r;ROUGHNESS=packed.g;}
	// Inferred wrapped backlighting; no claim of matching native two-sided shader.
	BACKLIGHT=review_grass_material ? scatter_color*review_backlight_rgb : color*vec3(0.18);
 SPECULAR=gaf_specular;
 EMISSION+=review_irradiance_scale*ALBEDO*max(vec3(0.0),gaf_diffuse_fill+gaf_sky_delta)*mix(1.0,gaf_fill_up_ratio,gaf_upward)*(1.0-METALLIC);
}
