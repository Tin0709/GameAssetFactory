extends CompositorEffect
## A bounded local contrast adjustment on the resolved scene before Godot's tone curve.

const TILE_SIZE := 16
const COLOR_FORMAT := RenderingDevice.DATA_FORMAT_A2B10G10R10_UNORM_PACK32
const USAGE := RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
const VERTEX := """#version 450
void main() {
	vec2 point = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
	gl_Position = vec4(point * 2.0 - 1.0, 0.0, 1.0);
}
"""
const COPY := """#version 450
layout(set=0,binding=0) uniform sampler2D source_color;
layout(location=0) out vec4 result;
void main() {
	result = texelFetch(source_color, ivec2(gl_FragCoord.xy), 0);
}
"""
const METER := """#version 450
layout(set=0,binding=0) uniform sampler2D source_color;
layout(location=0) out float result;
const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
void main() {
	ivec2 size = textureSize(source_color, 0);
	ivec2 start = ivec2(gl_FragCoord.xy) * 16;
	float sum = 0.0;
	for (int y = 2; y < 16; y += 4) {
		for (int x = 2; x < 16; x += 4) {
			vec3 rgb = texelFetch(source_color, min(start + ivec2(x,y), size - 1), 0).rgb;
			sum += log2(max(dot(rgb, luma), 0.002));
		}
	}
	result = sum / 16.0;
}
"""
const APPLY := """#version 450
layout(set=0,binding=0) uniform sampler2D source_color;
layout(set=0,binding=1) uniform sampler2D log_meter;
layout(push_constant,std430) uniform Settings { vec4 settings; };
layout(location=0) out vec4 result;
const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
void main() {
	vec4 color = texelFetch(source_color, ivec2(gl_FragCoord.xy), 0);
	if (settings.x <= 0.0) {
		result = color;
		return;
	}
	vec2 grid = vec2(textureSize(log_meter, 0));
	vec2 uv = gl_FragCoord.xy / (16.0 * grid);
	vec2 step_uv = 1.5 / grid;
	float log_area = textureLod(log_meter, uv, 0.0).r * 0.40;
	log_area += 0.15 * (
		textureLod(log_meter, uv + vec2(step_uv.x, 0.0), 0.0).r +
		textureLod(log_meter, uv - vec2(step_uv.x, 0.0), 0.0).r +
		textureLod(log_meter, uv + vec2(0.0, step_uv.y), 0.0).r +
		textureLod(log_meter, uv - vec2(0.0, step_uv.y), 0.0).r
	);
	float y = dot(color.rgb, luma);
	float log_pixel = log2(max(y, 0.002));
	// Let the current pixel moderate a dark or bright neighborhood.
	float log_base = log_pixel + 0.60 * clamp(log_area - log_pixel, -2.0, 2.0);
	float stops = log2(settings.y) - log_base;
	float toe = smoothstep(0.002, 0.012, y);
	float gain_stops = clamp(stops * settings.x, -settings.z, settings.w);
	gain_stops *= (gain_stops > 0.0) ? toe : 1.0;
	// Preserve RGB ratios when a saturated component is near the packed target limit.
	float peak = max(max(color.r, color.g), color.b);
	float gain = min(exp2(gain_stops), 1.0 / max(peak, 0.002));
	result = vec4(color.rgb * gain, color.a);
}
"""

var _guard := Mutex.new()
const REVIEW_PARAMETERS := [0.23, 0.10, 0.24, 0.38]
var _parameters := PackedFloat32Array(REVIEW_PARAMETERS).to_byte_array()
var _review_strength := float(REVIEW_PARAMETERS[0])
var _state := {"frames": 0, "rebuilds": 0, "error": "", "bytes": 0, "first_build_us": 0}
var _color := RID()
var _resources: Array[RID] = []
var _passes: Array[Array] = []
var _scene_framebuffer := RID()
var _scene_uniform := RID()

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true

func set_neutral(neutral: bool) -> void:
	var parameters := PackedFloat32Array(REVIEW_PARAMETERS)
	parameters[0] = 0.0 if neutral else _review_strength
	_guard.lock()
	_parameters = parameters.to_byte_array()
	_guard.unlock()

func set_review_strength(value: float) -> void:
	# Scene-local art setting; preserve the established finite gain clamps.
	_review_strength = clampf(value, 0.0, REVIEW_PARAMETERS[0]) if is_finite(value) else REVIEW_PARAMETERS[0]
	set_neutral(false)

func snapshot() -> Dictionary:
	_guard.lock()
	var copy := _state.duplicate()
	_guard.unlock()
	return copy

func failure() -> String:
	_guard.lock()
	var message: String = _state.error
	_guard.unlock()
	return message

func _report(key: String, value: Variant) -> void:
	_guard.lock()
	_state[key] = value
	_guard.unlock()

func _keep(rid: RID) -> RID:
	if rid.is_valid(): _resources.append(rid)
	return rid

func _texture(rd: RenderingDevice, width: int, height: int, format: int) -> RID:
	var shape := RDTextureFormat.new()
	shape.width = width
	shape.height = height
	shape.format = format
	shape.usage_bits = USAGE
	if not rd.texture_is_format_supported_for_usage(format, USAGE): return RID()
	return _keep(rd.texture_create(shape, RDTextureView.new()))

func _sampler(rd: RenderingDevice, filter_mode: RenderingDevice.SamplerFilter) -> RID:
	var state := RDSamplerState.new()
	state.min_filter = filter_mode
	state.mag_filter = filter_mode
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.max_lod = 0.0
	return _keep(rd.sampler_create(state))

