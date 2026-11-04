extends RefCounted
## Original reference-resolution graph, shared local/global RD; caller owns device/input.
var device:RenderingDevice
var error:=""
var outputs:Dictionary={}
var source_hashes:Dictionary={}
var owned:Array[RID]=[]
var _grid:Dictionary={}
var _pyramid:Array[Dictionary]=[]
var _log:Dictionary={}
var _blur:Array[Dictionary]=[]
func _keep(rid:RID)->RID:
 if rid.is_valid():owned.append(rid)
 else:error="Failed to create a RenderingDevice resource"
 return rid
func _texture(width:int,height:int,format:int,usage:int,depth:int=1)->RID:
 if not device.texture_is_format_supported_for_usage(format,usage):error="Unsupported graph texture format/usage";return RID()
 var f:=RDTextureFormat.new();f.width=width;f.height=height;f.depth=depth;f.format=format;f.usage_bits=usage
 if depth>1:f.texture_type=RenderingDevice.TEXTURE_TYPE_3D
 return _keep(device.texture_create(f,RDTextureView.new(),[]))
func _shader(folder:String,names:Dictionary)->RID:
 var source:=RDShaderSource.new()
 for stage:String in names:
  var path:=folder.path_join(names[stage]);var code:=FileAccess.get_file_as_string(path);source_hashes[names[stage]]=FileAccess.get_sha256(path)
  if stage=="compute":source.source_compute=code
  elif stage=="vertex":source.source_vertex=code
  else:source.source_fragment=code
 var spirv:=device.shader_compile_spirv_from_source(source)
 for stage in [RenderingDevice.SHADER_STAGE_COMPUTE]if names.has("compute")else[RenderingDevice.SHADER_STAGE_VERTEX,RenderingDevice.SHADER_STAGE_FRAGMENT]:
  var message:=spirv.get_stage_compile_error(stage)
  if not message.is_empty():error=message;return RID()
 return _keep(device.shader_create_from_spirv(spirv))
func _sampler(linear:bool,mirror:bool=false)->RID:
 var state:=RDSamplerState.new();state.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR if linear else RenderingDevice.SAMPLER_FILTER_NEAREST;state.mag_filter=state.min_filter;state.min_lod=0.;state.max_lod=0.
 state.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_MIRRORED_REPEAT if mirror else RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;state.repeat_v=state.repeat_u;state.repeat_w=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
 return _keep(device.sampler_create(state))
func _sample(binding:int,texture:RID,sampler:RID)->RDUniform:
 var u:=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;u.binding=binding;u.add_id(sampler);u.add_id(texture);return u
func _image(binding:int,texture:RID)->RDUniform:
 var u:=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;u.binding=binding;u.add_id(texture);return u
func _buffer(binding:int,bytes:PackedByteArray)->RDUniform:
 var buffer:=_keep(device.storage_buffer_create(bytes.size(),bytes));var u:=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;u.binding=binding;u.add_id(buffer);return u
func _uniform_set(shader:RID,uniforms:Array[RDUniform])->RID:return _keep(device.uniform_set_create(uniforms,shader,0))
func _raster(shader:RID,framebuffer:RID)->RID:
 var raster:=RDPipelineRasterizationState.new();raster.cull_mode=RenderingDevice.POLYGON_CULL_DISABLED;var colors:=RDPipelineColorBlendState.new();colors.attachments=[RDPipelineColorBlendStateAttachment.new()]
 return _keep(device.render_pipeline_create(shader,device.framebuffer_get_format(framebuffer),-1,RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,raster,RDPipelineMultisampleState.new(),RDPipelineDepthStencilState.new(),colors))
