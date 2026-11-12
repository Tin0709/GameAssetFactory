extends CompositorEffect
## Brightens near-side depth edges using the existing HDR color attachment.

const VERTEX := """#version 450
void main() {
	vec2 corner = vec2(float((gl_VertexIndex << 1) & 2), float(gl_VertexIndex & 2));
	gl_Position = vec4(corner * 2.0 - 1.0, 0.0, 1.0);
}
"""
const FRAGMENT := """#version 450
#if SAMPLES == 2
layout(set=0, binding=0) uniform sampler2DMS depth_map;
float read_depth(ivec2 p) {
	return max(texelFetch(depth_map, p, 0).r, texelFetch(depth_map, p, 1).r);
}
#else
layout(set=0, binding=0) uniform sampler2D depth_map;
float read_depth(ivec2 p) { return texelFetch(depth_map, p, 0).r; }
#endif
layout(push_constant, std430) uniform Outline {
	vec4 inverse_projection_z;
	vec4 settings;
};
layout(location=0) out vec4 edge_color;

void main() {
	ivec2 p = ivec2(gl_FragCoord.xy);
	ivec2 size = ivec2(settings.zw);
	int radius = int(settings.y);
	if (any(lessThan(p, ivec2(radius))) || any(greaterThanEqual(p, size - radius))) discard;
	float center = read_depth(p);
	if (center <= 0.000001) discard;

	// Symmetric offsets cancel a planar slope. A depth step behind the
	// current surface leaves a positive residual on the nearer side.
	float average = 0.25 * (read_depth(p + ivec2(radius, radius)) +
		read_depth(p - ivec2(radius, radius)) + read_depth(p + ivec2(radius, -radius)) +
		read_depth(p + ivec2(-radius, radius)));
	float residual = center - average;
	if (residual <= 0.000001) discard;

	vec4 q = inverse_projection_z;
	float denominator = q.z * (1.0 - 2.0 * center) + q.w;
	float meters_per_depth = 2.0 * abs(q.x * q.w - q.z * q.y) /
		max(denominator * denominator, 0.000001);
	float meters = residual * meters_per_depth;
	float edge = smoothstep(0.025 * float(radius), 0.24 * float(radius), meters);
	edge_color = vec4(vec3(0.25 * settings.x * edge), 0.0);
}
"""

var _guard := Mutex.new()
var _controls := Vector2(0.0, 2.0)
var _frames := 0
var _failure := ""
var _sampler := RID()
var _shaders: Dictionary = {}
var _pipelines: Dictionary = {}

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	enabled = false

static func supported(viewport: Viewport) -> bool:
	return viewport != null and viewport.msaa_3d in [Viewport.MSAA_DISABLED, Viewport.MSAA_2X] \
		and RenderingServer.get_current_rendering_method() == "mobile" \
		and RenderingServer.get_rendering_device() != null

func configure(strength: float, thickness: int) -> void:
	var controls := Vector2(clampf(strength, 0.0, 4.0), clampi(thickness, 1, 4))
	_guard.lock()
	_controls = controls
	_guard.unlock()
	if enabled != (controls.x > 0.0):
		enabled = controls.x > 0.0

func snapshot() -> Dictionary:
	_guard.lock()
	var state := {"frames": _frames, "error": _failure}
	_guard.unlock()
	return state

func _fail(message: String) -> void:
	_guard.lock()
	_failure = message
	_guard.unlock()

