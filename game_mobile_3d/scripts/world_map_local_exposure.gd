extends CompositorEffect
## A bounded local contrast adjustment on the resolved scene before Godot's tone curve.

const TILE_SIZE := 16
const HDR_FORMAT := RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
var _source_format:=0
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
layout(push_constant,std430) uniform Settings { vec4 settings; vec4 air; vec4 finish; };
layout(location=0) out float result;
const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
void main() {
	ivec2 size = textureSize(source_color, 0);
	ivec2 start = ivec2(gl_FragCoord.xy) * 16;
	float sum = 0.0;
	for (int y = 2; y < 16; y += 4) {
		for (int x = 2; x < 16; x += 4) {
			vec3 rgb = texelFetch(source_color, min(start + ivec2(x,y), size - 1), 0).rgb;
			sum += log2(max(dot(rgb, luma), 0.002*(air.z>.5?2.0:1.0)));
		}
	}
	result = sum / 16.0;
}
"""
const APPLY := """#version 450
layout(set=0,binding=0) uniform sampler2D source_color;
layout(set=0,binding=1) uniform sampler2D log_meter;
layout(set=0,binding=2) uniform sampler2D soft_light;
layout(push_constant,std430) uniform Settings { vec4 settings; vec4 air; vec4 finish; };
layout(location=0) out vec4 result;
const vec3 luma = vec3(0.2126, 0.7152, 0.0722);
void main() {
	vec4 color = texelFetch(source_color, ivec2(gl_FragCoord.xy), 0);
	if (settings.x <= 0.0 && air.x <= 0.0) {
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
	float log_pixel = log2(max(y, 0.002*(air.z>.5?2.0:1.0)));
	// Let the current pixel moderate a dark or bright neighborhood.
	float log_base = log_pixel + 0.60 * clamp(log_area - log_pixel, -2.0, 2.0);
	float stops = log2(settings.y) - log_base;
	float toe = smoothstep(0.002, 0.012, y/(air.z>.5?2.0:1.0));
	float gain_stops = clamp(stops * settings.x, -settings.z, settings.w);
	gain_stops *= (gain_stops > 0.0) ? toe : 1.0;
	// Preserve RGB ratios when a saturated component is near the packed target limit.
	float peak = max(max(color.r, color.g), color.b);
	float gain = exp2(gain_stops);
	if(air.z<.5) gain=min(gain,1.0/max(peak,0.002));
	vec3 adjusted = color.rgb * gain;
	// Reuse the local meter. Bound bloom's neighborhood gain independently of scene gain.
	float bloom_gain = 1.0;
	float response = air.y >= 2.0 ? air.y - 2.0 : air.y;
	if (air.x > 0.0 && response > 0.0) {
		float target_log = log2(settings.y);
		float local_stops = clamp(target_log - log_base, -2.0, 2.0);
		// Lift the halo where its surroundings are brighter. A uniformly dark
		// region gets no lift, and hot cores retain a gentler shoulder.
		float halo = smoothstep(0.10, 0.85, log_area - log_pixel);
		float highlight = smoothstep(0.5, 2.0, log_pixel - target_log);
		float bloom_stops = 0.32 * max(local_stops, 0.0) * toe * halo
			- 0.30 * max(-local_stops, 0.0) - 0.20 * highlight;
		bloom_stops = clamp(bloom_stops, -0.65, 0.24);
		bloom_gain = exp2(response * bloom_stops);
	}
	if (air.x > 0.0) {
		vec2 uv_air = gl_FragCoord.xy / vec2(textureSize(source_color, 0));
		vec3 spread = textureLod(soft_light, uv_air, 0.0).rgb;
		// Original bounded Mobile light spread, not the native UE bloom kernel.
		adjusted += spread * (air.x * bloom_gain);
	}
	result = vec4(adjusted, color.a);
}
"""

const AIR_PREFILTER := """
vec3 prefilter_air(vec3 scene_color) {
 if (finish.x <= 0.0) return scene_color;
 // Preserve diffuse haze below the knee instead of cutting it to black.
 // Threshold in physical luminance, independently of packed target encoding.
 float value = dot(scene_color, vec3(0.2126, 0.7152, 0.0722)) * (air.z > .5 ? 1. : 2.);
 float highlights = smoothstep(0.025, 0.15, value);
 return scene_color * mix(1.0, highlights, finish.x);
}
"""
const AIR_SOURCE := """#version 450
layout(set=0,binding=0) uniform sampler2D source_color;
layout(set=0,binding=1) uniform sampler2D log_meter;
layout(push_constant,std430) uniform Settings { vec4 settings; vec4 air; vec4 finish; };
layout(location=0) out vec4 result;
""" + AIR_PREFILTER + """
void main(){
 vec2 uv=gl_FragCoord.xy/ceil(vec2(textureSize(source_color,0))/4.0);
 vec2 px=1.0/vec2(textureSize(source_color,0));vec3 sum=vec3(0);
 for(int y=0;y<4;y++)for(int x=0;x<4;x++){
  vec2 at=uv+(vec2(x,y)-1.5)*px;vec3 c=textureLod(source_color,at,0.).rgb;
  float local=textureLod(log_meter,at,0.).r;
  float stops=clamp((log2(settings.y)-local)*settings.x,-settings.z,settings.w);
  sum+=c*exp2(stops);
 }
 result=vec4(prefilter_air(sum/16.),1.);
}
"""
const AIR_BLUR := """#version 450
layout(set=0,binding=0) uniform sampler2D source_color;
layout(push_constant,std430) uniform Settings { vec4 settings; vec4 air; vec4 finish; };
layout(location=0) out vec4 result;
void main(){
 vec2 uv=gl_FragCoord.xy/vec2(textureSize(source_color,0));
 vec2 step_uv=DIRECTION*air.w/vec2(textureSize(source_color,0));
 vec3 c=textureLod(source_color,uv,0.).rgb*.30;
 c+=(textureLod(source_color,uv+step_uv*2.,0.).rgb+textureLod(source_color,uv-step_uv*2.,0.).rgb)*.25;
 c+=(textureLod(source_color,uv+step_uv*6.,0.).rgb+textureLod(source_color,uv-step_uv*6.,0.).rgb)*.10;
 result=vec4(c,1.);
}
"""
# Keep the bloom input on the exact same ORIGINAL bounded exposure treatment
# as scene APPLY. Native source evidence establishes ordering/coherence, not
# equivalence of our bounded formula to Unreal's bilateral local exposure.
var _coherent_bloom_source:=true
var _render_coherent_bloom:=true
func set_coherent_bloom_source(value:bool)->void:
	_guard.lock();_coherent_bloom_source=value;_guard.unlock()
func _coherent_air_source(block:int=4)->String:
	# Reuse the single authoritative gain body; no independently drifting formula.
	var first:=APPLY.find("\tvec2 grid =")
	var last:=APPLY.find("\tvec3 adjusted =")
	if first<0 or last<=first:
		_report("error","Scene exposure gain contract changed");return ""
	var gain:=APPLY.substr(first,last-first).replace("gl_FragCoord.xy","pixel")
	var fn:="const vec3 luma=vec3(.2126,.7152,.0722);\nfloat scene_gain(vec3 rgb,vec2 pixel){vec4 color=vec4(rgb,1.);\n"+gain+"\nreturn gain;}\n"
	var main_start:=AIR_SOURCE.find("void main(){")
	if main_start<0:
		_report("error","Bloom source exposure contract changed");return ""
	var source:=AIR_SOURCE.substr(0,main_start)+fn+"""void main(){
 ivec2 dimensions=textureSize(source_color,0);
 ivec2 first=ivec2(gl_FragCoord.xy)*4;vec3 sum=vec3(0.);
 for(int y=0;y<4;y++)for(int x=0;x<4;x++){
  ivec2 pixel=min(first+ivec2(x,y),dimensions-1);
  vec3 c=texelFetch(source_color,pixel,0).rgb;
  sum+=c*scene_gain(c,vec2(pixel)+.5);
 }
 result=vec4(prefilter_air(sum/16.),1.);
}
"""
	return source.replace("*4;","*"+str(block)+";").replace("y<4;","y<"+str(block)+";").replace("x<4;","x<"+str(block)+";").replace("sum/16.","sum/"+str(block*block)+".")


var _air_bloom:=false
var _air_response:=1.
var _bloom_local_response := 0.
var _bloom_prefilter := 0.
var _air_spread:=1.
func set_air_bloom_spread(value: float) -> void:
	var spread := clampf(value, 0., 2.) if is_finite(value) else 1.
	if spread == _air_spread: return
	_air_spread = spread
	set_neutral(false)

func set_air_bloom_response(value:float)->void:
	var response:=clampf(value,0.,4.)if is_finite(value)else 1.
	if response==_air_response:return
	_air_response=response;set_neutral(false)

func set_bloom_prefilter(value: float) -> void:
	var amount := clampf(value, 0., 1.) if is_finite(value) else 0.
	if amount == _bloom_prefilter:
		return
	_bloom_prefilter = amount
	set_neutral(false)

func set_bloom_local_response(value: float) -> void:
	var response := clampf(value, 0., 1.) if is_finite(value) else 0.
	if response == _bloom_local_response:
		return
	_bloom_local_response = response
	set_neutral(false)

func set_air_bloom(value:bool)->void:
	if _air_bloom==value:return
	_air_bloom=value;set_neutral(false)

var _guard := Mutex.new()
const REVIEW_PARAMETERS := [0.23, 0.10, 0.24, 0.38]
var _parameters := PackedFloat32Array(REVIEW_PARAMETERS + [0.,0.,0.,1.,0.,0.,0.,0.]).to_byte_array()
var _review_strength := float(REVIEW_PARAMETERS[0])
var _state := {"frames": 0, "rebuilds": 0, "error": "", "bytes": 0, "first_build_us": 0, "air_bloom_spread": 1.}
var _color := RID()
var _resources: Array[RID] = []
var _passes: Array[Array] = []
var _scene_framebuffer := RID()
var _scene_uniform := RID()

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true

func set_neutral(neutral: bool) -> void:
	var parameters := PackedFloat32Array(REVIEW_PARAMETERS + [.16*_air_response if _air_bloom and not neutral else 0.,_bloom_local_response if not neutral else 0.,0.,_air_spread,_bloom_prefilter if not neutral else 0.,0.,0.,0.])
	parameters[0] = 0.0 if neutral else _review_strength
	_guard.lock()
	_parameters = parameters.to_byte_array()
	_state["air_bloom_response"]=_air_response;_state["air_bloom_weight"]=parameters[4]
	_state["air_bloom_spread"]=_air_spread
	_state["bloom_local_response"] = parameters[5]
	_state["bloom_prefilter"] = parameters[8]
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

var _air_bytes:=0
var _air_pass_end:=5
func _build_air(rd:RenderingDevice,copy:RID,meter:RID,format:RDTextureFormat,linear:RID)->RID:
	var small: Array[RID]=[]
	for i in 3:
		var t:=_texture(rd,ceili(float(format.width)/4.),ceili(float(format.height)/4.),RenderingDevice.DATA_FORMAT_B10G11R11_UFLOAT_PACK32)
		if not t.is_valid():return RID()
		small.append(t)
	var air_source:=_coherent_air_source() if _render_coherent_bloom else AIR_SOURCE
	if air_source.is_empty():return RID()
	if not _prepare_pass(rd,air_source,_keep(rd.framebuffer_create([small[0]])),[_sample(0,linear,copy),_sample(1,linear,meter)]):return RID()
	for i in 2:
		var code:=AIR_BLUR.replace("DIRECTION","vec2(1.,0.)" if i==0 else "vec2(0.,1.)")
		if not _prepare_pass(rd,code,_keep(rd.framebuffer_create([small[i+1]])),[_sample(0,linear,small[i])]):return RID()
	_air_bytes=ceili(float(format.width)/4.)*ceili(float(format.height)/4.)*12
	return small[2]

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
	var soft:=_build_air(rd,copy,meter,format,linear)
	if not soft.is_valid():return false
	_air_pass_end=_passes.size()
	if not _prepare_pass(rd, APPLY, _scene_framebuffer, [_sample(0, nearest, copy), _sample(1, linear, meter),_sample(2,linear,soft)]): return false
	_report("coherent_bloom",_render_coherent_bloom)
	_report("bytes", format.width * format.height * (8 if format.format==HDR_FORMAT else 4) + width * height * 2 + _air_bytes)
	_guard.lock()
	if _state.rebuilds == 0: _state.first_build_us = Time.get_ticks_usec() - start
	_state.rebuilds += 1
	_guard.unlock()
	return true

func _finish_needs_soft_light() -> bool:
	return false

func _render_callback(kind: int, data: RenderData) -> void:
	if kind != effect_callback_type or not _state.error.is_empty(): return
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	var rd := RenderingServer.get_rendering_device()
	if buffers == null or rd == null: return
	_guard.lock();var coherent:=_coherent_bloom_source;_guard.unlock()
	if coherent!=_render_coherent_bloom:
		_release(rd);_render_coherent_bloom=coherent
		_report("coherent_bloom",coherent)
	var color := buffers.get_color_layer(0)
	if not color.is_valid(): return
	if color != _color:
		_release(rd)
		var format := rd.texture_get_format(color)
		if buffers.get_view_count() != 1 or format.samples != RenderingDevice.TEXTURE_SAMPLES_1 or format.format not in [COLOR_FORMAT,HDR_FORMAT]:
			_report("error", "Local exposure requires a supported resolved scene color")
			return
		_source_format=format.format;_report("color_format",_source_format)
		if not _build(rd, color, format):
			_release(rd)
			if _state.error.is_empty(): _report("error", "Could not prepare local exposure passes")
			return
		_color = color
	_guard.lock()
	var parameters := _parameters.duplicate()
	_guard.unlock()
	var finish_needs_soft_light := _finish_needs_soft_light()
	# air.y stores the response in [0, 1]. Add 2 when diffusion needs the same filtered light even without bloom.
	if finish_needs_soft_light:
		parameters.encode_float(20, parameters.decode_float(20) + 2.0)
	if _source_format==HDR_FORMAT:
		# RGB10 scene color stores half radiance; RGBA16F stores full radiance.
		# Preserve the existing physical middle gray and toe, not a new art gain.
		parameters.encode_float(4,parameters.decode_float(4)*2.)
		parameters.encode_float(24,1.)
	var needs_soft_light := parameters.decode_float(16) > 0.0 or finish_needs_soft_light
	for index in _passes.size():
		if index >= 2 and index < _air_pass_end and not needs_soft_light: continue
		var pass_data := _passes[index]
		var list := rd.draw_list_begin(pass_data[0])
		rd.draw_list_bind_render_pipeline(list, pass_data[1])
		rd.draw_list_bind_uniform_set(list, pass_data[2], 0)
		if index >= 1: rd.draw_list_set_push_constant(list, parameters, parameters.size())
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
