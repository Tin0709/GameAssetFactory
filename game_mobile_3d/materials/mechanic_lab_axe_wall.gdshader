shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://materials/mechanic_lab_box_occlusion.gdshaderinc"

uniform sampler2D blade_texture : source_color, filter_nearest;
uniform sampler2D metallic_map : filter_nearest;
uniform sampler2D roughness_map : filter_nearest;
uniform sampler2D emission_map : source_color, filter_nearest;
uniform bool use_packed_surface = false;
uniform bool double_sided = false;
uniform int blade_blocker_count = 0;
uniform vec4 blocker_axes[12];
uniform vec2 actor_xz;
varying vec3 blade_world;

void vertex() {
	blade_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (!double_sided && !FRONT_FACING) {
		discard;
	}
	for (int i = 0; i < blade_blocker_count; i++) {
		vec4 x = blocker_axes[3 * i];
		vec4 z = blocker_axes[3 * i + 1];
		vec4 y = blocker_axes[3 * i + 2];
		float height = blade_world.y * y.x + y.z;
		if (abs(height) <= y.w) {
			vec2 centre = vec2(dot(actor_xz, x.xy) + x.z, dot(actor_xz, z.xy) + z.z);
			vec2 offset = blade_world.xz - actor_xz;
			vec2 path = vec2(dot(offset, x.xy), dot(offset, z.xy));
			if (lab_box_occludes(centre, path, vec2(x.w, z.w))) {
				discard;
			}
		}
	}
	ALBEDO = texture(blade_texture, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
	if (use_packed_surface) {
		METALLIC = texture(metallic_map, UV).b;
		ROUGHNESS = texture(roughness_map, UV).g;
		EMISSION = texture(emission_map, UV).rgb;
	}
}
