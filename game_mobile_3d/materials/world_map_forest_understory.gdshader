shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

#include "res://materials/world_map_wind.gdshaderinc"
#include "res://materials/world_map_spruce_sky.gdshaderinc"
#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_local_diffuse.gdshaderinc"
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

uniform sampler2D source_atlas : source_color, filter_nearest_mipmap, repeat_disable;
varying float sky_opening;
varying vec3 world_position;
varying float hanging;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	hanging = INSTANCE_CUSTOM.g;
	float sway = INSTANCE_CUSTOM.r * smoothstep(0.04, 0.5, VERTEX.y)
		+ hanging * smoothstep(0.07, 0.85, -VERTEX.y) * 0.7;
	if (sway > 0.0) {
		vec2 drift = clamp(world_breeze(root) * sway * 0.025, vec2(-0.06), vec2(0.06));
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(drift.x, 0.0, drift.y);
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	sky_opening = gaf_spruce_sky(world_position, INV_VIEW_MATRIX[3].xyz);
}

#include "res://materials/world_map_direct_cloud.gdshaderinc"

void fragment() {
	vec4 source = texture(source_atlas, UV);
	if (source.a < 0.5) {
		discard;
	}
	ALBEDO = source.rgb;
	vec3 world_up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	vec3 face = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = normalize(mix(face, world_up_view, mix(0.38, 0.17, hanging)));
	float open_sky = gaf_ground_canopy_sky(sky_opening);
	AO = 0.96 * mix(0.58, 1.0, open_sky);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	cloud_transmission = world_cloud_shade(world_position);
	vec3 world_normal = mat3(INV_VIEW_MATRIX) * NORMAL;
	EMISSION += gaf_local_environment_delta(ALBEDO, 0.0, world_position, world_normal) * AO;
#ifdef GAF_SHARED_MIST
	FOG = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
#endif
}
