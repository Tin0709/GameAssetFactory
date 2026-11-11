render_mode diffuse_burley, ambient_light_disabled;
#include "height_fill.gdshaderinc"
#include "ground_contact.gdshaderinc"
#ifdef GAF_CLOUD_PROJECTOR
#include "cloud_v001/cloud_projector.gdshaderinc"
#endif
#include "directional_fill_v001/directional_fill.gdshaderinc"
#include "leaf_material_v001/leaf_material.gdshaderinc"
#include "res://materials/world_map_crown_wind.gdshaderinc"
uniform bool gaf_leaf_material_enabled=false;
uniform sampler2D gaf_leaf_vertex_colors : filter_nearest, repeat_disable;
uniform float gaf_leaf_scatter_strength=0.0;
uniform sampler2D gaf_leaf_wind_pattern : filter_nearest, repeat_enable;
uniform vec2 gaf_leaf_wind = vec2(0.0);
uniform sampler2D gaf_crown_mask : filter_nearest, repeat_disable;
uniform sampler2D gaf_crown_pattern : filter_linear, repeat_enable;
uniform vec2 gaf_crown_wind = vec2(0.0);
varying vec2 gaf_leaf_weights;
uniform bool review_alpha_mask=false;
uniform bool gaf_rock_bounce=false;
uniform float review_leaf_hue=0.0;
uniform vec3 review_backlight_rgb=vec3(0.0);
uniform bool review_path=false;
uniform bool review_path_blend=false;
uniform vec4 review_grass_rects[2];
uniform vec4 review_source_rects[3];
uniform vec4 review_target_rect=vec4(0.0);
uniform float review_emissive_gain=1.0;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D mre_map : filter_nearest, repeat_disable;
uniform bool has_mre=false;
uniform float cutoff=0.3333;

uniform float review_irradiance_scale=1.0;
uniform vec3 gaf_sky_delta = vec3(0.0);
uniform sampler2D gaf_indirect_field : filter_linear, repeat_disable;
uniform vec2 gaf_field_origin=vec2(-17.0);
uniform float gaf_field_extent=34.0;
uniform float gaf_specular=0.0;
uniform float gaf_fill_up_ratio=0.35;
uniform bool gaf_height_aware_fill=false;
uniform vec3 gaf_open_fill=vec3(0.0);
uniform float gaf_fill_height_fade=0.5;
varying vec3 gaf_diffuse_fill;
varying float gaf_upward;

void vertex(){
 gaf_leaf_weights=gaf_leaf_material_enabled ? texelFetch(gaf_leaf_vertex_colors,ivec2(VERTEX_ID,0),0).rg : vec2(0.);
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 if(gaf_leaf_material_enabled && gaf_leaf_wind.y > 0.0 && gaf_leaf_weights.g > 0.0){
  vec3 relative = p - MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
  if(abs(relative.y) >= 0.2){
   vec3 offset = gaf_leaf_wind_offset(gaf_leaf_wind_pattern, relative, gaf_leaf_wind.x, gaf_leaf_wind.y * gaf_leaf_weights.g);
   VERTEX += inverse(mat3(MODEL_MATRIX)) * offset;
   p += offset;
  }
 } else if (gaf_crown_wind.y > 0.0) {
  int width = textureSize(gaf_crown_mask, 0).x;
  float weight = texelFetch(gaf_crown_mask, ivec2(VERTEX_ID % width, VERTEX_ID / width), 0).r;
  if (weight > 0.0) {
   vec3 offset = gaf_leaf_world_drift(gaf_crown_pattern, p, MODEL_MATRIX[3].y, gaf_crown_wind, weight);
   VERTEX += inverse(mat3(MODEL_MATRIX)) * offset;
   p += offset;
  }
 }
 gaf_diffuse_fill=gaf_resolve_fill(textureLod(gaf_indirect_field,(p.xz-gaf_field_origin)/gaf_field_extent,0.0),p.y,gaf_open_fill,gaf_fill_height_fade,gaf_height_aware_fill);
 gaf_upward=clamp((MODEL_NORMAL_MATRIX*NORMAL).y,0.0,1.0);
}
bool gaf_inside_tile(vec2 uv,vec4 rect){
 return all(greaterThanEqual(uv,rect.xy-vec2(.00001)))&&all(lessThanEqual(uv,rect.zw+vec2(.00001)));
}

float gaf_path_noise(vec2 cell){
 return fract(52.9829189*fract(dot(cell,vec2(.06711056,.00583715))));
}

