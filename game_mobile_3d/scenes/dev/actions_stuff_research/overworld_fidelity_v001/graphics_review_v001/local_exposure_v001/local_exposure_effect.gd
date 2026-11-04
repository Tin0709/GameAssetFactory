extends "hdr_raster_gain.gd"
## Original opt-in live effect, same conformed graph as frozen-input validation.
const Pipeline=preload("exposure_pipeline.gd")
const KERNEL_FOLDER="res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/local_exposure_v001/shaders"
var _graph=Pipeline.new()
var _parameters:Dictionary={}
var _kernel_folder:=""
var _metadata_sha:=""
var _ready_live:=false
var _neutral:=false
var _half:=RID()
var _half_fb:=RID()
var _first_pipeline:=RID()
var _first_set:=RID()
var _final_pipeline:=RID()
var _final_set:=RID()
var _rebuilds:=0
var _published:Dictionary={"frames":0,"error":"","size":[0,0],"gain":1.,"neutral":false,"owned_RIDs":0,"graph_owned_RIDs":0,"graph_error":"","graph_source_hashes":{},"parameters_sha256":"","buffer_rebuilds":0}
func _digest(bytes:PackedByteArray)->String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func configure_external(path:String)->bool:
 var ok:=_load_external(path);_publish_snapshot();return ok
func _load_external(path:String)->bool:
 var meta:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not meta is Dictionary or meta.get("schema","")!="original_live_exposure_parameters_v1":_error="Invalid external live parameters";return false
 if not meta.get("paths",null)is Dictionary:_error="Missing external parameter paths";return false
 _kernel_folder=KERNEL_FOLDER;_metadata_sha=FileAccess.get_sha256(path)
 var manifest_path:=_kernel_folder.path_join("manifest.json")
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 for file:String in manifest.files:
  if FileAccess.get_sha256(_kernel_folder.path_join(file))!=manifest.files[file]:_error="Changed original shader source";return false
 for key:String in ["grid","log","final"]:
  if not meta.paths.get(key,null)is Dictionary:_error="Missing scalar parameter "+key;return false
  var row:Dictionary=meta.paths[key];var bytes:=FileAccess.get_file_as_bytes(row.path)
  if _digest(bytes)!=row.sha256:_error="Changed scalar parameters";return false
  if bytes.size()!={"grid":48,"log":32,"final":64}[key]:_error="Wrong scalar parameter size";return false
  _parameters[key]=bytes
 for key:String in ["pyramid","blur"]:
  if not meta.paths.get(key,null)is Array or meta.paths[key].size()!=(4 if key=="pyramid"else 2):_error="Wrong reference pass count";return false
  _parameters[key]=[]
  for row:Dictionary in meta.paths[key]:
   var bytes:=FileAccess.get_file_as_bytes(row.path)
   if _digest(bytes)!=row.sha256:_error="Changed pass parameters";return false
   if bytes.size()!=(32 if key=="pyramid"else 288):_error="Wrong pass parameter size";return false
   _parameters[key].append(bytes)
 return true
func set_neutral(value:bool)->void:
 _mutex.lock();_neutral=value;_mutex.unlock()
func snapshot()->Dictionary:
 _mutex.lock();var result:Dictionary=_published.duplicate(true);_mutex.unlock();return result
func _publish_snapshot()->void:
 _mutex.lock()
 var result:={"frames":_frames,"error":_error,"size":[_size.x,_size.y],"gain":_gain,"neutral":_neutral,"owned_RIDs":_owned.size(),"graph_owned_RIDs":_graph.owned.size(),"graph_error":_graph.error,"graph_source_hashes":_graph.source_hashes.duplicate(),"parameters_sha256":_metadata_sha,"buffer_rebuilds":_rebuilds}
 _published=result;_mutex.unlock()
