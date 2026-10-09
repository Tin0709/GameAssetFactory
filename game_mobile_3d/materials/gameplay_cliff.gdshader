shader_type spatial;
render_mode diffuse_burley, specular_disabled, depth_draw_always;
#include "res://materials/gameplay_cliff_cutaway.gdshaderinc"
uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec4 albedo_tint : source_color = vec4(1.0);

void vertex() {
	cutaway_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALPHA = cliff_visibility();
	ALBEDO = texture(atlas, UV).rgb * albedo_tint.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