func initialize(rd:RenderingDevice,source_half:RID,parameters:Dictionary,folder:String)->bool:
 device=rd
 var source_format:=device.texture_get_format(source_half)
 if source_format.width!=1024 or source_format.height!=576 or source_format.format!=RenderingDevice.DATA_FORMAT_B10G11R11_UFLOAT_PACK32:error="Reference graph requires caller R11 1024x576 half-resolution input";return false
 var sampled_copy:=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
 var color_usage:=sampled_copy|RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
 var storage_usage:=sampled_copy|RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
 var point:=_sampler(false);var linear:=_sampler(true);var mirror:=_sampler(true,true)
 var grid:=_texture(16,9,RenderingDevice.DATA_FORMAT_R32G32_SFLOAT,storage_usage,32)
 var log_texture:=_texture(64,36,RenderingDevice.DATA_FORMAT_R16_SFLOAT,storage_usage)
 var blur_h:=_texture(64,36,RenderingDevice.DATA_FORMAT_R16_SFLOAT,color_usage);var blur_v:=_texture(64,36,RenderingDevice.DATA_FORMAT_R16_SFLOAT,color_usage)
 if not error.is_empty():return false
 outputs={"grid":grid,"log":log_texture,"blur_h":blur_h,"blur":blur_v}
 var grid_shader:=_shader(folder,{"compute":"grid.comp.glslinc"});var log_shader:=_shader(folder,{"compute":"log.comp.glslinc"})
 var down_shader:=_shader(folder,{"vertex":"fullscreen.vert.glslinc","fragment":"downsample.frag.glslinc"});var blur_shader:=_shader(folder,{"vertex":"blur.vert.glslinc","fragment":"blur.frag.glslinc"})
 if not error.is_empty():return false
 _grid={"pipeline":_keep(device.compute_pipeline_create(grid_shader)),"set":_uniform_set(grid_shader,[_sample(0,source_half,point),_image(1,grid),_buffer(2,parameters.grid)]),"groups":Vector3i(16,9,1)}
 var source:=source_half;var down_pipeline:=RID();var width:=512;var height:=288
 for i in 4:
  var target:=_texture(width,height,RenderingDevice.DATA_FORMAT_B10G11R11_UFLOAT_PACK32,color_usage);var framebuffer:=_keep(device.framebuffer_create([target]))
  if not down_pipeline.is_valid():down_pipeline=_raster(down_shader,framebuffer)
  _pyramid.append({"pipeline":down_pipeline,"framebuffer":framebuffer,"set":_uniform_set(down_shader,[_sample(0,source,linear),_buffer(1,parameters.pyramid[i])])})
  source=target;width/=2;height/=2
 outputs.low_rgb=source
 _log={"pipeline":_keep(device.compute_pipeline_create(log_shader)),"set":_uniform_set(log_shader,[_sample(0,source,point),_image(1,log_texture),_buffer(2,parameters.log)]),"groups":Vector3i(8,5,1)}
 source=log_texture;var blur_pipeline:=RID()
 for i in 2:
  var target:RID=blur_h if i==0 else blur_v;var framebuffer:=_keep(device.framebuffer_create([target]))
  if not blur_pipeline.is_valid():blur_pipeline=_raster(blur_shader,framebuffer)
  _blur.append({"pipeline":blur_pipeline,"framebuffer":framebuffer,"set":_uniform_set(blur_shader,[_sample(0,source,mirror),_buffer(1,parameters.blur[i])])});source=target
 return error.is_empty()
func _dispatch(pass_data:Dictionary)->void:
 var list:=device.compute_list_begin();device.compute_list_bind_compute_pipeline(list,pass_data.pipeline);device.compute_list_bind_uniform_set(list,pass_data.set,0);device.compute_list_dispatch(list,pass_data.groups.x,pass_data.groups.y,pass_data.groups.z);device.compute_list_end()
func _draw(pass_data:Dictionary)->void:
 var list:=device.draw_list_begin(pass_data.framebuffer);device.draw_list_bind_render_pipeline(list,pass_data.pipeline);device.draw_list_bind_uniform_set(list,pass_data.set,0);device.draw_list_draw(list,false,1,3);device.draw_list_end()
func execute()->bool:
 if not error.is_empty():return false
 _dispatch(_grid)
 for pass_data:Dictionary in _pyramid:_draw(pass_data)
 _dispatch(_log)
 for pass_data:Dictionary in _blur:_draw(pass_data)
 return true
func release()->void:
 owned.reverse()
 for rid:RID in owned:device.free_rid(rid)
 owned.clear();outputs.clear();_grid.clear();_pyramid.clear();_log.clear();_blur.clear()
