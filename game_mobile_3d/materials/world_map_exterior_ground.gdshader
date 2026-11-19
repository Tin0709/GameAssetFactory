shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_direct_cloud.gdshaderinc"
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

uniform sampler2DArray source_terrain_tiles : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 foothill_world;
varying vec3 foothill_normal;

void vertex() {
	foothill_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	foothill_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec2 stone_uv = abs(foothill_normal.y) > .9 ? vec2(foothill_world.x, -foothill_world.z) :
		vec2(abs(foothill_normal.x) > .9 ? -foothill_world.z * sign(foothill_normal.x) :
			foothill_world.x * sign(foothill_normal.z), foothill_world.y);
	ALBEDO = texture(source_terrain_tiles, vec3(stone_uv, 4.0)).rgb;
	cloud_transmission = world_cloud_shade(foothill_world);
	// The ledges sit below the authored irradiance cache. Use the live biome sky here.
	AO = mix(0.66, 0.90, max(0.0, foothill_normal.y));
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#ifdef GAF_SHARED_MIST
	FOG = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
#endif
}
