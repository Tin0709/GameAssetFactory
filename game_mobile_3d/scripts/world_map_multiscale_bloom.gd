extends "res://scripts/world_map_phase_finish_effect.gd"
## Original separable pyramid, with private measured kernel coefficients.
const Shape=preload("res://scripts/world_map_bloom_shapes.gd")
const DOWN="""#version 450
layout(set=0,binding=0)uniform sampler2D source_color;
layout(push_constant,std430)uniform Settings{vec4 settings;vec4 air;vec4 finish;};
layout(location=0)out vec4 result;
void main(){ivec2 size=textureSize(source_color,0);ivec2 first=ivec2(gl_FragCoord.xy)*2;vec3 sum=vec3(0.);
for(int y=0;y<2;y++)for(int x=0;x<2;x++)sum+=texelFetch(source_color,min(first+ivec2(x,y),size-1),0).rgb;
result=vec4(max(sum*.25,vec3(0.)),1.);}
"""
const FILTER="""#version 450
layout(set=0,binding=0)uniform sampler2D source_color;
layout(set=0,binding=1)uniform sampler2D coarse_color;
layout(set=0,binding=2,std430)readonly buffer Kernel{vec4 k[];};
layout(push_constant,std430)uniform Settings{vec4 settings;vec4 air;vec4 finish;};
layout(location=0)out vec4 result;
vec3 border_sample(sampler2D image,vec2 at){
 vec2 size=vec2(textureSize(image,0));
 vec2 coverage=clamp(at*size+.5,0.,1.)*clamp((1.-at)*size+.5,0.,1.);
 return textureLod(image,at,0.).rgb*coverage.x*coverage.y;
}
void main(){vec2 uv=gl_FragCoord.xy/vec2(textureSize(source_color,0));vec3 c=vec3(0.);
for(int i=0;i<32;i++){if(i>=int(k[0].x))break;c+=border_sample(source_color,uv+k[i+1].xy)*k[i+1].z;}
if(k[0].y>.5)c+=border_sample(coarse_color,uv);result=vec4(max(c,vec3(0.)),1.);}
"""
var _shape_profile=Shape.new()
var _shape_requested:=false
var _shape_weight:=0.
var _render_shape:=false
var _shape_blocked:=false
var _shape_ready:=false
var _shape_buffer:=RID()
var _old_soft:=RID()
var _work_bytes:=0
var _coefficient_bytes:=0
var _last_shape_weight:=-1.
func multiscale_available()->bool:return _shape_profile.available()
func set_bloom_shape(value:bool,weight:float)->void:
 _guard.lock()
 if value and not _shape_requested:_shape_blocked=false
 _shape_requested=value and multiscale_available()
 _shape_weight=clampf(weight,0.,1.)if is_finite(weight)else 0.
 _guard.unlock()
func _render_callback(kind:int,data:RenderData)->void:
 if kind!=effect_callback_type:return
 var rd:=RenderingServer.get_rendering_device()
 if rd==null:return
 _guard.lock();var weight:=_shape_weight;var wanted:=_shape_requested and weight>0. and not _shape_blocked and _reference_requested and _reference_enabled and not _reference_blocked;_guard.unlock()
 if wanted!=_render_shape:_release(rd);_render_shape=wanted
 if _shape_buffer.is_valid()and weight!=_last_shape_weight:
  rd.buffer_update(_shape_buffer,0,4,PackedFloat32Array([weight]).to_byte_array());_last_shape_weight=weight
 _report("shape_weight",weight if wanted else 0.)
 super(kind,data)
func _release(rd:RenderingDevice)->void:
 _shape_ready=false;_shape_buffer=RID();_old_soft=RID();_last_shape_weight=-1.
 _report("shape_active",false);_report("shape_bytes",0);_report("shape_levels",0)
 super(rd)
func _field(rd:RenderingDevice,width:int,height:int)->RID:
 var image:=_texture(rd,width,height,RenderingDevice.DATA_FORMAT_B10G11R11_UFLOAT_PACK32)
 if image.is_valid():_work_bytes+=width*height*4
 return image
func _kernel_pass(rd:RenderingDevice,input:RID,coarse:RID,output:RID,taps:Array,linear:RID)->bool:
 var values:=PackedFloat32Array([taps.size(),1. if coarse.is_valid()else 0.,0.,0.])
 for tap in taps:values.append_array(PackedFloat32Array([tap[0],tap[1],tap[2],0.]))
 var bytes:=values.to_byte_array();var buffer:=_keep(rd.storage_buffer_create(bytes.size(),bytes));_coefficient_bytes+=bytes.size()
 if not buffer.is_valid():return false
 var u:=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;u.binding=2;u.add_id(buffer)
 var uniforms:Array[RDUniform]=[_sample(0,linear,input),_sample(1,linear,coarse if coarse.is_valid()else input),u]
 var fb:=_keep(rd.framebuffer_create([output]));return fb.is_valid()and _prepare_pass(rd,FILTER,fb,uniforms)
