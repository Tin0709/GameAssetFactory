extends "../bloom_v001/bloom_exposure_effect.gd"
## Optional original direct logarithmic presentation, fused with final LE writeback.
const PRESENTATION_SHADER="res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/presentation_v001/presentation.frag.glslinc"
var _presentation_data:Dictionary={}
var _presentation_enabled:=false
var _presentation_frames:=0
var _presentation_ready:=false
var _presentation_pipeline:=RID()
var _presentation_set:=RID()
var _presentation_bloom_texture:=RID()
var _presentation_lut:=RID()
var _presentation_black:=RID()
var _presentation_sampler:=RID()
var _presentation_shader:=RID()
var _presentation_buffer:=RID()
var _presentation_exposure_buffer:=RID()
var _presentation_profile_hash:=""
var _presentation_owned:Array[RID]=[]
func configure_presentation_external(path:String)->bool:
 if not _presentation_data.is_empty():return true
 var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not raw is Dictionary or raw.get("schema","")!="original_reference_presentation_v1":return false
 for key:String in["lut","parameters"]:
  if not raw.get(key,null)is Dictionary:return false
  for field:String in["path","sha256"]:
   if not raw[key].get(field,null)is String:return false
 if not _numeric(raw.lut.get("size",null)):return false
 var n:=int(raw.lut["size"])
 if float(n)!=float(raw.lut["size"])or n<2 or n>64:return false
 var lut:=FileAccess.get_file_as_bytes(raw.lut.path);var params:=FileAccess.get_file_as_bytes(raw.parameters.path)
 if lut.size()!=n*n*n*4 or params.size()!=48:return false
 if _digest(lut)!=raw.lut.sha256 or _digest(params)!=raw.parameters.sha256:return false
 for i in 12:
  if not is_finite(params.decode_float(i*4)):return false
 if params.decode_float(0)<=0. or params.decode_float(4)<=0. or params.decode_float(12)<=0. or params.decode_float(44)<=0.:return false
 if params.decode_float(16)<0. or params.decode_float(20)<0. or params.decode_float(20)>1.:return false
 if absf(params.decode_float(40)-sqrt(2.))>1e-6:return false
 if absf(params.decode_float(44)-_parameters.final.decode_float(44)*_parameters.final.decode_float(0))>1e-6:return false
 _presentation_data={"lut":lut,"parameters":params,"size":n};_presentation_profile_hash=FileAccess.get_sha256(path);return true
func presentation_configured()->bool:return not _presentation_data.is_empty()
func set_presentation_enabled(value:bool)->void:
 _mutex.lock();_presentation_enabled=value;_mutex.unlock()
func _publish_snapshot()->void:
 super._publish_snapshot();_mutex.lock();_published.presentation_requested=_presentation_enabled;_published.presentation_ready=_presentation_ready;_published.presentation_frames=_presentation_frames;_published.presentation_profile_sha256=_presentation_profile_hash;_published.presentation_texture_bytes=_presentation_data.get("lut",PackedByteArray()).size();_mutex.unlock()