func _render_callback(kind: int, data: RenderData) -> void:
	if kind != effect_callback_type:
		return
	_guard.lock()
	var controls := _controls
	var failed := not _failure.is_empty()
	_guard.unlock()
	if controls.x <= 0.0 or failed:
		return
	var rd := RenderingServer.get_rendering_device()
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene := data.get_render_scene_data()
	if rd == null or buffers == null or buffers.get_view_count() != 1 or scene == null:
		return
	var msaa := buffers.get_msaa_3d() == RenderingServer.VIEWPORT_MSAA_2X
	if not msaa and buffers.get_msaa_3d() != RenderingServer.VIEWPORT_MSAA_DISABLED:
		return
	var depth := buffers.get_depth_layer(0, msaa)
	var color := buffers.get_color_layer(0)
	if not depth.is_valid() or not color.is_valid():
		return
	var depth_format := rd.texture_get_format(depth)
	var color_format := rd.texture_get_format(color)
	var samples := 2 if msaa else 1
	var sample_format := RenderingDevice.TEXTURE_SAMPLES_2 if msaa else RenderingDevice.TEXTURE_SAMPLES_1
	if depth_format.samples != sample_format or color_format.samples != RenderingDevice.TEXTURE_SAMPLES_1 \
			or depth_format.width != color_format.width or depth_format.height != color_format.height \
			or (depth_format.usage_bits & RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT) == 0:
		return

	var framebuffer := FramebufferCacheRD.get_cache_multipass([color], [], 1)
	if not framebuffer.is_valid():
		return
	var pipeline := _get_pipeline(rd, samples, rd.framebuffer_get_format(framebuffer))
	if not pipeline.is_valid():
		return
	var source_depth := RDUniform.new()
	source_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	source_depth.add_id(_sampler)
	source_depth.add_id(depth)
	var uniforms := UniformSetCacheRD.get_cache(_shaders[samples], 0, [source_depth])
	if not uniforms.is_valid():
		return

	var inv := scene.get_cam_projection().inverse()
	var constants := PackedFloat32Array([inv.z.z, inv.w.z, inv.z.w, inv.w.w,
		controls.x, controls.y, color_format.width, color_format.height]).to_byte_array()
	var draw := rd.draw_list_begin(framebuffer)
	rd.draw_list_bind_render_pipeline(draw, pipeline)
	rd.draw_list_bind_uniform_set(draw, uniforms, 0)
	rd.draw_list_set_push_constant(draw, constants, constants.size())
	rd.draw_list_draw(draw, false, 1, 3)
	rd.draw_list_end()
	_guard.lock()
	_frames += 1
	_guard.unlock()

func _get_pipeline(rd: RenderingDevice, samples: int, framebuffer_format: int) -> RID:
	var key := Vector2i(samples, framebuffer_format)
	if _pipelines.has(key):
		return _pipelines[key]
	if not _shaders.has(samples):
		var source := RDShaderSource.new()
		source.source_vertex = VERTEX
		source.source_fragment = FRAGMENT.replace("#if SAMPLES == 2", "#if %d == 2" % samples)
		var spirv := rd.shader_compile_spirv_from_source(source)
		for stage in [RenderingDevice.SHADER_STAGE_VERTEX, RenderingDevice.SHADER_STAGE_FRAGMENT]:
			var error := spirv.get_stage_compile_error(stage)
			if not error.is_empty():
				_fail(error)
				return RID()
		var shader := rd.shader_create_from_spirv(spirv)
		if not shader.is_valid():
			_fail("World Outline shader could not be created")
			return RID()
		_shaders[samples] = shader
	if not _sampler.is_valid():
		_sampler = rd.sampler_create(RDSamplerState.new())
	var raster := RDPipelineRasterizationState.new()
	raster.cull_mode = RenderingDevice.POLYGON_CULL_DISABLED
	var blend := RDPipelineColorBlendStateAttachment.new()
	blend.enable_blend = true
	blend.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_DST_COLOR
	blend.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend.write_a = false
	var colors := RDPipelineColorBlendState.new()
	colors.attachments = [blend]
	var pipeline := rd.render_pipeline_create(_shaders[samples], framebuffer_format, -1,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, raster, RDPipelineMultisampleState.new(),
		RDPipelineDepthStencilState.new(), colors)
	if not rd.render_pipeline_is_valid(pipeline):
		_fail("World Outline blend pipeline could not be created")
		return RID()
	_pipelines[key] = pipeline
	return pipeline

func release_on_render_thread() -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		return
	for rid: RID in _pipelines.values():
		rd.free_rid(rid)
	for rid: RID in _shaders.values():
		rd.free_rid(rid)
	if _sampler.is_valid():
		rd.free_rid(_sampler)
	_pipelines.clear()
	_shaders.clear()
	_sampler = RID()