func _compile_raster(rd:RenderingDevice,fragment:String)->RID:
 var source:=RDShaderSource.new();source.source_vertex=FileAccess.get_file_as_string(_kernel_folder.path_join("fullscreen.vert.glslinc"));source.source_fragment=fragment
 var spirv:=rd.shader_compile_spirv_from_source(source)
 for stage in [RenderingDevice.SHADER_STAGE_VERTEX,RenderingDevice.SHADER_STAGE_FRAGMENT]:
  var message:=spirv.get_stage_compile_error(stage)
  if not message.is_empty():_error=message;return RID()
 var shader:=rd.shader_create_from_spirv(spirv);_owned.append(shader)
 return shader
func _raster_pipeline(rd:RenderingDevice,shader:RID,framebuffer:RID)->RID:
 var raster:=RDPipelineRasterizationState.new();raster.cull_mode=RenderingDevice.POLYGON_CULL_DISABLED;var colors:=RDPipelineColorBlendState.new();colors.attachments=[RDPipelineColorBlendStateAttachment.new()]
 var pipeline:=rd.render_pipeline_create(shader,rd.framebuffer_get_format(framebuffer),-1,RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,raster,RDPipelineMultisampleState.new(),RDPipelineDepthStencilState.new(),colors);_owned.append(pipeline);return pipeline
func _sampler_uniform(binding:int,texture:RID,sampler:RID)->RDUniform:
 var u:=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;u.binding=binding;u.add_id(sampler);u.add_id(texture);return u
func _storage_uniform(rd:RenderingDevice,binding:int,bytes:PackedByteArray)->RDUniform:
 var buffer:=rd.storage_buffer_create(bytes.size(),bytes);_owned.append(buffer);var u:=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;u.binding=binding;u.add_id(buffer);return u
func _initialize_live(rd:RenderingDevice)->bool:
 var f:=RDTextureFormat.new();f.width=1024;f.height=576;f.format=RenderingDevice.DATA_FORMAT_B10G11R11_UFLOAT_PACK32;f.usage_bits=RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
 if not rd.texture_is_format_supported_for_usage(f.format,f.usage_bits):_error="R11 reference work target unsupported";return false
 _half=rd.texture_create(f,RDTextureView.new(),[]);_half_fb=rd.framebuffer_create([_half]);_owned.append_array([_half,_half_fb])
 if not _graph.initialize(rd,_half,_parameters,_kernel_folder):_error=_graph.error;return false
 var state:=RDSamplerState.new();state.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;state.mag_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;state.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;state.repeat_v=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;state.repeat_w=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;state.min_lod=0.;state.max_lod=0.;var sampler:=rd.sampler_create(state);_owned.append(sampler)
 var first_fragment:="""#version 450
layout(set=0,binding=0)uniform sampler2D source_color;
layout(std430,set=0,binding=1)readonly buffer Parameters{vec4 p[];};
layout(location=0)out vec4 output_color;
void main(){vec2 uv=clamp(gl_FragCoord.xy*p[0].xy,p[0].zw,p[1].xy);output_color=textureLod(source_color,uv,0.);}
"""
 var first_shader:=_compile_raster(rd,first_fragment)
 if not first_shader.is_valid():return false
 _first_pipeline=_raster_pipeline(rd,first_shader,_half_fb)
 var first_params:=PackedFloat32Array([1./1024.,1./576.,.5/_size.x,.5/_size.y,1.-.5/_size.x,1.-.5/_size.y,0.,0.]).to_byte_array()
 _first_set=rd.uniform_set_create([_sampler_uniform(0,_copy,sampler),_storage_uniform(rd,1,first_params)],first_shader,0);_owned.append(_first_set)
 var fragment:="""#version 450
layout(set=0,binding=0)uniform sampler2D source_color;
layout(set=0,binding=1)uniform sampler3D exposure_grid;
layout(set=0,binding=2)uniform sampler2D blurred_log;
layout(std430,set=0,binding=3)readonly buffer Parameters{vec4 p[];};
layout(push_constant,std430)uniform Control{vec4 value;}control;
layout(location=0)out vec4 output_color;
void main(){
 ivec2 pixel=ivec2(gl_FragCoord.xy);vec2 uv=gl_FragCoord.xy/vec2(textureSize(source_color,0));
 vec4 color=texelFetch(source_color,pixel,0);
 float luminance=max(dot(color.rgb*p[2].w,p[3].xyz),p[2].z);
 float physical_log=log2(luminance);
 float depth=(physical_log*p[1].z+p[1].w)*p[2].x+p[2].y;
 vec2 grid=textureLod(exposure_grid,vec3(uv,depth),0.).rg;float blur=textureLod(blurred_log,uv,0.).r;
 float local=grid.y<p[1].y?blur:grid.x/grid.y;
 float base=local+(blur-local)*p[1].x+log2(p[0].x);float delta=base-log2(p[0].y);
 float contrast=delta>0.?p[0].z:p[0].w;if(control.value.x==0.)contrast=1.;
 float gain=exp2((contrast-1.)*delta);output_color=vec4(color.rgb*gain,color.a);
}
"""
 var final_shader:=_compile_raster(rd,fragment)
 if not final_shader.is_valid():return false
 _final_pipeline=_raster_pipeline(rd,final_shader,_scene_fb)
 _final_set=rd.uniform_set_create([_sampler_uniform(0,_copy,sampler),_sampler_uniform(1,_graph.outputs.grid,sampler),_sampler_uniform(2,_graph.outputs.blur,sampler),_storage_uniform(rd,3,_parameters.final)],final_shader,0);_owned.append(_final_set)
 return _error.is_empty()
