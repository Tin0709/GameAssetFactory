shader_type spatial;
render_mode diffuse_burley, depth_draw_always;
#include "res://materials/gameplay_cliff_cutaway.gdshaderinc"

// Only occluding chunks use this material. All other chunks use their imports.
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform bool use_albedo_texture = false;
uniform bool use_vertex_color = false;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float native_roughness = 1.0;
uniform float native_metallic = 0.0;
uniform float native_specular = 0.5;

void vertex() {
	cutaway_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 color = albedo_tint;
	if (use_albedo_texture) color *= texture(atlas, UV);
	if (use_vertex_color) color *= COLOR;
	ALBEDO = color.rgb;
	ALPHA = color.a * cliff_visibility();
	ROUGHNESS = native_roughness;
	METALLIC = native_metallic;
	SPECULAR = native_specular;
}