func _ensure_presentation(rd:RenderingDevice,bloom:RID)->bool:
 if not _presentation_ready:
  if _presentation_data.is_empty():_error="Presentation parameters unavailable";return false
  var usage:=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
  if not rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_A2B10G10R10_UNORM_PACK32,usage):_error="Typed presentation LUT unsupported";return false
  var f:=RDTextureFormat.new();f.texture_type=RenderingDevice.TEXTURE_TYPE_3D;f.width=int(_presentation_data["size"]);f.height=f.width;f.depth=f.width;f.format=RenderingDevice.DATA_FORMAT_A2B10G10R10_UNORM_PACK32;f.usage_bits=usage
  _presentation_lut=rd.texture_create(f,RDTextureView.new(),[_presentation_data.lut]);_presentation_owned.append(_presentation_lut)
  f=RDTextureFormat.new();f.width=1;f.height=1;f.format=RenderingDevice.DATA_FORMAT_B10G11R11_UFLOAT_PACK32;f.usage_bits=usage
  var black:=PackedByteArray();black.resize(4);black.fill(0);_presentation_black=rd.texture_create(f,RDTextureView.new(),[black]);_presentation_owned.append(_presentation_black)
  var state:=RDSamplerState.new();state.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;state.mag_filter=state.min_filter;state.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;state.repeat_v=state.repeat_u;state.repeat_w=state.repeat_u;state.min_lod=0.;state.max_lod=0.
  _presentation_sampler=rd.sampler_create(state);_presentation_owned.append(_presentation_sampler)
  _presentation_shader=_compile_raster(rd,FileAccess.get_file_as_string(PRESENTATION_SHADER))
  if not _error.is_empty():return false
  _presentation_pipeline=_raster_pipeline(rd,_presentation_shader,_scene_fb)
  var params:PackedByteArray=_presentation_data.parameters;_presentation_buffer=rd.storage_buffer_create(params.size(),params);_presentation_owned.append(_presentation_buffer)
  _presentation_exposure_buffer=rd.storage_buffer_create(_parameters.final.size(),_parameters.final);_presentation_owned.append(_presentation_exposure_buffer)
  _presentation_ready=_presentation_pipeline.is_valid()and _presentation_lut.is_valid()and _presentation_black.is_valid()
  if not _presentation_ready:_error="Presentation resources unsupported";return false
 var texture:RID=bloom if bloom.is_valid()else _presentation_black
 if not _presentation_set.is_valid()or texture!=_presentation_bloom_texture:
  if _presentation_set.is_valid()and rd.uniform_set_is_valid(_presentation_set):rd.free_rid(_presentation_set)
  var parameters:=RDUniform.new();parameters.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;parameters.binding=6;parameters.add_id(_presentation_buffer)
  var exposure:=RDUniform.new();exposure.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;exposure.binding=3;exposure.add_id(_presentation_exposure_buffer)
  _presentation_set=rd.uniform_set_create([_sampler_uniform(0,_copy,_presentation_sampler),_sampler_uniform(1,_graph.outputs.grid,_presentation_sampler),_sampler_uniform(2,_graph.outputs.blur,_presentation_sampler),exposure,_sampler_uniform(4,texture,_presentation_sampler),_sampler_uniform(5,_presentation_lut,_presentation_sampler),parameters],_presentation_shader,0)
  _presentation_bloom_texture=texture
 return _presentation_set.is_valid()
func _render_pass(rd:RenderingDevice,framebuffer:RID,pipeline:RID,uniform_set:RID,control:PackedByteArray=PackedByteArray())->void:
 _mutex.lock();var use_presentation:=_presentation_enabled and not _neutral;var use_bloom:=_bloom_enabled;_mutex.unlock()
 if use_presentation and framebuffer==_scene_fb and pipeline==_final_pipeline:
  var bloom:=RID();var scale:=0.
  if use_bloom:
   if not _ensure_bloom(rd):return
   super._render_pass(rd,_setup_fb,_setup_pipeline,_setup_set,PackedFloat32Array([0.,0.,0.,0.]).to_byte_array())
   if not _bloom_graph.execute_bloom():_error=_bloom_graph.error;return
   bloom=_bloom_graph.outputs[_bloom_data.steps[-1].output];scale=float(_bloom_data.to_current);_bloom_frames+=1
  if not _ensure_presentation(rd,bloom):
   if _error.is_empty():_error="Presentation uniform bindings unavailable"
   return
  super._render_pass(rd,_scene_fb,_presentation_pipeline,_presentation_set,PackedFloat32Array([1. if use_bloom else 0.,scale,0.,0.]).to_byte_array());_presentation_frames+=1;return
 super._render_pass(rd,framebuffer,pipeline,uniform_set,control)
func _release_resources()->void:
 var rd:=RenderingServer.get_rendering_device()
 if _presentation_set.is_valid()and rd.uniform_set_is_valid(_presentation_set):rd.free_rid(_presentation_set)
 _presentation_set=RID();_presentation_owned.reverse()
 for rid:RID in _presentation_owned:
  if rid.is_valid():rd.free_rid(rid)
 _presentation_owned.clear();_presentation_ready=false;_presentation_bloom_texture=RID();super._release_resources()
