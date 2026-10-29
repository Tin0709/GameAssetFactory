shader_type spatial;
render_mode diffuse_burley, ambient_light_disabled;
uniform bool review_alpha_mask=false;
uniform bool review_path=false;
uniform vec4 review_source_rects[3];
uniform vec4 review_target_rect=vec4(0.0);
uniform float review_emissive_gain=1.0;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D mre_map : filter_nearest, repeat_disable;
uniform bool has_mre=false;
uniform float cutoff=0.3333;

uniform vec3 gaf_sky_delta = vec3(0.0);
uniform sampler2D gaf_indirect_field : filter_linear, repeat_disable;
uniform vec2 gaf_field_origin=vec2(-17.0);
uniform float gaf_field_extent=34.0;
uniform float gaf_specular=0.0;
uniform float gaf_fill_up_ratio=0.35;
varying vec3 gaf_diffuse_fill;
varying float gaf_upward;

void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 gaf_diffuse_fill=textureLod(gaf_indirect_field,(p.xz-gaf_field_origin)/gaf_field_extent,0.0).rgb;
 gaf_upward=clamp((MODEL_NORMAL_MATRIX*NORMAL).y,0.0,1.0);
}
void fragment(){
	vec2 lookup_uv=UV;
	if(review_path && gaf_upward>.99){
	 for(int i=0;i<3;i++){
	  vec4 r=review_source_rects[i];
	  if(all(greaterThanEqual(UV,r.xy-vec2(.00001)))&&all(lessThanEqual(UV,r.zw+vec2(.00001)))){
	   lookup_uv=mix(review_target_rect.xy,review_target_rect.zw,clamp((UV-r.xy)/(r.zw-r.xy),0.,1.));break;
	  }
	 }
	}
	vec4 texel=texture(atlas,lookup_uv);
	if(review_alpha_mask && texel.a<cutoff){discard;}
	ALBEDO=texel.rgb;ROUGHNESS=1.0;SPECULAR=0.0;
	if(has_mre){vec3 packed=texture(mre_map,lookup_uv).rgb;METALLIC=packed.r;ROUGHNESS=packed.g;EMISSION=texel.rgb*packed.b*review_emissive_gain;}
 SPECULAR=gaf_specular;
 EMISSION+=ALBEDO*max(vec3(0.0),gaf_diffuse_fill+gaf_sky_delta)*mix(1.0,gaf_fill_up_ratio,gaf_upward)*(1.0-METALLIC);
}
