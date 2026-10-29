shader_type spatial;
render_mode diffuse_burley, ambient_light_disabled;
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
	vec4 texel=texture(atlas,UV);
	ALBEDO=texel.rgb;ROUGHNESS=1.0;SPECULAR=0.0;
	if(has_mre){vec3 packed=texture(mre_map,UV).rgb;METALLIC=packed.r;ROUGHNESS=packed.g;EMISSION=texel.rgb*packed.b;}
 SPECULAR=gaf_specular;
 EMISSION+=ALBEDO*max(vec3(0.0),gaf_diffuse_fill+gaf_sky_delta)*mix(1.0,gaf_fill_up_ratio,gaf_upward)*(1.0-METALLIC);
}
