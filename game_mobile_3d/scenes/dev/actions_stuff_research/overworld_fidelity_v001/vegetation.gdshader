shader_type spatial;
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif
#ifdef GAF_GRASS_EDGE_SAMPLING
render_mode cull_disabled, diffuse_burley, specular_disabled, alpha_to_coverage_and_one;
#else
render_mode cull_disabled, diffuse_burley, specular_disabled;
#endif
#include "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/world_map_grass_splay.gdshaderinc"
#include "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/world_map_grass_wind.gdshaderinc"
#ifdef GAF_REFERENCE_GRASS_LIGHTING
#include "res://materials/world_map_replay_bounce.gdshaderinc"
#include "res://materials/world_map_turf_ambient.gdshaderinc"
#include "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/world_map_grass_light.gdshaderinc"
#include "res://materials/world_map_spruce_sky.gdshaderinc"
#include "res://materials/world_map_player_contact.gdshaderinc"
#include "res://materials/world_map_regional_sky.gdshaderinc"
#include "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/grass_normal_v001/world_normal.gdshaderinc"
uniform sampler2D study_ground_sky : filter_nearest, repeat_disable;
uniform vec2 study_ground_sky_origin;
uniform vec3 study_ground_sky_scale = vec3(1.0);
uniform float study_ground_sky_mix = 0.0;
uniform float study_twilight_ground_ambient = 1.0;
uniform vec3 study_grass_shade_color = vec3(0.0);
uniform float study_grass_root_tone = 0.0;
uniform float study_grass_night_albedo = 0.0;
uniform float study_grass_shadow_height = 1.0;
varying flat vec4 study_ground_sky_at_root;
varying flat float study_canopy_sky_at_root;
varying flat float study_raw_canopy_sky;
varying flat vec3 study_day_bounce_at_root;

vec3 grass_day_bounce(vec2 world_position) {
	if (dot(day_bounce_key.rgb, vec3(1.0)) <= 0.0) return vec3(0.0);
	ivec2 extent = ivec2(day_bounce_roots.zw);
	ivec2 cell = ivec2(floor(world_position - day_bounce_roots.xy));
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, extent))) return vec3(0.0);
	return gaf_day_bounce(day_bounce_grass_start + cell.y * extent.x + cell.x);
}

