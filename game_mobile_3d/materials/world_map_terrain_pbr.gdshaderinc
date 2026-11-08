uniform bool terrain_pbr_enabled=false;
uniform bool terrain_has_metal=false;
uniform bool terrain_has_rough=false;
uniform sampler2D terrain_metal_map : hint_default_white, filter_nearest, repeat_disable;
uniform sampler2D terrain_rough_map : hint_default_white, filter_nearest, repeat_disable;
uniform vec4 terrain_metal_channel=vec4(0,0,1,0);
uniform vec4 terrain_rough_channel=vec4(0,1,0,0);
uniform bool terrain_glow_enabled=false;
uniform bool terrain_glow_add=false;
uniform vec4 terrain_glow_tint : source_color=vec4(0.0);
uniform float terrain_glow_energy=1.0;
uniform sampler2D terrain_glow_map : source_color, hint_default_black, filter_nearest, repeat_disable;
vec2 terrain_pbr(vec2 uv){
	return vec2(terrain_pbr_enabled&&terrain_has_metal?dot(texture(terrain_metal_map,uv),terrain_metal_channel):1.,terrain_pbr_enabled&&terrain_has_rough?dot(texture(terrain_rough_map,uv),terrain_rough_channel):1.);
}
vec3 terrain_emission(vec2 uv){
	if(!terrain_pbr_enabled||!terrain_glow_enabled)return vec3(0);
	vec3 value=texture(terrain_glow_map,uv).rgb;
	return (terrain_glow_add?terrain_glow_tint.rgb+value:terrain_glow_tint.rgb*value)*terrain_glow_energy;
}