vec3 gaf_meadow_path_layer(vec2 uv,vec2 world_xz){
 vec2 tile_uv=vec2(0.);
 vec4 grass_rect=review_grass_rects[0];
 bool matched=false;
 for(int i=0;i<2;i++){
  vec4 rect=review_grass_rects[i];
  if(gaf_inside_tile(uv,rect)){
   tile_uv=clamp((uv-rect.xy)/(rect.zw-rect.xy),0.,1.);
   grass_rect=rect;
   matched=true;
   break;
  }
 }
 bool from_grass=matched;
 if(!matched){
  for(int i=0;i<3;i++){
   vec4 rect=review_source_rects[i];
   if(gaf_inside_tile(uv,rect)){
    tile_uv=clamp((uv-rect.xy)/(rect.zw-rect.xy),0.,1.);
    matched=true;
    break;
   }
  }
 }
 if(!matched){return vec3(0.);}
 // Follow the existing meadow path in world space across 1 m block seams.
 float center=1.9*sin(world_xz.y*.24)+.55*sin(world_xz.y*.57);
 float clumps=gaf_path_noise(floor(world_xz*4.))-.5;
 float pixels=gaf_path_noise(floor(world_xz*16.))-.5;
 float distance_to_path=abs(world_xz.x-center)+.32*clumps+.15*pixels;
 float grass_weight=smoothstep(.69,1.01,distance_to_path);
 vec4 other_rect=from_grass?review_target_rect:grass_rect;
 return vec3(mix(other_rect.xy,other_rect.zw,tile_uv),from_grass?1.-grass_weight:grass_weight);
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
	vec3 other_layer=vec3(0.);
	if(review_path_blend && gaf_upward>.99){
		other_layer=gaf_meadow_path_layer(UV,(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xz);
	}
	vec3 surface_color=texel.rgb;
	if(other_layer.z>0.){
		surface_color=mix(surface_color,texture(atlas,other_layer.xy).rgb,other_layer.z);
	}
	if(gaf_leaf_material_enabled){surface_color=gaf_leaf_color(texel.rgb,review_leaf_hue,gaf_leaf_weights.r);}
	else if(review_leaf_hue!=0. && texel.g>texel.r*1.1 && texel.g>texel.b*1.1){
	 vec3 axis=vec3(.5773502692);
	 surface_color=surface_color*cos(review_leaf_hue)+cross(axis,surface_color)*sin(review_leaf_hue)+axis*dot(axis,surface_color)*(1.-cos(review_leaf_hue));
	}
	ALBEDO=max(surface_color,vec3(0.0));
	if(gaf_leaf_material_enabled){BACKLIGHT=gaf_leaf_transmission(ALBEDO,gaf_leaf_weights.g,gaf_leaf_scatter_strength);}
	else if(texel.g>texel.r*1.1 && texel.g>texel.b*1.1){BACKLIGHT=ALBEDO*review_backlight_rgb;}ROUGHNESS=1.0;SPECULAR=0.0;
	if(has_mre){
		vec3 packed=texture(mre_map,lookup_uv).rgb;
		if(other_layer.z>0.){packed=mix(packed,texture(mre_map,other_layer.xy).rgb,other_layer.z);}
		METALLIC=packed.r;
		ROUGHNESS=packed.g;
		EMISSION=(other_layer.z>0.?surface_color:texel.rgb)*packed.b*review_emissive_gain;
	}
 SPECULAR=gaf_specular;
 float ground_contact=1.0;
 if(gaf_ground_contact_enabled){
  ground_contact=gaf_ground_contact_factor((INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz);
 }
 vec3 diffuse_fill=review_irradiance_scale*ALBEDO*max(vec3(0.0),gaf_diffuse_fill+gaf_sky_delta)*mix(1.0,gaf_fill_up_ratio,gaf_upward)*(1.0-METALLIC)*ground_contact;
 EMISSION+=diffuse_fill;
 if(gaf_rock_bounce){
  // Lift the vertical faces with existing scene irradiance and contact weighting.
  float vertical_face=clamp(1.0-abs(dot(normalize(NORMAL),VIEW_MATRIX[1].xyz)),0.0,1.0);
  EMISSION+=diffuse_fill*vec3(0.96,1.02,1.08)*vertical_face;
 }
 if(gaf_directional_fill_enabled){
  vec3 normal_y=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.)).xyz);
  EMISSION+=diffuse_fill*(gaf_directional_factor(normal_y)-vec3(1.));
 }
#ifdef GAF_CLOUD_PROJECTOR
	// Ambient is disabled here. Mobile applies this AO to direct diffuse and
	// specular, while the existing indirect term is supplied through EMISSION.
	if(gaf_cloud_strength>0.0){
		AO=gaf_cloud_at((INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz);
		AO_LIGHT_AFFECT=1.0;
	}
#endif
}
