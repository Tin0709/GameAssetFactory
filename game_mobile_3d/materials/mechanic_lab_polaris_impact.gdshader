shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

varying vec4 spark_color;

void vertex() {
	spark_color = INSTANCE_CUSTOM;
}

void fragment() {
	// Custom data carries the linear Niagara color divided by its maximum.
	// This exposure conversion keeps the orange-to-red gradient on Mobile.
	ALBEDO = spark_color.rgb * 5.0;
	ALPHA = spark_color.a;
}
