extends "res://scripts/world_map_reference_grade.gd"
## Original bridge between the approved GAF finish and a private reference transfer.
## The Filmic/BCS order follows Godot's public mathematical operations; verified on GPU.
const EDGES=preload("res://scripts/world_map_display_edges.gd")
var _edge_requested:=false
var _render_edge:=false
var _reported_size:=Vector2i.ZERO
func set_display_edges(value:bool)->void:
 _guard.lock();_edge_requested=value;_guard.unlock()
var _finish_wanted:=false
var _render_finish:=false
var _baseline:=PackedByteArray()
var _baseline_slices:Array[Image]=[]
var _baseline_buffer:=RID()
var _baseline_texture:Texture3D
var _palette_generation:=0
var _render_palette_generation:=-1
var _last_baseline:=PackedByteArray()
func configure_finish(value:bool,env:Environment=null,weight:float=0.)->bool:
 if value:
  if env==null or env.tonemap_mode!=Environment.TONE_MAPPER_FILMIC or not env.adjustment_color_correction is Texture3D:return false
  var texture:Texture3D=env.adjustment_color_correction
  if texture.get_width()!=32 or texture.get_height()!=32 or texture.get_depth()!=32:return false
  var slices:Array[Image]=_baseline_slices
  var changed:=texture!=_baseline_texture
  if changed:
   slices=texture.get_data()
   if slices.size()!=32:return false
   for image in slices:
    if image.is_compressed()or image.get_format()not in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8]:return false
    image.convert(Image.FORMAT_RGBA8)
   _baseline_texture=texture
  var data:=PackedFloat32Array([env.tonemap_exposure,env.tonemap_white,env.adjustment_brightness,env.adjustment_contrast,env.adjustment_saturation,1. if env.adjustment_enabled else 0.,clampf(weight,0.,1.),0.]).to_byte_array()
  _guard.lock();_baseline=data;_baseline_slices=slices;_finish_wanted=true
  if changed:_palette_generation+=1
  _guard.unlock()
 else:
  _guard.lock();_finish_wanted=false;_guard.unlock()
 return true
func set_finish_weight(value:float)->void:
 _guard.lock()
 if _baseline.size()==32:_baseline.encode_float(24,clampf(value,0.,1.)if is_finite(value)else 0.)
 _guard.unlock()
func _render_callback(kind:int,data:RenderData)->void:
 if kind!=effect_callback_type:return
 var rd:=RenderingServer.get_rendering_device()
 if rd==null:return
 var buffers:=data.get_render_scene_buffers()as RenderSceneBuffersRD
 if buffers!=null and buffers.get_internal_size()!=_reported_size:
  _reported_size=buffers.get_internal_size();_report("render_size",[_reported_size.x,_reported_size.y])
 _guard.lock();var wanted:=_finish_wanted;var baseline:=_baseline.duplicate();var generation:=_palette_generation;var edge:=_edge_requested and wanted and _reference_enabled and _reference_requested and not _reference_blocked;_guard.unlock()
 if wanted!=_render_finish or edge!=_render_edge or(wanted and generation!=_render_palette_generation):
  _release(rd);_render_finish=wanted;_render_palette_generation=generation;_render_edge=edge
 if _baseline_buffer.is_valid()and baseline!=_last_baseline:
  rd.buffer_update(_baseline_buffer,0,baseline.size(),baseline);_last_baseline=baseline
 super(kind,data)
func _release(rd:RenderingDevice)->void:
 _baseline_buffer=RID();_last_baseline=PackedByteArray();_report("finish_ready",false);_report("finish_bytes",0);_report("edge_active",false);_report("edge_bytes",0);_report("edge_size",[0,0])
 super(rd)
