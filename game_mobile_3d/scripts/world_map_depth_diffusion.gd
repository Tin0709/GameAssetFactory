extends RefCounted
## Borrows the existing scene depth and integrated mist in the finish pass.
const SETTINGS_SIZE := 32
const SHADER := """
layout(set=0,binding=7) uniform sampler2DMS gaf_diffusion_depth;
layout(set=0,binding=8) uniform sampler3D gaf_diffusion_mist;
layout(set=0,binding=9,std430) readonly buffer DiffusionDepth { vec4 projection; vec4 layer; } diffusion_depth;

float gaf_diffusion_by_depth(vec2 uv) {
	ivec2 extent = textureSize(gaf_diffusion_depth);
	ivec2 pixel = clamp(ivec2(uv * vec2(extent)), ivec2(0), extent - 1);
	// Reverse Z: favor the near surface at mixed-coverage edges.
	float raw = max(texelFetch(gaf_diffusion_depth, pixel, 0).r,
		texelFetch(gaf_diffusion_depth, pixel, 1).r);
	if (raw <= 0.0) return 1.0;
	float ndc = 1.0 - 2.0 * raw;
	vec4 inverse_z = diffusion_depth.projection;
	float depth_m = -(inverse_z.x * ndc + inverse_z.y) / (inverse_z.z * ndc + inverse_z.w);
	float far_m = diffusion_depth.layer.y;
	float entry_m = diffusion_depth.layer.z;
	float opacity = 0.0;
	if (depth_m > entry_m) {
		float slice = sqrt(clamp(depth_m / far_m, 0.0, 1.0)) * 31.0;
		float previous = floor(sqrt(entry_m / far_m) * 31.0);
		float next_m = far_m * pow((previous + 1.0) / 31.0, 2.0);
		if (entry_m > 0.0 && depth_m < next_m) {
			slice = previous + (depth_m - entry_m) / max(next_m - entry_m, 0.00001);
		}
		opacity = clamp(1.0 - textureLod(gaf_diffusion_mist, vec3(uv, (slice + 0.5) / 32.0), 0.0).a, 0.0, 1.0);
	}
	float distance_weight = smoothstep(0.6, 6.0, depth_m - diffusion_depth.layer.x);
	float haze_weight = smoothstep(0.004, 0.035, opacity);
	float scale = 0.14 + 1.28 * distance_weight * haze_weight;
	return mix(1.0, scale, diffusion_depth.layer.w);
}
"""

var depth := RID()
var volume := RID()
var uniform_set := RID()
var settings_buffer := RID()
var applied := PackedByteArray()

static func supported(viewport: Viewport) -> bool:
	# This path is validated with the D3D12 Mobile attachment. Keep the existing
	# finish on drivers whose MSAA lifetime and bandwidth are still unmeasured.
	return RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_current_rendering_driver_name() == "d3d12" \
		and viewport != null and viewport.msaa_3d == Viewport.MSAA_2X

static func parameters(camera: Camera3D, focus: Vector3, entry: float, weight: float) -> PackedByteArray:
	var inverse := camera.get_camera_projection().inverse()
	var actor_depth := -camera.global_basis.z.dot(focus - camera.global_position)
	return PackedFloat32Array([inverse.z.z, inverse.w.z, inverse.z.w, inverse.w.w,
		actor_depth, camera.far, entry, weight]).to_byte_array()

func refresh_sources(rd: RenderingDevice, buffers: RenderSceneBuffersRD, mist: CompositorEffect) -> bool:
	var new_depth := RID()
	var new_volume := RID()
	if mist != null and buffers != null and buffers.get_view_count() == 1 and buffers.get_msaa_3d() == RenderingServer.VIEWPORT_MSAA_2X:
		var state: Dictionary = mist.snapshot()
		var source := buffers.get_depth_texture(true)
		if state.ready and state.error.is_empty() and source.is_valid():
			var format := rd.texture_get_format(source)
			if format.samples == RenderingDevice.TEXTURE_SAMPLES_2 and (format.usage_bits & RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT) != 0:
				new_volume = mist.texture.texture_rd_rid
				if new_volume.is_valid():
					new_depth = source
	var changed := new_depth != depth or new_volume != volume
	depth = new_depth
	volume = new_volume
	return changed

func write(rd: RenderingDevice, data: PackedByteArray) -> void:
	if settings_buffer.is_valid() and data.size() == SETTINGS_SIZE and data != applied:
		if rd.buffer_update(settings_buffer, 0, SETTINGS_SIZE, data) == OK:
			applied = data

func release(rd: RenderingDevice, resources: Array[RID]) -> void:
	# Reconfiguration can remove the engine-owned attachment and its binding.
	if uniform_set.is_valid() and not rd.uniform_set_is_valid(uniform_set):
		resources.erase(uniform_set)
	uniform_set = RID()
	settings_buffer = RID()
	applied = PackedByteArray()
