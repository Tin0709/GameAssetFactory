shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://materials/world_map_clouds.gdshaderinc"
#include "res://materials/world_map_direct_cloud.gdshaderinc"
#ifdef GAF_SHARED_MIST
#include "res://materials/world_map_mist.gdshaderinc"
#endif

#ifdef GAF_VISTA_SPRUCE
uniform sampler2D tree_atlas : source_color, filter_linear_mipmap, repeat_disable;
#else
uniform sampler2DArray source_terrain_tiles : source_color, filter_linear_mipmap, repeat_enable;
#endif
uniform vec3 distant_air_color;
varying vec3 world_point;
varying vec3 world_normal;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
#ifdef GAF_VISTA_SPRUCE
	vec4 source = texture(tree_atlas, UV);
	if (source.a < .44) {
		discard;
	}
	ALBEDO = source.rgb * vec3(.78,.84,.88);
#else
	vec2 uv = abs(world_normal.y) > .9 ? vec2(world_point.x, -world_point.z) :
		vec2(abs(world_normal.x) > .9 ? -world_point.z * sign(world_normal.x) :
			world_point.x * sign(world_normal.z), world_point.y);
	vec3 stone = texture(source_terrain_tiles, vec3(uv, 4.0)).rgb;
	float variation = sin(world_point.z*.17 + cos(world_point.x*.118))*.55 +
		cos(world_point.x*.21 + sin(world_point.z*.081))*.45;
	float greenery = smoothstep(-.10,.56,variation) * step(.98,world_normal.y) * .72;
	vec3 grass = texture(source_terrain_tiles, vec3(uv, 0.0)).rgb * vec3(.71,.77,.74);
	ALBEDO = mix(stone, grass, greenery);
#endif
	cloud_transmission = world_cloud_shade(world_point);
	AO = mix(.66, .90, max(0.0, world_normal.y));
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec4 near_air = vec4(0.0);
#ifdef GAF_SHARED_MIST
	near_air = gaf_surface_mist(SCREEN_UV, -VERTEX.z, INV_VIEW_MATRIX[3].xyz, -INV_VIEW_MATRIX[2].xyz,
		vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]));
#endif
	// A distant layer adds optical depth after the existing near-air contribution.
	float far_opacity = (1.0 - near_air.a) * (1.0 - exp(-max(0.0, -VERTEX.z - 29.0) * .056));
	float opacity = near_air.a + far_opacity;
	FOG = vec4((near_air.rgb * near_air.a + distant_air_color * far_opacity) / max(0.00001, opacity), opacity);
}