func _make_shapes(rd:RenderingDevice,copy:RID,meter:RID,format:RDTextureFormat,linear:RID)->RID:
 var fields:Array[RID]=[];var sizes:Array[Vector2i]=[]
 var size:=Vector2i(ceili(float(format.width)/2.),ceili(float(format.height)/2.))
 for i in 6:
  var image:=_field(rd,size.x,size.y)
  if not image.is_valid():return RID()
  var fb:=_keep(rd.framebuffer_create([image]));var uniforms:Array[RDUniform]=[]
  if not fb.is_valid():return RID()
  if i==0:
   uniforms=[_sample(0,linear,copy),_sample(1,linear,meter)]
   if not _prepare_pass(rd,_coherent_air_source(2),fb,uniforms):return RID()
  else:
   uniforms=[_sample(0,linear,fields[-1])]
   if not _prepare_pass(rd,DOWN,fb,uniforms):return RID()
  fields.append(image);sizes.append(size);size=Vector2i(ceili(float(size.x)/2.),ceili(float(size.y)/2.))
 var coarse:=RID()
 for i in range(5,-1,-1):
  var size_here:Vector2i=sizes[i];var h:=_field(rd,size_here.x,size_here.y);var v:=_field(rd,size_here.x,size_here.y)
  if not h.is_valid()or not v.is_valid():return RID()
  var level:Dictionary=_shape_profile.levels[i]
  if not _kernel_pass(rd,fields[i],RID(),h,level.h,linear)or not _kernel_pass(rd,h,coarse,v,level.v,linear):return RID()
  coarse=v
 return coarse
func _shape_control(rd:RenderingDevice,weight:float)->RID:
 return _keep(rd.storage_buffer_create(16,PackedFloat32Array([weight,0.,0.,0.]).to_byte_array()))
func _build_air(rd:RenderingDevice,copy:RID,meter:RID,format:RDTextureFormat,linear:RID)->RID:
 var old:=super._build_air(rd,copy,meter,format,linear)
 if not old.is_valid()or not _render_shape or not _reference_requested or _reference_blocked:return old
 var mark:=_resources.size();var pass_mark:=_passes.size();_work_bytes=0;_coefficient_bytes=0
 var result:=_make_shapes(rd,copy,meter,format,linear)
 _guard.lock();var weight:=_shape_weight;_guard.unlock()
 if result.is_valid():_shape_buffer=_shape_control(rd,weight)
 if not result.is_valid()or not _shape_buffer.is_valid():
  var why:=failure()
  while _resources.size()>mark:rd.free_rid(_resources.pop_back())
  _passes.resize(pass_mark);_shape_buffer=RID();_shape_blocked=true;_render_shape=false
  _report("shape_error",why if not why.is_empty()else"Unsupported optional six-scale resources");_report("error","")
  return old
 _old_soft=old;_shape_ready=true;_last_shape_weight=weight;_air_bytes+=_work_bytes
 _report("shape_active",true);_report("shape_levels",6);_report("shape_bytes",_work_bytes+_coefficient_bytes+16);_report("shape_error","")
 return result
func _finish_fragment(fragment:String,rd:RenderingDevice,uniforms:Array[RDUniform])->String:
 fragment=super._finish_fragment(fragment,rd,uniforms)
 if not _shape_ready or not fragment.contains("vec3 spread = textureLod(soft_light, uv_air, 0.0).rgb;"):return fragment
 var sampler:RID=uniforms[2].get_ids()[0]
 uniforms.append(_sample(7,sampler,_old_soft))
 var u:=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;u.binding=8;u.add_id(_shape_buffer);uniforms.append(u)
 fragment=fragment.replace("void main() {","layout(set=0,binding=7)uniform sampler2D original_spread;\nlayout(set=0,binding=8,std430)readonly buffer ShapeControl{vec4 shape;};\nvoid main() {")
 return fragment.replace("vec3 spread = textureLod(soft_light, uv_air, 0.0).rgb;","vec3 spread = mix(textureLod(original_spread,uv_air,0.).rgb,textureLod(soft_light,uv_air,0.).rgb,shape.x);")
