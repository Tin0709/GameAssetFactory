// Lightweight moving shade field; no sky/cloud geometry or volumetric claim.
uniform bool clouds_enabled = false;
uniform float cloud_time = 0.0;
uniform sampler2D cloud_field : filter_linear, repeat_enable;
float cloud_noise(vec2 p) {
	return texture(cloud_field,(p+0.5)/64.0).r;
}
float world_cloud_shade(vec3 world) {
	if (!clouds_enabled) return 1.0;
	vec2 p=(world.xz+vec2(cloud_time*0.48,cloud_time*0.19))/13.0;
	float density=(cloud_noise(p)+cloud_noise(p*2.07+vec2(17.0,9.0))*0.32)/1.32;
	return 1.0-smoothstep(0.50,0.73,density)*0.20;
}
