extends "../local_exposure_v001/exposure_pipeline.gd"
## Original cached separable/pyramid graph. Caller owns device and source.
var stages:Array[Dictionary]=[]
func initialize_bloom(rd:RenderingDevice,source:RID,fixtures:Array,folder:String)->bool:
 device=rd;outputs={"source":source};var clamp_sampler:=_sampler(true)
 var state:=RDSamplerState.new();state.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;state.mag_filter=state.min_filter;state.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER;state.repeat_v=state.repeat_u;state.repeat_w=state.repeat_u;state.border_color=RenderingDevice.SAMPLER_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;state.min_lod=0.;state.max_lod=0.
 var border:=_keep(device.sampler_create(state));var cache:Dictionary={}
 for row:Dictionary in fixtures:
  var dst:Dictionary=row
  var target:=_texture(int(dst.width),int(dst.height),RenderingDevice.DATA_FORMAT_B10G11R11_UFLOAT_PACK32,RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
  var fb:=_keep(device.framebuffer_create([target]));var key:String=row.kind if row.kind=="downsample"else"%d_%s"%[int(row.tap_count),"add"if row.inputs.size()>1 else"plain"]
  if not cache.has(key):
   var vs:String="../../local_exposure_v001/shaders/fullscreen.vert.glslinc"if row.kind=="downsample"else"filter_%d.vert.glslinc"%int(row.tap_count)
   var fs:String="../../local_exposure_v001/shaders/downsample.frag.glslinc"if row.kind=="downsample"else("filter_%d_add.frag.glslinc"if row.inputs.size()>1 else"filter_%d.frag.glslinc")%int(row.tap_count)
   var shader:=_shader(folder,{"vertex":vs,"fragment":fs})
   if not error.is_empty():return false
   cache[key]={"shader":shader,"pipeline":_raster(shader,fb)}
  if not error.is_empty():return false
  var params:PackedByteArray=row.parameters
  var uniforms:Array[RDUniform]=[_buffer(1,params)];var sampler:RID=clamp_sampler if row.kind=="downsample"else border
  for i in row.inputs.size():
   var id:String=str(row.inputs[i])
   if not outputs.has(id):error="Missing upstream bloom dependency";return false
   uniforms.append(_sample(0 if i==0 else 2,outputs[id],sampler))
  var set:=_uniform_set(cache[key].shader,uniforms);stages.append({"framebuffer":fb,"pipeline":cache[key].pipeline,"set":set,"resource":str(row.output)})
  outputs[str(row.output)]=target
 return error.is_empty()
func execute_bloom()->bool:
 if not error.is_empty():return false
 for s:Dictionary in stages:
  var dl:=device.draw_list_begin(s.framebuffer);device.draw_list_bind_render_pipeline(dl,s.pipeline);device.draw_list_bind_uniform_set(dl,s.set,0);device.draw_list_draw(dl,false,1,3);device.draw_list_end()
 return true
func release()->void:
 super.release();stages.clear()
