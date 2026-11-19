extends "res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/local_exposure_v001/local_exposure_effect.gd"
## Latches the strength actually submitted alongside the borrowed raw/statistics.
const Neighborhood := preload("res://scripts/world_map_exposure_neighborhood.gd")
const NEIGHBORHOOD_OFFSET := 64
const LanternExposure := preload("res://scripts/world_map_lantern_exposure.gd")
var _lantern_settings := PackedByteArray()
var _lantern_uploaded := PackedByteArray()
var _lantern_submitted_amount := 0.
var _lantern_error := ""
var _lantern_depth := RID()
var _lantern_shader := RID()
var _lantern_pipeline := RID()
var _lantern_buffer := RID()
var _lantern_sampler := RID()
var _lantern_set := RID()
var _lantern_samples := 0

var _source_frame:=-1
var _source_strength:=0.
var _source_shadow_lift:=1.
var _source_green_shadow_trim := 0.
var _guide_scale := 1.
var _blur_scale := 1.
var _submitted_guide_scale := 1.
var _guide_buffer := RID()
var _original_guide_weight := 0.
var _neighborhood := Vector4.ZERO
var _submitted_neighborhood := Vector4.ZERO

func set_neighborhood_limit(protection: Vector4) -> void:
 var wanted := Vector4.ZERO
 if protection.is_finite() and protection.z > 0. and protection.w > 0.:
  wanted = Vector4(protection.x, protection.y, minf(protection.z, .32), protection.w)
 _mutex.lock()
 _neighborhood = wanted
 _mutex.unlock()

func _neighborhood_shader() -> String:
 return Neighborhood.SHADER

func _neighborhood_gain() -> String:
 return "gain_ev=gaf_limit_neighborhood_gain(gain_ev,luminance,blur-local,uv,vec2(textureSize(source_color,0)),p[4]);"

func set_guide_scale(value: float) -> void:
 _mutex.lock()
 _guide_scale = clampf(value, 0., 1.) if is_finite(value) else 1.
 _mutex.unlock()

func set_blur_scale(value: float) -> void:
 _mutex.lock()
 _blur_scale = clampf(value, .5, 1.) if is_finite(value) else 1.
 _mutex.unlock()

func _statistics_blur_scale() -> float:
 _mutex.lock()
 var scale := _blur_scale
 _mutex.unlock()
 return scale

func rendered_source()->Dictionary:
 return {"frame":_source_frame,"strength":_source_strength,"shadow_lift":_source_shadow_lift,
  "green_shadow_trim":_source_green_shadow_trim,"guide_scale":_submitted_guide_scale,"blur_scale":_graph.blur_scale,
  "neighborhood": _submitted_neighborhood}

func _storage_uniform(rd: RenderingDevice, binding: int, bytes: PackedByteArray) -> RDUniform:
 if binding != 3 or bytes.size() != NEIGHBORHOOD_OFFSET or bytes != _parameters.get("final"):
  return super(rd, binding, bytes)
 var payload := bytes.duplicate()
 payload.resize(NEIGHBORHOOD_OFFSET + 16)
 var uniform := super(rd, binding, payload)
 _guide_buffer = uniform.get_ids()[0]
 _original_guide_weight = bytes.decode_float(16)
 _submitted_guide_scale = 1.
 _submitted_neighborhood = Vector4.ZERO
 return uniform

func _render_pass(rd:RenderingDevice,framebuffer:RID,pipeline:RID,uniform_set:RID,control:PackedByteArray=PackedByteArray())->void:
 if (pipeline == _final_pipeline or pipeline == _lantern_pipeline) and control.size() == 16:
  _mutex.lock()
  var scale := _guide_scale
  var neighborhood := _neighborhood
  _mutex.unlock()
  if scale != _submitted_guide_scale and _guide_buffer.is_valid():
   var data := PackedFloat32Array([_original_guide_weight * scale]).to_byte_array()
   if rd.buffer_update(_guide_buffer, 16, data.size(), data) == OK:
    _submitted_guide_scale = scale
  if neighborhood != _submitted_neighborhood and _guide_buffer.is_valid():
   var data := PackedFloat32Array([neighborhood.x, neighborhood.y, neighborhood.z, neighborhood.w]).to_byte_array()
   if rd.buffer_update(_guide_buffer, NEIGHBORHOOD_OFFSET, data.size(), data) == OK:
    _submitted_neighborhood = neighborhood
  _source_strength=control.decode_float(4)if control.decode_float(0)>0. else 0.
  _source_shadow_lift=control.decode_float(8)
  _source_green_shadow_trim = control.decode_float(12)
  _source_frame=_frames+1
 super(rd,framebuffer,pipeline,uniform_set,control)
# The published camera data crosses to the render thread with the same lock as exposure strength.
func set_lantern_exposure(camera: Camera3D, feet: Vector3, lamp: OmniLight3D, amount: float) -> void:
 var data := LanternExposure.parameters(camera, feet, lamp, amount)
 _mutex.lock()
 _lantern_settings = data
 _mutex.unlock()

func lantern_exposure_status() -> Dictionary:
 _mutex.lock()
 var result := {"active": _lantern_submitted_amount > 0., "amount": _lantern_submitted_amount, "error": _lantern_error}
 _mutex.unlock()
 return result