func _sample(binding: int, sampler: RID, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler)
	uniform.add_id(texture)
	return uniform

func _prepare_pass(rd: RenderingDevice, fragment: String, framebuffer: RID, uniforms: Array[RDUniform]) -> bool:
	var source := RDShaderSource.new()
	source.source_vertex = VERTEX
	source.source_fragment = fragment
	var spirv := rd.shader_compile_spirv_from_source(source)
	if spirv == null: return false
	for stage in [RenderingDevice.SHADER_STAGE_VERTEX, RenderingDevice.SHADER_STAGE_FRAGMENT]:
		var error := spirv.get_stage_compile_error(stage)
		if not error.is_empty():
			_report("error", error)
			return false
	var shader := _keep(rd.shader_create_from_spirv(spirv))
	if not shader.is_valid(): return false
	var raster := RDPipelineRasterizationState.new()
	raster.cull_mode = RenderingDevice.POLYGON_CULL_DISABLED
	var colors := RDPipelineColorBlendState.new()
	colors.attachments = [RDPipelineColorBlendStateAttachment.new()]
	var pipeline := _keep(rd.render_pipeline_create(shader, rd.framebuffer_get_format(framebuffer), -1,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, raster, RDPipelineMultisampleState.new(),
		RDPipelineDepthStencilState.new(), colors))
	if not rd.render_pipeline_is_valid(pipeline): return false
	var binding := _keep(rd.uniform_set_create(uniforms, shader, 0))
	if not binding.is_valid(): return false
	if _passes.is_empty(): _scene_uniform = binding
	_passes.append([framebuffer, pipeline, binding])
	return true

func _build(rd: RenderingDevice, color: RID, format: RDTextureFormat) -> bool:
	var start := Time.get_ticks_usec()
	var width := ceili(float(format.width) / TILE_SIZE)
	var height := ceili(float(format.height) / TILE_SIZE)
	var copy := _texture(rd, format.width, format.height, format.format)
	var meter := _texture(rd, width, height, RenderingDevice.DATA_FORMAT_R16_SFLOAT)
	if not copy.is_valid() or not meter.is_valid(): return false
	var copy_fb := _keep(rd.framebuffer_create([copy]))
	var meter_fb := _keep(rd.framebuffer_create([meter]))
	_scene_framebuffer = _keep(rd.framebuffer_create([color]))
	if not copy_fb.is_valid() or not meter_fb.is_valid() or not _scene_framebuffer.is_valid(): return false
	var nearest := _sampler(rd, RenderingDevice.SAMPLER_FILTER_NEAREST)
	var linear := _sampler(rd, RenderingDevice.SAMPLER_FILTER_LINEAR)
	if not nearest.is_valid() or not linear.is_valid(): return false
	if not _prepare_pass(rd, COPY, copy_fb, [_sample(0, nearest, color)]): return false
	if not _prepare_pass(rd, METER, meter_fb, [_sample(0, nearest, copy)]): return false
	if not _prepare_pass(rd, APPLY, _scene_framebuffer, [_sample(0, nearest, copy), _sample(1, linear, meter)]): return false
	_report("bytes", format.width * format.height * 4 + width * height * 2)
	_guard.lock()
	if _state.rebuilds == 0: _state.first_build_us = Time.get_ticks_usec() - start
	_state.rebuilds += 1
	_guard.unlock()
	return true

func _render_callback(kind: int, data: RenderData) -> void:
	if kind != effect_callback_type or not _state.error.is_empty(): return
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	var rd := RenderingServer.get_rendering_device()
	if buffers == null or rd == null: return
	var color := buffers.get_color_layer(0)
	if not color.is_valid(): return
	if color != _color:
		_release(rd)
		var format := rd.texture_get_format(color)
		if buffers.get_view_count() != 1 or format.samples != RenderingDevice.TEXTURE_SAMPLES_1 or format.format != COLOR_FORMAT:
			_report("error", "Local exposure requires a supported resolved scene color")
			return
		if not _build(rd, color, format):
			_release(rd)
			if _state.error.is_empty(): _report("error", "Could not prepare local exposure passes")
			return
		_color = color
	_guard.lock()
	var parameters := _parameters
	_guard.unlock()
	for index in _passes.size():
		var pass_data := _passes[index]
		var list := rd.draw_list_begin(pass_data[0])
		rd.draw_list_bind_render_pipeline(list, pass_data[1])
		rd.draw_list_bind_uniform_set(list, pass_data[2], 0)
		if index == 2: rd.draw_list_set_push_constant(list, parameters, 16)
		rd.draw_list_draw(list, false, 1, 3)
		rd.draw_list_end()
	_guard.lock()
	_state.frames += 1
	_guard.unlock()

func release_on_render_thread() -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd != null: _release(rd)

func _release(rd: RenderingDevice) -> void:
	_resources.reverse()
	for rid in _resources:
		# Engine-owned color can disappear during resize, taking borrowed bindings with it.
		if rid == _scene_uniform and not rd.uniform_set_is_valid(rid): continue
		if rid == _scene_framebuffer and not rd.framebuffer_is_valid(rid): continue
		rd.free_rid(rid)
	_resources.clear()
	_passes.clear()
	_report("bytes", 0)
	_color = RID()
	_scene_uniform = RID()
	_scene_framebuffer = RID()