func _render_pass(rd:RenderingDevice,framebuffer:RID,pipeline:RID,uniform_set:RID,control:PackedByteArray=PackedByteArray())->void:
 var list:=rd.draw_list_begin(framebuffer);rd.draw_list_bind_render_pipeline(list,pipeline);rd.draw_list_bind_uniform_set(list,uniform_set,0)
 if not control.is_empty():rd.draw_list_set_push_constant(list,control,control.size())
 rd.draw_list_draw(list,false,1,3);rd.draw_list_end()
func _render_callback(kind:int,data:RenderData)->void:
 _render_frame(kind,data);_publish_snapshot()
func _render_frame(kind:int,data:RenderData)->void:
 if kind!=CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or not _error.is_empty():return
 var buffers:RenderSceneBuffersRD=data.get_render_scene_buffers();var rd:=RenderingServer.get_rendering_device()
 if buffers==null or rd==null:return
 var color:=buffers.get_color_layer(0)
 if not color.is_valid():return
 var format:=rd.texture_get_format(color)
 if format.format!=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT or buffers.get_view_count()!=1 or format.samples!=RenderingDevice.TEXTURE_SAMPLES_1:_error="Live LE requires single-view/single-sample physical HDR2D";return
 if _ready_live and (color!=_color or Vector2i(format.width,format.height)!=_size):
  _release_resources();_graph=Pipeline.new();_ready_live=false;_rebuilds+=1
 if not _ready_live:
  if _parameters.is_empty():_error="Configure external parameters first";return
  if not _initialize_pipeline(rd,color,format)or not _initialize_live(rd):return
  _ready_live=true
 _draw(rd,_copy_fb,_source_set,1.);_render_pass(rd,_half_fb,_first_pipeline,_first_set)
 if not _graph.execute():_error=_graph.error;return
 _mutex.lock();var neutral:=_neutral;_mutex.unlock()
 _render_pass(rd,_scene_fb,_final_pipeline,_final_set,PackedFloat32Array([0. if neutral else 1.,0.,0.,0.]).to_byte_array())
 _mutex.lock();_frames+=1;_mutex.unlock()
func release_on_render_thread()->void:
 _release_resources();_publish_snapshot()
func _release_resources()->void:
 # Final set borrows graph textures; graph sets borrow our half-resolution input.
 # Release these dependency layers before their textures, avoiding auto-free twice.
 var rd:=RenderingServer.get_rendering_device()
 if _final_set.is_valid():
  _owned.erase(_final_set)
  rd.free_rid(_final_set);_final_set=RID()
 _graph.release();super.release_on_render_thread()