vec4 grass_ground_sky(vec2 world_position) {
	ivec2 cell = ivec2(floor(world_position - study_ground_sky_origin));
	ivec2 extent = textureSize(study_ground_sky, 0);
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, extent))) {
		return vec4(0.0);
	}
	vec4 incident = texelFetch(study_ground_sky, cell, 0);
	if (regional_sky_state.x > 0.0 && incident.a > 0.0 &&
			all(equal(study_ground_sky_origin, regional_sky_roots.xy)) &&
			all(equal(extent, ivec2(regional_sky_roots.zw)))) {
		int receiver = int(regional_sky_state.y) + cell.y * extent.x + cell.x;
		incident.rgb = gaf_regional_sky(incident.rgb, study_ground_sky_scale, world_position, receiver);
	}
	if (night_sky_state.x > 0.0 && incident.a > 0.0 &&
			all(equal(study_ground_sky_origin, night_sky_roots.xy)) &&
			all(equal(extent, ivec2(night_sky_roots.zw)))) {
		int receiver = night_sky_grass_start + cell.y * extent.x + cell.x;
		incident.rgb = gaf_night_sky(incident.rgb, receiver);
	}
	return incident;
}
#endif
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
#ifdef GAF_GRASS_EDGE_SAMPLING
uniform sampler2D edge_atlas : filter_linear, repeat_disable;
#endif
uniform sampler2D mre_map : filter_nearest, repeat_disable;
uniform sampler2D interaction_field : filter_linear, repeat_disable;
uniform sampler2D interaction_previous : filter_linear, repeat_disable;
uniform sampler2D ground_atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 ground_uv=vec4(0.0);
uniform bool has_mre=false;
uniform bool tinted_grass=false;
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
// Optional map-cell constraint; legacy private meadow keeps its original path.
uniform bool cell_limited_motion=false;
uniform bool splayed_rest_motion=false;
uniform bool ground_mask_enabled=false;
uniform sampler2D ground_coverage_map : filter_nearest, repeat_disable;
uniform vec2 ground_coverage_origin=vec2(0.0);
uniform vec2 ground_coverage_extent=vec2(1.0);
varying vec3 foliage_world;
varying float height_fraction;
varying vec3 root_color;
varying vec3 wrapped_normal_world;
void vertex(){
#ifdef GAF_REFERENCE_GRASS_LIGHTING
	// The patch origin stays in its own cell while the blades bend.
	study_ground_sky_at_root = study_ground_sky_mix > 0.0 ? grass_ground_sky(MODEL_MATRIX[3].xz) : vec4(0.0);
	study_raw_canopy_sky = gaf_spruce_sky(MODEL_MATRIX[3].xyz, INV_VIEW_MATRIX[3].xyz);
	study_canopy_sky_at_root = gaf_ground_canopy_sky(study_raw_canopy_sky);
	study_day_bounce_at_root = grass_day_bounce(MODEL_MATRIX[3].xz);
#endif
	// Full float custom attribute: normalized height, blade height, phase, response.
	float u=CUSTOM0.x;
	float h=CUSTOM0.y;
	height_fraction=u;
	vec3 root=(MODEL_MATRIX*vec4(UV2.x,0.0,UV2.y,1.0)).xyz;
	vec2 direction=normalize(wind_direction);
	float spatial=dot(root.xz,direction);
	float phase=CUSTOM0.z+spatial*0.6283185+INSTANCE_CUSTOM.r;
	vec2 bend=vec2(0.0);
	if(!review_source_wind){
		bend=direction*(0.28*sin(wind_time*frequency*6.2831853+phase)+0.055*sin(wind_time*6.2831853*0.625+spatial*0.34));
		bend+=vec2(-direction.y,direction.x)*0.025*sin(wind_time*6.2831853*0.25+phase);
		bend*=wind_intensity*CUSTOM0.w;
	}
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
	if(splayed_rest_motion){
		world_offset=gaf_grass_rest_arc(normalize(MODEL_NORMAL_MATRIX*NORMAL),heading,planar,vertical);
	}
	if(review_source_wind && wind_intensity>0.0){
		world_offset+=gaf_source_grass_wind((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz,root,wind_time);
	}
	if(cell_limited_motion){
		world_offset*=INSTANCE_CUSTOM.a;
		vec3 target=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+world_offset;
		target.xz=clamp(target.xz,INSTANCE_CUSTOM.gb-vec2(0.48),INSTANCE_CUSTOM.gb+vec2(0.48));
		world_offset=target-(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	}
	VERTEX+=(inverse(MODEL_MATRIX)*vec4(world_offset,0.0)).xyz;
#ifdef GAF_REFERENCE_GRASS_LIGHTING
	// Only the orthographic shadow draw uses the corrected blade height.
	if (IN_SHADOW_PASS && PROJECTION_MATRIX[3][3] > .5) {
		VERTEX.y *= study_grass_shadow_height;
	}
#endif
	foliage_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
#ifndef GAF_REFERENCE_GRASS_LIGHTING
	if(tinted_grass)NORMAL=normalize(NORMAL*0.35+vec3(0.0,0.65,0.0));
#endif
	wrapped_normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	root_color=textureLod(ground_atlas,mix(ground_uv.xy,ground_uv.zw,fract(vec2(root.x,-root.z))),0.0).rgb;
}
void fragment(){
	vec4 texel=texture(atlas,UV);
	vec3 color=texel.rgb;
	if(tinted_grass){
		// Preserve the authored upward grass normals on both sides, as in the
		// existing lab. Automatic backface flipping otherwise makes dark stripes.
		vec3 world_normal=wrapped_normal_world;
#ifdef GAF_REFERENCE_GRASS_LIGHTING
		study_face=normalize(mat3(VIEW_MATRIX)*(FRONT_FACING?world_normal:-world_normal));
		world_normal=gaf_foliage_world_normal(world_normal,study_grass_up_weight);
#endif
		NORMAL=normalize(mat3(VIEW_MATRIX)*world_normal);
		color=mix(base_tint,tip_tint,clamp(height_fraction,0.0,1.0))*(vec3(0.65)+0.35*texel.rgb);
		color=mix(root_color,color,smoothstep(0.0,0.18,height_fraction));
#ifdef GAF_REFERENCE_GRASS_LIGHTING
		if (study_grass_root_tone > 0.0 && height_fraction < 0.62) {
			// Calibrated against adjacent terrain and foliage in the Forest
			// G-buffer. Preserve luminance and taper towards the blade tip.
			const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
			vec3 ground_tone = color * vec3(0.91, 1.0, 1.25);
			ground_tone *= dot(color, luma) / max(dot(ground_tone, luma), 0.000001);
			float tone_mix = study_grass_root_tone * (1.0 - smoothstep(0.19, 0.62, height_fraction));
			color = mix(color, ground_tone, tone_mix);
		}
		if (study_grass_night_albedo > 0.0) {
			float tip = smoothstep(0.0, 0.58, height_fraction);
			float above_root = smoothstep(0.03, 0.23, height_fraction);
			color *= mix(1.0, mix(0.75, 0.62, tip), study_grass_night_albedo * above_root);
		}
#endif
	}
#ifdef GAF_REFERENCE_GRASS_LIGHTING
	float dawn_turf = tinted_grass ? gaf_dawn_turf_weight(foliage_world, CAMERA_POSITION_WORLD) : 0.0;
	color = gaf_dawn_turf_chroma(color, vec3(1.21, 1.0, 1.08), 0.68 * dawn_turf);
#endif
	ALBEDO=color;ALPHA=texel.a;ALPHA_SCISSOR_THRESHOLD=cutoff;
#ifdef GAF_GRASS_EDGE_SAMPLING
	// Filter coverage from the same atlas, separately from the nearest color.
	// Retain the original binary shape for the shadow-map pass.
	ALPHA_ANTIALIASING_EDGE=-1.0;
	if(!IN_SHADOW_PASS){
		ALPHA=texture(edge_atlas,UV).a;
		ALPHA_SCISSOR_THRESHOLD=min(cutoff,0.02);
		ALPHA_ANTIALIASING_EDGE=cutoff-ALPHA_SCISSOR_THRESHOLD;
		ALPHA_TEXTURE_COORDINATE=UV*vec2(textureSize(edge_atlas,0));
	}
#endif
	if(ground_mask_enabled){
		vec2 mask_uv=(floor(foliage_world.xz)-ground_coverage_origin+vec2(0.5))/ground_coverage_extent;
		float inside=step(0.0,mask_uv.x)*step(mask_uv.x,1.0)*step(0.0,mask_uv.y)*step(mask_uv.y,1.0);
		float kind=texture(ground_coverage_map,mask_uv).b;
		ALPHA*=inside*(1.0-step(0.25,abs(kind-1.0)));
	}
	ROUGHNESS=1.0;SPECULAR=0.0;
	if(has_mre){vec3 packed=texture(mre_map,UV).rgb;METALLIC=packed.r;ROUGHNESS=packed.g;}
	// Inferred wrapped backlighting; no claim of matching native two-sided shader.
	BACKLIGHT=color*0.18;
#ifdef GAF_REFERENCE_GRASS_LIGHTING
	BACKLIGHT=vec3(0.0);
	float ground_mix = study_ground_sky_at_root.a * study_ground_sky_mix;
	// Crossfade the ambient terms. AO_LIGHT_AFFECT keeps direct light separate.
	AO = (1.0 - ground_mix) * study_canopy_sky_at_root;
	AO_LIGHT_AFFECT = 0.0;
	EMISSION = color * (1.0 - METALLIC) * study_ground_sky_at_root.rgb * study_ground_sky_scale * ground_mix * study_canopy_sky_at_root;
	vec3 ungraded_sky = EMISSION;
	// The canopy field weights the color change without altering sky irradiance.
	float shade_mix = study_grass_shade_color.z * (1.0 - smoothstep(0.73, 0.96, study_canopy_sky_at_root));
	if (shade_mix > 0.0) {
		const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
		vec3 cool_fill = EMISSION * vec3(study_grass_shade_color.x, 1.0, study_grass_shade_color.y);
		cool_fill *= dot(EMISSION, luma) / max(dot(cool_fill, luma), 0.000001);
		EMISSION = mix(EMISSION, cool_fill, shade_mix);
	}
	if (gaf_canopy_sky_color > 0.0) {
		// Fade out the old grass-only treatment as the common sky color takes over.
		vec3 shared_sky = gaf_canopy_diffuse_color(ungraded_sky, study_raw_canopy_sky, 1.0);
		EMISSION = mix(EMISSION, shared_sky, gaf_canopy_sky_color);
	}
	float sole = gaf_player_contact(foliage_world, CAMERA_POSITION_WORLD);
	AO *= sole * study_twilight_ground_ambient;
	EMISSION *= study_twilight_ground_ambient;
	if (tinted_grass && turf_ambient_color != vec3(1.0)) {
		EMISSION = gaf_turf_ambient(EMISSION);
		EMISSION = gaf_dawn_turf_chroma(EMISSION, vec3(1.65, 1.0, .81), .55 * dawn_turf);
	}
	EMISSION = gaf_pre_twilight_diffuse(EMISSION, CAMERA_POSITION_WORLD);
	EMISSION += color * (1.0 - METALLIC) * study_day_bounce_at_root;
	EMISSION *= sole;
	EMISSION += color * (1.0 - METALLIC) * gaf_replay_incident(foliage_world,vec3(0.0,1.0,0.0)) * (0.64 * sole);
	if (gaf_diffuse_opening.w > 0.0) {
		grass_opening_incident = study_ground_sky_at_root.rgb * study_ground_sky_scale * ground_mix * study_canopy_sky_at_root * sole;
	}
	study_tip_weight=smoothstep(0.26,0.85,height_fraction);
	study_cloud=world_cloud_shade(foliage_world);
#endif
#ifdef GAF_SHARED_MIST
	FOG=gaf_surface_mist(SCREEN_UV,-VERTEX.z,INV_VIEW_MATRIX[3].xyz,-INV_VIEW_MATRIX[2].xyz,vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1]));
#endif
}