func _render_final(rd: RenderingDevice, buffers: RenderSceneBuffersRD, control: PackedByteArray) -> void:
 _mutex.lock()
 var data := _lantern_settings.duplicate()
 _mutex.unlock()
 var amount := 0.
 if not data.is_empty() and control.decode_float(0) > 0. and control.decode_float(4) > 0. \
   and _prepare_lantern(rd, buffers, data):
  _render_pass(rd, _scene_fb, _lantern_pipeline, _lantern_set, control)
  amount = data.decode_float(12)
 else:
  super(rd, buffers, control)
 _mutex.lock()
 _lantern_submitted_amount = amount
 _mutex.unlock()

func _prepare_lantern(rd: RenderingDevice, buffers: RenderSceneBuffersRD, data: PackedByteArray) -> bool:
 if not _lantern_error.is_empty() or buffers.get_msaa_3d() not in [
   RenderingServer.VIEWPORT_MSAA_2X, RenderingServer.VIEWPORT_MSAA_4X]:
  return false
 var depth := buffers.get_depth_texture(true)
 if not depth.is_valid():
  return false
 if depth != _lantern_depth or not _lantern_set.is_valid() or not rd.uniform_set_is_valid(_lantern_set):
  if not _bind_lantern_depth(rd, depth, data):
   return false
 data.encode_float(LanternExposure.SAMPLE_COUNT_OFFSET, float(_lantern_samples))
 if data != _lantern_uploaded:
  if rd.buffer_update(_lantern_buffer, 0, data.size(), data) != OK:
   return false
  _lantern_uploaded = data
 return true

func _bind_lantern_depth(rd: RenderingDevice, depth: RID, data: PackedByteArray) -> bool:
 var format := rd.texture_get_format(depth)
 if (format.usage_bits & RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT) == 0 or Vector2i(format.width, format.height) != _size:
  return false
 if format.samples not in [RenderingDevice.TEXTURE_SAMPLES_2, RenderingDevice.TEXTURE_SAMPLES_4]:
  return false
 if not _lantern_pipeline.is_valid() and not _build_lantern_pipeline(rd, data):
  return false
 _release_lantern_binding(rd)
 var params := RDUniform.new()
 params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
 params.binding = 3
 params.add_id(_guide_buffer)
 var lantern := RDUniform.new()
 lantern.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
 lantern.binding = 5
 lantern.add_id(_lantern_buffer)
 _lantern_set = rd.uniform_set_create([
  _sampler_uniform(0, _copy, _final_sampler),
  _sampler_uniform(1, _graph.outputs.grid, _final_sampler),
  _sampler_uniform(2, _graph.outputs.blur, _final_sampler),
  params, _sampler_uniform(4, depth, _lantern_sampler), lantern,
 ], _lantern_shader, 0)
 if not _lantern_set.is_valid():
  _set_lantern_error("Could not bind the renderer's MSAA depth attachment")
  return false
 _lantern_depth = depth
 _lantern_samples = 4 if format.samples == RenderingDevice.TEXTURE_SAMPLES_4 else 2
 return true

func _build_lantern_pipeline(rd: RenderingDevice, data: PackedByteArray) -> bool:
 var previous_error := _error
 _lantern_shader = _compile_raster(rd, _final_fragment(LanternExposure.SHADER,
  "gain_ev=gaf_lantern_exposure(gain_ev,color.rgb,luminance,uv,pixel);"))
 var compile_error := _error
 _error = previous_error
 if not _lantern_shader.is_valid():
  _set_lantern_error(compile_error if not compile_error.is_empty() else "Could not compile lantern exposure")
  return false
 _lantern_pipeline = _raster_pipeline(rd, _lantern_shader, _scene_fb)
 if not rd.render_pipeline_is_valid(_lantern_pipeline):
  _set_lantern_error("Could not create the lantern exposure pipeline")
  return false
 var sampler := RDSamplerState.new()
 sampler.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
 sampler.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
 _lantern_sampler = rd.sampler_create(sampler)
 _owned.append(_lantern_sampler)
 _lantern_buffer = _storage_uniform(rd, 5, data).get_ids()[0]
 return true

func _set_lantern_error(message: String) -> void:
 _mutex.lock()
 _lantern_error = message
 _mutex.unlock()

func _release_lantern_binding(rd: RenderingDevice) -> void:
 if _lantern_set.is_valid() and rd.uniform_set_is_valid(_lantern_set):
  rd.free_rid(_lantern_set)
 _lantern_set = RID()

func _release_resources()->void:
 var rd:=RenderingServer.get_rendering_device()
 if rd != null:
  _release_lantern_binding(rd)
 _lantern_depth = RID()
 _lantern_shader = RID()
 _lantern_pipeline = RID()
 _lantern_buffer = RID()
 _lantern_sampler = RID()
 _lantern_samples = 0
 _lantern_uploaded.clear()
 _mutex.lock()
 _lantern_submitted_amount = 0.
 _lantern_error = ""
 _mutex.unlock()

 _source_frame=-1;_source_strength=0.;_source_shadow_lift=1.
 _source_green_shadow_trim = 0.
 _guide_buffer = RID()
 _submitted_guide_scale = 1.
 _submitted_neighborhood = Vector4.ZERO
 super()
