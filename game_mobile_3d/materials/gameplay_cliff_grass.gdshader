shader_type spatial;
render_mode diffuse_burley, specular_disabled, fog_disabled, depth_draw_always;
#include "res://materials/gameplay_cliff_cutaway.gdshaderinc"

// Scene-local ground grade. Original mesh, UVs and atlas remain reusable.
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D smooth_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 ground_color : source_color = vec3(0.266667, 0.360784, 0.2);
uniform float texture_contrast : hint_range(0.0, 1.0) = 0.065;
varying float top_face;

void vertex() {
	cutaway_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top_face = step(0.9, NORMAL.y);
}

void fragment() {
	ALPHA = cliff_visibility();
	vec3 source = texture(atlas, UV).rgb;
	if (top_face > 0.5) {
		// Keep the authored 32px grass tile isolated from neighbouring atlas cells.
		// Limit atlas mip depth and inset the lookup footprint to prevent colour bleed.
		vec2 size = vec2(textureSize(smooth_atlas, 0));
		vec2 dx = dFdx(UV * size);
		vec2 dy = dFdy(UV * size);
		float lod = clamp(log2(max(max(length(dx), length(dy)), 1.0)), 0.0, 2.0);
		vec2 inset = vec2(0.5 * exp2(lod));
		vec2 safe_uv = clamp(UV, (vec2(2.0, 94.0) + inset) / size, (vec2(34.0, 126.0) - inset) / size);
		source = textureLod(smooth_atlas, safe_uv, lod).rgb;
	}
	bool grass_cap = source.g > source.r * 1.1 && source.g > source.b * 1.4;
	vec3 grass_mean = vec3(0.08563283, 0.21684506, 0.03415246);
	vec3 quiet_grass = max(ground_color + (source - grass_mean) * texture_contrast, vec3(0.0));
	ALBEDO = (top_face > 0.5 || grass_cap) ? quiet_grass : source;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
