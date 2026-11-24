shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

varying vec4 spark_color;
varying float receiver_distance;
uniform float opacity_scale = 1.0;

void vertex() {
	spark_color = INSTANCE_CUSTOM;
	receiver_distance = dot(COLOR.rg * 2.0 - 1.0, VERTEX.xy) + COLOR.b;
}

void fragment() {
	if (receiver_distance < 0.0) {
		discard;
	}
	// Custom data carries the linear Niagara color divided by its maximum.
	// This exposure conversion keeps the orange-to-red gradient on Mobile.
	ALBEDO = spark_color.rgb * 5.0;
	ALPHA = spark_color.a * opacity_scale;
}
