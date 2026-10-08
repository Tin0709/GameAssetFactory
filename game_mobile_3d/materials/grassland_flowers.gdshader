shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 wind_direction = vec2(1.0,0.0);
uniform float wind_phase = 0.0;
void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0)).xyz;
	// Smooth local-height mask anchors roots and translates rigid flower heads together.
	float mask = smoothstep(0.0,0.25,max(VERTEX.y,0.0));
	vec2 breeze = normalize(wind_direction) * sin(wind_phase + sin(dot(root.xz,vec2(0.19,0.13))) * 0.16) * 0.012 * mask;
	vec3 local_offset = inverse(mat3(MODEL_MATRIX)) * vec3(breeze.x,0.0,breeze.y);
	VERTEX += local_offset;
}
void fragment() {
	ALBEDO = texture(atlas,UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
