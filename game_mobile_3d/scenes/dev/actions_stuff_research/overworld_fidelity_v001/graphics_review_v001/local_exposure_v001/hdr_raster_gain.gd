extends CompositorEffect
## Original render-thread copy/transform/writeback; engine texture is never owned.
var _mutex:=Mutex.new()
var _gain:=1.
var _frames:=0
var _error:=""
var _owned:Array[RID]=[]
var _shader:=RID()
var _pipeline:=RID()
var _sampler:=RID()
var _copy:=RID()
var _copy_fb:=RID()
var _scene_fb:=RID()
var _source_set:=RID()
var _copy_set:=RID()
var _color:=RID()
var _size:=Vector2i.ZERO
func _init()->void:
 effect_callback_type=CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT;access_resolved_color=true;enabled=true
func configure(value:float)->void:
 _mutex.lock();_gain=value;_mutex.unlock()
func snapshot()->Dictionary:
 _mutex.lock();var result:={"frames":_frames,"error":_error,"size":[_size.x,_size.y],"gain":_gain,"owned_RIDs":_owned.size()};_mutex.unlock();return result
func _initialize_pipeline(rd:RenderingDevice,color:RID,f:RDTextureFormat)->bool:
 _size=Vector2i(f.width,f.height);_color=color
 var format:=RDTextureFormat.new();format.width=f.width;format.height=f.height;format.format=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT;format.usage_bits=RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
 _copy=rd.texture_create(format,RDTextureView.new(),[]);_copy_fb=rd.framebuffer_create([_copy]);_scene_fb=rd.framebuffer_create([color]);_owned.append_array([_copy,_copy_fb,_scene_fb])
 var source:=RDShaderSource.new();source.source_vertex="#version 450\nvoid main(){vec2 v[3]=vec2[3](vec2(0.,0.),vec2(2.,0.),vec2(0.,2.));gl_Position=vec4(v[gl_VertexIndex]*2.-1.,0.,1.);}\n"
 source.source_fragment="""#version 450
layout(set=0,binding=0)uniform sampler2D source_color;
layout(push_constant,std430)uniform Control{vec4 value;}control;
layout(location=0)out vec4 output_color;
void main(){vec4 c=texelFetch(source_color,ivec2(gl_FragCoord.xy),0);output_color=vec4(c.rgb*control.value.x,c.a);}
"""
 var spirv:=rd.shader_compile_spirv_from_source(source)
 for stage in [RenderingDevice.SHADER_STAGE_VERTEX,RenderingDevice.SHADER_STAGE_FRAGMENT]:
  var error:=spirv.get_stage_compile_error(stage)
  if not error.is_empty():_error=error;return false
 _shader=rd.shader_create_from_spirv(spirv);_owned.append(_shader)
 var raster:=RDPipelineRasterizationState.new();raster.cull_mode=RenderingDevice.POLYGON_CULL_DISABLED;var colors:=RDPipelineColorBlendState.new();colors.attachments=[RDPipelineColorBlendStateAttachment.new()]
 _pipeline=rd.render_pipeline_create(_shader,rd.framebuffer_get_format(_copy_fb),-1,RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,raster,RDPipelineMultisampleState.new(),RDPipelineDepthStencilState.new(),colors);_owned.append(_pipeline)
 if not rd.render_pipeline_is_valid(_pipeline):_error="Invalid HDR writeback pipeline";return false
 var state:=RDSamplerState.new();state.min_filter=RenderingDevice.SAMPLER_FILTER_NEAREST;state.mag_filter=RenderingDevice.SAMPLER_FILTER_NEAREST;_sampler=rd.sampler_create(state);_owned.append(_sampler)
 var a:=RDUniform.new();a.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;a.binding=0;a.add_id(_sampler);a.add_id(color);_source_set=rd.uniform_set_create([a],_shader,0)
 var b:=RDUniform.new();b.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;b.binding=0;b.add_id(_sampler);b.add_id(_copy);_copy_set=rd.uniform_set_create([b],_shader,0);_owned.append_array([_source_set,_copy_set])
 return true
func _draw(rd:RenderingDevice,framebuffer:RID,uniform_set:RID,gain:float)->void:
 var constants:=PackedFloat32Array([gain,0.,0.,0.]).to_byte_array()
 var list:=rd.draw_list_begin(framebuffer);rd.draw_list_bind_render_pipeline(list,_pipeline);rd.draw_list_bind_uniform_set(list,uniform_set,0);rd.draw_list_set_push_constant(list,constants,16);rd.draw_list_draw(list,false,1,3);rd.draw_list_end()
func _render_callback(kind:int,data:RenderData)->void:
 if kind!=CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or not _error.is_empty():return
 var buffers:RenderSceneBuffersRD=data.get_render_scene_buffers();var rd:=RenderingServer.get_rendering_device()
 if buffers==null or rd==null:return
 var color:=buffers.get_color_layer(0)
 if not color.is_valid():return
 var format:=rd.texture_get_format(color)
 if format.format!=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT or buffers.get_view_count()!=1 or format.samples!=RenderingDevice.TEXTURE_SAMPLES_1:_error="Requires single-view, single-sample RGBA16F scene color";return
 if not _shader.is_valid():
  if not _initialize_pipeline(rd,color,format):return
 elif color!=_color or Vector2i(format.width,format.height)!=_size:_error="Scene buffer changed; rebuild effect before reuse";return
 _mutex.lock();var gain:=_gain;_mutex.unlock()
 _draw(rd,_copy_fb,_source_set,1.);_draw(rd,_scene_fb,_copy_set,gain)
 _mutex.lock();_frames+=1;_mutex.unlock()
func release_on_render_thread()->void:
 var rd:=RenderingServer.get_rendering_device();_owned.reverse()
 for rid:RID in _owned:
  # Engine buffer replacement can auto-invalidate these two borrowed bindings.
  if rid==_source_set and not rd.uniform_set_is_valid(rid):continue
  if rid==_scene_fb and not rd.framebuffer_is_valid(rid):continue
  rd.free_rid(rid)
 _owned.clear();_shader=RID();_pipeline=RID()
