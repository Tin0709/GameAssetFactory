// Lightweight moving shade field; no sky/cloud geometry or volumetric claim.
uniform bool clouds_enabled = false;
uniform float cloud_time = 0.0;
// World metres per field texel, density start/end and maximum shade.
uniform vec4 cloud_shape = vec4(13.0, 0.50, 0.73, 0.20);
uniform sampler2D cloud_field : filter_linear, repeat_enable;
global uniform float gaf_projected_sun_strength;
global uniform vec2 gaf_projected_sun_shift;
global uniform sampler2D gaf_projected_sun_mask : filter_linear_mipmap, repeat_enable;
float cloud_noise(vec2 p) {
	return texture(cloud_field,(p+0.5)/64.0).r;
}
float world_cloud_shade(vec3 world) {
	if (!clouds_enabled) return 1.0;
	vec2 p=(world.xz+vec2(cloud_time*0.48,cloud_time*0.19))/cloud_shape.x;
	float density=(cloud_noise(p)+cloud_noise(p*2.07+vec2(17.0,9.0))*0.32)/1.32;
	float current_shade = 1.0-smoothstep(cloud_shape.y,cloud_shape.z,density)*cloud_shape.w;
	if (gaf_projected_sun_strength <= 0.0) return current_shade;
	// Convert the measured Forest projection to Godot metres. The offset
	// places openings over the WorldMap path and adjacent rock shelves.
	vec2 plane = 0.809017 * world.xz + 0.587785 * world.y * vec2(-1.0, 1.0) + vec2(3.5, -1.2) + gaf_projected_sun_shift;
	float warp = texture(gaf_projected_sun_mask, plane * 0.2 + cloud_time * vec2(0.6, -0.6)).g;
	float mask = texture(gaf_projected_sun_mask, plane / 30.0 + warp * 0.003).r;
	return mix(current_shade, 0.1 + 0.9 * mask, gaf_projected_sun_strength);
}
