extends "res://scripts/world_map_local_exposure.gd"
## Optional private Forest LUT transfer; native input radiometry is NOT established.
const PROFILE_FILE="godot_lab/world_map_unified_showcase_v001/forest_grade_transfer_v001/phase-profile.private.json"
const PROFILE_SHA="58de63a6dda994ab838f9a51488c5c7c2c1db803740559498220560b8f6b882c"
var reference_available:=false
var _profile:Dictionary={}
var _reference_requested:=false
var _reference_enabled:=false
var _reference_blocked:=false
var _reference_buffer:=RID()
var _last_flag:=false
var _phase_control:=Vector4(7,7,0,8)
var _last_phase:=Vector4(-1,-1,-1,-1)
func _init()->void:
 super()
 if not OS.has_feature("editor"):return
 var root:=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=root.path_join(PROFILE_FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=PROFILE_SHA:return
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or data.get("schema")!="private-forest-grade-transfer/2":return
 if not FileAccess.file_exists(data.lut)or FileAccess.get_sha256(data.lut)!=data.lut_sha256:return
 if FileAccess.get_file_as_bytes(data.lut).size()!=1048576:return
 if not data.get("parameters")is Array or data.parameters.size()!=3:return
 for row in data.parameters:
  if not row is Array or row.size()!=4:return
  for value in row:
   if not(value is float or value is int)or not is_finite(value):return
 var times=data.get("anchors")
 if not times is Array or times.size()!=8:return
 var expected:=[0.,5.5,6.5,7.,8.,9.,10.,12.]
 for i in 8:
  if not(times[i]is float or times[i]is int)or not is_finite(times[i])or float(times[i])!=expected[i]:return
 _profile=data;reference_available=true
 _report("reference_ready",false);_report("reference_bytes",0)
func set_reference_hour(hour:float)->void:
 if not reference_available or not is_finite(hour):return
 var h:=fposmod(hour,24.)
 if h>12.:h=24.-h # Original GAF mirror, not recovered MD2 clock.
 var anchors:Array=_profile.anchors;var i:=0
 while i<anchors.size()-2 and h>float(anchors[i+1]):i+=1
 var t:=smoothstep(float(anchors[i]),float(anchors[i+1]),h)
 _guard.lock();_phase_control=Vector4(i,i+1,t,8);_guard.unlock()
func prepare_reference_grade(value:bool)->void:
 _guard.lock();_reference_requested=value and reference_available and not _reference_blocked;_guard.unlock()
func set_reference_grade(value:bool)->void:
 _guard.lock();_reference_enabled=value and reference_available;_guard.unlock()
func _render_callback(kind:int,data:RenderData)->void:
 if kind!=effect_callback_type:return
 _guard.lock();var wanted:=_reference_requested;var applied:=_reference_enabled;var phase:=_phase_control;_guard.unlock()
 var rd:=RenderingServer.get_rendering_device()
 if rd==null:return
 if _reference_buffer.is_valid()and not wanted:_release(rd) # Restore the actual original APPLY pipeline on OFF.
 if wanted and not _reference_buffer.is_valid()and _color.is_valid():_release(rd)
 var flag:bool=applied and _source_format==HDR_FORMAT
 if _reference_buffer.is_valid()and flag!=_last_flag:
  rd.buffer_update(_reference_buffer,28,4,PackedFloat32Array([1. if flag else 0.]).to_byte_array());_last_flag=flag
 if _reference_buffer.is_valid()and phase!=_last_phase:
  rd.buffer_update(_reference_buffer,48,16,PackedFloat32Array([phase.x,phase.y,phase.z,phase.w]).to_byte_array());_last_phase=phase
 super._render_callback(kind,data)
 if wanted and not failure().is_empty():
  # Unsupported optional grading must preserve the approved exposure pipeline.
  var reason:=failure();_block_reference(reason);_report("error","");_release(rd)
  super._render_callback(kind,data)
func _block_reference(reason:String)->void:
 _guard.lock();_reference_blocked=true;_reference_requested=false;_reference_enabled=false;_guard.unlock()
 _report("reference_failure",reason)
func _release(rd:RenderingDevice)->void:
 _reference_buffer=RID();_last_flag=false
 _report("reference_ready",false);_report("reference_bytes",0)
 super._release(rd)
func _prepare_pass(rd:RenderingDevice,fragment:String,framebuffer:RID,uniforms:Array[RDUniform])->bool:
 if fragment==APPLY and reference_available and _reference_requested and not _reference_blocked:
  var profile:Dictionary=_profile
  if FileAccess.get_sha256(profile.lut)!=profile.lut_sha256:
   _block_reference("Private LUT changed after setup");return super._prepare_pass(rd,fragment,framebuffer,uniforms)
  var f:=RDTextureFormat.new();f.texture_type=RenderingDevice.TEXTURE_TYPE_3D;f.width=32;f.height=32;f.depth=256;f.format=COLOR_FORMAT;f.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
  if not rd.texture_is_format_supported_for_usage(f.format,f.usage_bits):
   _block_reference("Typed 3D LUT is unsupported");return super._prepare_pass(rd,fragment,framebuffer,uniforms)
  var lut:=_keep(rd.texture_create(f,RDTextureView.new(),[FileAccess.get_file_as_bytes(profile.lut)]))
  if not lut.is_valid():
   _block_reference("Typed 3D LUT allocation failed");return super._prepare_pass(rd,fragment,framebuffer,uniforms)
  var st:=RDSamplerState.new();st.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;st.mag_filter=st.min_filter;st.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;st.repeat_v=st.repeat_u;st.repeat_w=st.repeat_u;st.max_lod=0.
  var smp:=_keep(rd.sampler_create(st));uniforms.append(_sample(3,smp,lut))
  _reference_buffer=RID()
  var q:=PackedFloat32Array()
  for row in profile.parameters:
   for item in row:q.append(item)
  q[4]=0. # Isolate the LUT transfer; original scene vignette is suspended by owner.
  q[7]=1. if _reference_enabled else 0.
  q.append_array(PackedFloat32Array([_phase_control.x,_phase_control.y,_phase_control.z,_phase_control.w]));_last_phase=_phase_control
  var data:=q.to_byte_array();var buffer:=_keep(rd.storage_buffer_create(data.size(),data));var u:=RDUniform.new();u.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;u.binding=4;u.add_id(buffer);uniforms.append(u)
  _reference_buffer=buffer;_last_flag=_reference_enabled;_report("reference_ready",true);_report("reference_bytes",1048640)
  fragment=fragment.replace("void main() {", """layout(set=0,binding=3) uniform sampler3D forest_lut;
layout(set=0,binding=4,std430) readonly buffer Grade {vec4 q[];};
vec3 inverse_display(vec3 c){return mix(c/12.92,pow((c+.055)/1.055,vec3(2.4)),greaterThan(c,vec3(.04045)));}
void main() {""")
  fragment=fragment.replace("result = vec4(adjusted, color.a);", """if(q[1].w>.5){
 vec2 screen=gl_FragCoord.xy/vec2(textureSize(source_color,0));
 float aspect=float(textureSize(source_color,0).y)/float(textureSize(source_color,0).x);
 float k=q[2].z/sqrt(1.+aspect*aspect);vec2 edge=(screen*2.-1.)*vec2(k,k*aspect)*q[1].x;
 float v=1./(1.+dot(edge,edge));
 vec3 physical=adjusted*(air.z>.5?1.:2.);
 vec3 positive=max(physical*q[2].w*(v*v)+q[0].x,vec3(1e-20));
 vec3 logcoord=clamp(log2(positive)*q[0].y+q[0].z,0.,1.);
 vec3 coord=logcoord*(31./32.)+vec3(.5/32.);
 vec3 first=vec3(coord.xy,(coord.z+q[3].x)/q[3].w);
 vec3 display=textureLod(forest_lut,first,0.).rgb;
 if(q[3].z>0.){vec3 second=vec3(coord.xy,(coord.z+q[3].y)/q[3].w);display=mix(display,textureLod(forest_lut,second,0.).rgb,q[3].z);}
 display*=q[0].w;
 result=vec4(inverse_display(clamp(display,0.,1.)),color.a);
 }else{result=vec4(adjusted,color.a);}""")
 return super._prepare_pass(rd,fragment,framebuffer,uniforms)