func _finish_fragment(fragment:String,rd:RenderingDevice,uniforms:Array[RDUniform])->String:
 if not _render_finish or not fragment.contains("inverse_display(clamp(display,0.,1.))"):return fragment
 _guard.lock();var slices:=_baseline_slices.duplicate();var baseline:=_baseline.duplicate();_guard.unlock()
 if slices.size()!=32 or baseline.size()!=32:return fragment
 var format:=RDTextureFormat.new();format.texture_type=RenderingDevice.TEXTURE_TYPE_3D;format.width=32;format.height=32;format.depth=32;format.format=RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB;format.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
 if not rd.texture_is_format_supported_for_usage(format.format,format.usage_bits):
  _report("error","Owned finish requires sampled 3D sRGB texture support");return fragment
 var bytes:=PackedByteArray()
 for image in slices:bytes.append_array(image.get_data())
 var palette:=_keep(rd.texture_create(format,RDTextureView.new(),[bytes]));var sampler:=_sampler(rd,RenderingDevice.SAMPLER_FILTER_LINEAR)
 if not palette.is_valid()or not sampler.is_valid():_report("error","Owned finish palette allocation failed");return fragment
 uniforms.append(_sample(5,sampler,palette))
 _baseline_buffer=_keep(rd.storage_buffer_create(32,baseline));_last_baseline=baseline
 if not _baseline_buffer.is_valid():_report("error","Owned finish parameter allocation failed");return fragment
 var uniform:=RDUniform.new();uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;uniform.binding=6;uniform.add_id(_baseline_buffer);uniforms.append(uniform)
 var helpers:="""layout(set=0,binding=5)uniform sampler3D gaf_palette;
layout(set=0,binding=6,std430)readonly buffer Baseline{vec4 base[];};
vec3 gaf_display(vec3 c){return mix(12.92*c,1.055*pow(max(c,vec3(0.)),vec3(1./2.4))-.055,greaterThan(c,vec3(.0031308)));}
vec3 gaf_filmic(vec3 c){return ((c*(.88*c+.06)+.002)/(c*(.88*c+.6)+.06))-(.01/.3);}
vec3 gaf_finish(vec3 c){
 c=vec3(unpackHalf2x16(packHalf2x16(c.rg)),unpackHalf2x16(packHalf2x16(vec2(c.b,0.))).x);
 c=gaf_filmic(max(c*base[0].x,vec3(0.)))/gaf_filmic(vec3(base[0].y));
 if(base[1].y>.5){c=gaf_display(c*base[0].z);c=mix(vec3(.5),c,base[0].w);c=mix(vec3(dot(c,vec3(1./3.))),c,base[1].x);c=textureLod(gaf_palette,clamp(c,0.,1.),0.).rgb;}
 return c;
}
"""
 fragment=fragment.replace("void main() {",helpers+"void main() {")
 fragment=fragment.replace("if (settings.x <= 0.0)","if (settings.x < 0.0)")
 fragment=fragment.replace("result=vec4(inverse_display(clamp(display,0.,1.)),color.a);","result=vec4(mix(gaf_finish(adjusted),inverse_display(clamp(display,0.,1.)),base[1].z),color.a);")
 if _render_edge:
  fragment=fragment.replace("color.a);", "color.a);result.rgb=clamp(gaf_display(result.rgb),0.,1.);")
 _report("finish_ready",true);_report("finish_bytes",131104)
 return fragment

func _prepare_pass(rd:RenderingDevice,fragment:String,framebuffer:RID,uniforms:Array[RDUniform])->bool:
 if fragment!=APPLY or not _render_edge or not _render_finish or not _reference_requested or _reference_blocked:return super._prepare_pass(rd,fragment,framebuffer,uniforms)
 # _color is assigned after _build; borrow source_color texture dimensions instead.
 var source:RID=uniforms[0].get_ids()[1]
 var format:=rd.texture_get_format(source)
 var image:=_texture(rd,format.width,format.height,COLOR_FORMAT)
 if not image.is_valid():_report("error","Display-edge target unsupported");return false
 var target:=_keep(rd.framebuffer_create([image]))
 if not target.is_valid():return false
 if not super._prepare_pass(rd,fragment,target,uniforms):return false
 if not _baseline_buffer.is_valid():_report("error","Display edges require owned final color transfer");return false
 var parameters:=RDUniform.new();parameters.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;parameters.binding=1;parameters.add_id(_baseline_buffer)
 var linear:=_sampler(rd,RenderingDevice.SAMPLER_FILTER_LINEAR)
 if not linear.is_valid()or not super._prepare_pass(rd,EDGES.FRAGMENT,framebuffer,[_sample(0,linear,image),parameters]):return false
 _report("edge_active",true);_report("edge_bytes",format.width*format.height*4);_report("edge_size",[format.width,format.height]);_report("edge_error","")
 return true
