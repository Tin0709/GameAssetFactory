shader_type spatial;

uniform bool reveal_player = false;
uniform vec3 player_view;
uniform float native_specular = 0.24;

#ifdef GAF_WORLD_DIRECT_CLOUD
#include "res://materials/world_map_clouds.gdshaderinc"
varying vec2 grove_world_xz;

void vertex() {
	grove_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
#endif
#if defined(GAF_WORLD_DIRECT_CLOUD) || defined(GAF_WORLD_FOLIAGE_LIGHT)
#define GAF_WORLD_BURLEY
#ifdef GAF_WORLD_FOLIAGE_LIGHT
#define GAF_WORLD_OPAQUE_FOLIAGE
#endif
#include "res://materials/world_map_direct_cloud.gdshaderinc"
#endif

void fragment() {
	if (reveal_player) {
		// WorldMap uses an orthographic camera. Keep the opening centred on
		// the player even while the camera holds its elevation during a jump.
		vec3 offset = VERTEX - player_view;
		vec2 extent = abs(offset.xy) / vec2(0.70, 1.16);
		float distance_to_player = length(max(extent - 0.48, vec2(0.0)));
		if (offset.z > 0.01 && distance_to_player < 0.80) {
			float opacity = smoothstep(0.35, 0.80, distance_to_player);
			float threshold = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
			if (opacity <= threshold) discard;
		}
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = native_specular;
#ifdef GAF_WORLD_DIRECT_CLOUD
	cloud_transmission = world_cloud_shade(vec3(grove_world_xz.x, 0.0, grove_world_xz.y));
#elif defined(GAF_WORLD_FOLIAGE_LIGHT)
	cloud_transmission = 1.0;
#endif
}
