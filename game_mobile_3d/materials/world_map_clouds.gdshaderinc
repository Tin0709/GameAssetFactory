// Lightweight moving shade field; no sky/cloud geometry or volumetric claim.
uniform bool clouds_enabled = false;
uniform float cloud_time = 0.0;
// World metres per field texel, density start/end and maximum shade.
uniform vec4 cloud_shape = vec4(13.0, 0.50, 0.73, 0.20);
uniform sampler2D cloud_field : filter_linear, repeat_enable;
float cloud_noise(vec2 p) {
	return texture(cloud_field,(p+0.5)/64.0).r;
}
float world_cloud_shade(vec3 world) {
	if (!clouds_enabled) return 1.0;
	vec2 p=(world.xz+vec2(cloud_time*0.48,cloud_time*0.19))/cloud_shape.x;
	float density=(cloud_noise(p)+cloud_noise(p*2.07+vec2(17.0,9.0))*0.32)/1.32;
	return 1.0-smoothstep(cloud_shape.y,cloud_shape.z,density)*cloud_shape.w;
}
