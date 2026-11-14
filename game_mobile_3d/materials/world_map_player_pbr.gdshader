shader_type spatial;
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_player_transport.gdshaderinc"
#include "res://materials/world_map_spruce_sky.gdshaderinc"
#include "res://materials/world_map_local_diffuse.gdshaderinc"
#ifdef GAF_PLAYER_SKY
#include "res://materials/world_map_actor_sky.gdshaderinc"
#endif
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D metal_map : hint_default_white, filter_nearest, repeat_disable;
uniform sampler2D rough_map : hint_default_white, filter_nearest, repeat_disable;
uniform sampler2D glow_map : source_color, hint_default_black, filter_nearest, repeat_disable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec4 glow_tint : source_color = vec4(1.0);
uniform vec4 metal_channel = vec4(0.0,0.0,1.0,0.0);
uniform vec4 rough_channel = vec4(0.0,1.0,0.0,0.0);
uniform float native_metallic = 0.0;
uniform float native_roughness = 1.0;
uniform float native_specular = 0.5;
uniform float cutout = 0.5;
uniform bool glow_enabled = false;
uniform bool glow_add = false;
uniform float glow_energy = 1.0;
uniform bool recovered_roughness = false;
uniform bool recovered_self_light = false;
// Values supplied only by the validated external reference profile.
uniform vec3 roughness_transform = vec3(1.0,0.0,1.0);
uniform float self_light_scale = 0.0;
uniform float actor_view_fill_chroma = 0.0;
varying vec3 actor_world;
varying float actor_canopy_sky;
#ifdef GAF_PLAYER_DIRECT
#include "res://materials/world_map_player_light.gdshaderinc"
#endif
void vertex(){
	actor_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	actor_canopy_sky = gaf_spruce_sky(actor_world, INV_VIEW_MATRIX[3].xyz);
}
void fragment(){
	vec4 base=texture(atlas,UV);
	ALBEDO=albedo_tint.rgb*base.rgb;
	METALLIC=dot(texture(metal_map,UV),metal_channel)*native_metallic;
	float rough=dot(texture(rough_map,UV),rough_channel);
	ROUGHNESS=rough*native_roughness;
	SPECULAR=native_specular;
	player_skin_weight=skin_wrap_enabled?step(.10000000149,texture(skin_profile_mask,UV).r):0.;
	if(recovered_roughness){
		float decoded=rough<=0.04045?rough/12.92:pow((rough+0.055)/1.055,2.4);
		ROUGHNESS=clamp(decoded*roughness_transform.x,roughness_transform.y,roughness_transform.z);
	}
	if(glow_enabled){
		vec3 glow=texture(glow_map,UV).rgb;
		EMISSION=(glow_add?glow_tint.rgb+glow:glow_tint.rgb*glow)*glow_energy;
	}
	if(recovered_self_light){
		float facing=max(dot(normalize(NORMAL),normalize(VIEW))*self_light_scale,0.0);
		vec3 view_fill = ALBEDO*facing*facing*facing;
		if (player_local_light && actor_view_fill_chroma > 0.0 && METALLIC < 1.0) {
			vec3 normal_world = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
			vec3 sky = player_cube_sky(normal_world, actor_world.y - player_probe_base, actor_canopy_sky);
			const vec3 luma = vec3(.2126, .7152, .0722);
			float sky_luma = dot(sky, luma);
			if (sky_luma > .0001) {
				// Adapt the view-facing fill to the local sky without adding a light.
				vec3 tint = clamp(sky / sky_luma, vec3(.60), vec3(1.55));
				tint /= dot(tint, luma);
				float weight = actor_view_fill_chroma * (1.0 - METALLIC) * (.40 + .45 * max(normal_world.y, 0.0));
				view_fill *= mix(vec3(1.0), tint, weight);
			}
		}
		EMISSION += view_fill;
	}
#ifdef GAF_PLAYER_CUTOUT
	ALPHA*=albedo_tint.a*base.a;
	ALPHA_SCISSOR_THRESHOLD=cutout;
#endif
#ifdef GAF_PLAYER_SKY
	AO=actor_sky_visibility(actor_world,normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz));
	AO_LIGHT_AFFECT=0.0;
#endif
	if(player_local_light || player_rough_reflection){
		vec3 wn=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.)).xyz);
		vec3 wv=normalize((INV_VIEW_MATRIX*vec4(VIEW,0.)).xyz);
		float cloud=world_cloud_shade(actor_world);
		float height=actor_world.y-player_probe_base;
		float visible_sky=1.;
#ifdef GAF_PLAYER_SKY
		visible_sky=AO;
#endif
		if(player_local_light){
			vec3 incident = player_cube_light(wn,height,cloud,actor_canopy_sky);
			if ((actor_canopy_color_mix > 0.0 && actor_canopy_sky < 0.96) || gaf_pre_twilight_receiver > 0.0) {
				// Retint only the diffuse sky contribution. The probe's sun bounce and reflection are separate.
				vec3 sky = player_cube_sky(wn, height, actor_canopy_sky);
				vec3 diffuse_sky = gaf_canopy_diffuse_color(sky, actor_canopy_sky, actor_canopy_color_mix);
				incident += gaf_pre_twilight_diffuse(diffuse_sky, CAMERA_POSITION_WORLD) - sky;
			}
			if (recovered_roughness) incident = gaf_local_diffuse(incident, actor_world, wn);
			EMISSION+=ALBEDO*(1.-METALLIC)*incident*visible_sky;
			AO=0.; // Replace engine diffuse sky instead of stacking two ambient terms.
			AO_LIGHT_AFFECT=0.;
		}
		if(player_rough_reflection){
			vec3 reflected=reflect(-wv,wn);
			vec3 radiance=player_cube_light(reflected,height,cloud,actor_canopy_sky);
			vec3 average=(player_axis_light(0,height,cloud,actor_canopy_sky)+player_axis_light(1,height,cloud,actor_canopy_sky)
				+player_axis_light(2,height,cloud,actor_canopy_sky)+player_axis_light(3,height,cloud,actor_canopy_sky)
				+player_axis_light(4,height,cloud,actor_canopy_sky)+player_axis_light(5,height,cloud,actor_canopy_sky))/6.;
			radiance=mix(radiance,average,ROUGHNESS*ROUGHNESS);
			vec3 f0=mix(vec3(.16*native_specular*native_specular),ALBEDO,METALLIC);
			EMISSION+=radiance*f0*visible_sky;
		}
	}
#ifdef GAF_PLAYER_DIRECT
	player_cloud=world_cloud_shade(actor_world);
#endif
#ifdef GAF_SHARED_MIST
	FOG=gaf_surface_mist(SCREEN_UV,-VERTEX.z,INV_VIEW_MATRIX[3].xyz,-INV_VIEW_MATRIX[2].xyz,vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1]));
#endif
}
