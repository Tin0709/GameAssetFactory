extends "res://scripts/world_map_reference_grade.gd"
## Original bridge between the approved GAF finish and a private reference transfer.
## The Filmic/BCS order follows Godot's public mathematical operations; verified on GPU.
const EDGES=preload("res://scripts/world_map_display_edges.gd")
const DepthDiffusion := preload("res://scripts/world_map_depth_diffusion.gd")
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
var _humid_weight := 0.
var _humid_actor := Vector4.ZERO
var _twilight_shadow_weight := 0.
var _depth_diffusion := DepthDiffusion.new()
var _humid_depth := PackedByteArray()
var _humid_mist: CompositorEffect

func set_humid_light(weight: float, actor: Vector4 = Vector4.ZERO, depth := PackedByteArray(), mist: CompositorEffect = null) -> void:
 var amount := clampf(weight, 0., 1.) if is_finite(weight) and actor.is_finite() else 0.
 _guard.lock()
 _humid_weight = amount
 _humid_actor = actor if amount > 0. else Vector4.ZERO
 _humid_depth = depth
 _humid_mist = mist
 _guard.unlock()

func set_twilight_shadow_color(weight: float) -> void:
 _guard.lock()
 _twilight_shadow_weight = clampf(weight, 0., 1.) if is_finite(weight) else 0.
 _guard.unlock()

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
  var data:=PackedFloat32Array([env.tonemap_exposure,env.tonemap_white,env.adjustment_brightness,env.adjustment_contrast,env.adjustment_saturation,1. if env.adjustment_enabled else 0.,clampf(weight,0.,1.),0.,0.,0.,0.,0.,0.,0.,0.,0.]).to_byte_array()
  _guard.lock();_baseline=data;_baseline_slices=slices;_finish_wanted=true
  if changed:_palette_generation+=1
  _guard.unlock()
 else:
  _guard.lock();_finish_wanted=false;_guard.unlock()
 return true
func set_finish_weight(value:float)->void:
 _guard.lock()
 if not _baseline.is_empty():_baseline.encode_float(24,clampf(value,0.,1.)if is_finite(value)else 0.)
 _guard.unlock()
func _render_callback(kind:int,data:RenderData)->void:
 if kind!=effect_callback_type:return
 var rd:=RenderingServer.get_rendering_device()
 if rd==null:return
 var buffers:=data.get_render_scene_buffers()as RenderSceneBuffersRD
 if buffers!=null and buffers.get_internal_size()!=_reported_size:
  _reported_size=buffers.get_internal_size();_report("render_size",[_reported_size.x,_reported_size.y])
 _guard.lock()
 var wanted := _finish_wanted
 var baseline := _baseline.duplicate()
 var generation := _palette_generation
 var edge := _edge_requested and wanted and _reference_enabled and _reference_requested and not _reference_blocked
 var humid_weight := _humid_weight if wanted and _parameters.decode_float(16) > 0. else 0.
 var humid_actor := _humid_actor if humid_weight > 0. else Vector4.ZERO
 var depth_data := _humid_depth
 var depth_mist := _humid_mist if humid_weight > 0. else null
 var twilight_shadow_weight := _twilight_shadow_weight if wanted and _reference_enabled else 0.
 _guard.unlock()
 if not baseline.is_empty():
  baseline.encode_float(28, humid_weight)
  baseline.encode_float(32, humid_actor.x)
  baseline.encode_float(36, humid_actor.y)
  baseline.encode_float(40, humid_actor.z)
  baseline.encode_float(44, humid_actor.w)
  baseline.encode_float(48, twilight_shadow_weight)
 var depth_changed := _depth_diffusion.refresh_sources(rd, buffers, depth_mist)
 if depth_changed or wanted!=_render_finish or edge!=_render_edge or(wanted and generation!=_render_palette_generation):
  _release(rd);_render_finish=wanted;_render_palette_generation=generation;_render_edge=edge
 _depth_diffusion.write(rd, depth_data)
 if _baseline_buffer.is_valid()and baseline!=_last_baseline:
  if rd.buffer_update(_baseline_buffer, 0, baseline.size(), baseline) == OK:
   _last_baseline = baseline
 super(kind,data)
 _report("humid_light_weight", _last_baseline.decode_float(28) if _baseline_buffer.is_valid() and failure().is_empty() else 0.)
 var depth_applied := _depth_diffusion.applied
 _report("humid_depth_weight", depth_applied.decode_float(28) if depth_applied.size() == DepthDiffusion.SETTINGS_SIZE and failure().is_empty() else 0.)
 _report("twilight_shadow_weight", _last_baseline.decode_float(48) if _baseline_buffer.is_valid() and failure().is_empty() else 0.)
func _release(rd:RenderingDevice)->void:
 _depth_diffusion.release(rd, _resources)
 _baseline_buffer=RID();_last_baseline=PackedByteArray();_report("finish_ready",false);_report("finish_bytes",0);_report("edge_active",false);_report("edge_bytes",0);_report("edge_size",[0,0])
 _report("twilight_shadow_weight",0.)
 super(rd)
func _finish_fragment(fragment:String,rd:RenderingDevice,uniforms:Array[RDUniform])->String:
 if not _render_finish or not fragment.contains("inverse_display(clamp(display,0.,1.))"):return fragment
 _guard.lock();var slices:=_baseline_slices.duplicate();var baseline:=_baseline.duplicate();_guard.unlock()
 if slices.size()!=32 or baseline.size()!=64:return fragment
 var format:=RDTextureFormat.new();format.texture_type=RenderingDevice.TEXTURE_TYPE_3D;format.width=32;format.height=32;format.depth=32;format.format=RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB;format.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
 if not rd.texture_is_format_supported_for_usage(format.format,format.usage_bits):
  _report("error","Owned finish requires sampled 3D sRGB texture support");return fragment
 var bytes:=PackedByteArray()
 for image in slices:bytes.append_array(image.get_data())
 var palette:=_keep(rd.texture_create(format,RDTextureView.new(),[bytes]));var sampler:=_sampler(rd,RenderingDevice.SAMPLER_FILTER_LINEAR)
 if not palette.is_valid()or not sampler.is_valid():_report("error","Owned finish palette allocation failed");return fragment
 uniforms.append(_sample(5,sampler,palette))
 _baseline_buffer=_keep(rd.storage_buffer_create(baseline.size(),baseline));_last_baseline=baseline
 if not _baseline_buffer.is_valid():_report("error","Owned finish parameter allocation failed");return fragment
 var uniform:=RDUniform.new();uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;uniform.binding=6;uniform.add_id(_baseline_buffer);uniforms.append(uniform)
 var depth_shader := _append_diffusion_depth(rd, uniforms)
 var helpers:="""layout(set=0,binding=5)uniform sampler3D gaf_palette;
layout(set=0,binding=6,std430)readonly buffer Baseline{vec4 base[];};
vec3 gaf_display(vec3 c){return mix(12.92*c,1.055*pow(max(c,vec3(0.)),vec3(1./2.4))-.055,greaterThan(c,vec3(.0031308)));}
vec3 gaf_filmic(vec3 c){return ((c*(.88*c+.06)+.002)/(c*(.88*c+.6)+.06))-(.01/.3);}
vec3 diffuse_humid_light(vec3 source, vec3 surrounding, vec2 uv){
 float y = dot(source, luma);
 float nearby = dot(surrounding, luma);
 float separation = length((uv - base[2].xy) * base[2].zw);
 float outside_actor = smoothstep(1., 1.65, separation);
 float lit = smoothstep(.025, .23, max(y, nearby));
 float dark_detail = smoothstep(.005, .038, y);
 float weight = .58 * base[1].w * lit * dark_detail * outside_actor;
 float limit = .58 * max(y, .022);
 return max(source + weight * clamp(surrounding - source, vec3(-limit), vec3(limit)), vec3(0.));
}
vec3 gaf_finish(vec3 c){
 c=vec3(unpackHalf2x16(packHalf2x16(c.rg)),unpackHalf2x16(packHalf2x16(vec2(c.b,0.))).x);
 c=gaf_filmic(max(c*base[0].x,vec3(0.)))/gaf_filmic(vec3(base[0].y));
 if(base[1].y>.5){c=gaf_display(c*base[0].z);c=mix(vec3(.5),c,base[0].w);c=mix(vec3(dot(c,vec3(1./3.))),c,base[1].x);c=textureLod(gaf_palette,clamp(c,0.,1.),0.).rgb;}
 return c;
}
vec3 recover_twilight_shadow_color(vec3 graded, vec3 original) {
 float y = dot(graded, luma);
 float blue = max(graded.b - graded.g, 0.);
 if (base[3].x <= 0. || blue <= 0. || y <= .004 || y >= .17) return graded;
 float lost_red = original.r / max(original.g, .001) - graded.r / max(graded.g, .001);
 float mask = smoothstep(.14,.64,blue / max(y,.008)) * smoothstep(.12,.44,lost_red);
 mask *= smoothstep(.004,.017,y) * (1. - smoothstep(.075,.17,y));
 // Restore part of the red chroma from the original finish at fixed luminance.
 // Keep green and enough blue to retain the cool shadow hue.
 float missing = max(original.r * y / max(dot(original,luma),.00001) - graded.r, 0.);
 float shift = min(missing, .85 * blue * luma.b / luma.r) * mask * base[3].x;
 return graded + vec3(shift, 0., -shift * luma.r / luma.b);
}
"""
 if not depth_shader.is_empty():
  helpers = depth_shader + helpers.replace("float limit = .58 * max(y, .022);",
   "weight *= gaf_diffusion_by_depth(uv);\n float limit = .58 * max(y, .022);")
 fragment=fragment.replace("void main() {",helpers+"void main() {")
 fragment=fragment.replace("adjusted += spread * air.x;","if (base[1].w > 0.) adjusted = diffuse_humid_light(adjusted, spread, uv_air);\n\t\tadjusted += spread * air.x;")
 fragment=fragment.replace("if (settings.x <= 0.0)","if (settings.x < 0.0)")
 fragment=fragment.replace("result=vec4(inverse_display(clamp(display,0.,1.)),color.a);","vec3 original_finish = gaf_finish(adjusted);\n\t\tvec3 mixed_finish = mix(original_finish,inverse_display(clamp(display,0.,1.)),base[1].z);\n\t\tresult=vec4(recover_twilight_shadow_color(mixed_finish,original_finish),color.a);")
 if _render_edge:
  fragment=fragment.replace("color.a);", "color.a);result.rgb=clamp(gaf_display(result.rgb),0.,1.);")
 _report("finish_ready",true);_report("finish_bytes",131072+baseline.size())
 return fragment

func _append_diffusion_depth(rd: RenderingDevice, uniforms: Array[RDUniform]) -> String:
 if not _depth_diffusion.depth.is_valid() or not _depth_diffusion.volume.is_valid():
  return ""
 _guard.lock()
 var data := _humid_depth
 _guard.unlock()
 if data.size() != DepthDiffusion.SETTINGS_SIZE:
  return ""
 var storage := _keep(rd.storage_buffer_create(DepthDiffusion.SETTINGS_SIZE, data))
 var depth_sampler := _sampler(rd, RenderingDevice.SAMPLER_FILTER_NEAREST)
 var mist_sampler := _sampler(rd, RenderingDevice.SAMPLER_FILTER_LINEAR)
 if not storage.is_valid() or not depth_sampler.is_valid() or not mist_sampler.is_valid():
  return ""
 _depth_diffusion.settings_buffer = storage
 _depth_diffusion.applied = data
 uniforms.append(_sample(7, depth_sampler, _depth_diffusion.depth))
 uniforms.append(_sample(8, mist_sampler, _depth_diffusion.volume))
 var settings := RDUniform.new()
 settings.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
 settings.binding = 9
 settings.add_id(storage)
 uniforms.append(settings)
 return DepthDiffusion.SHADER

func _prepare_finish_pass(rd: RenderingDevice, fragment: String, framebuffer: RID, uniforms: Array[RDUniform]) -> bool:
 var first := _passes.size()
 var ready := super._prepare_pass(rd, fragment, framebuffer, uniforms)
 if fragment == APPLY and ready and _depth_diffusion.settings_buffer.is_valid():
  _depth_diffusion.uniform_set = _passes[first][2]
 return ready

func _prepare_pass(rd:RenderingDevice,fragment:String,framebuffer:RID,uniforms:Array[RDUniform])->bool:
 if fragment!=APPLY or not _render_edge or not _render_finish or not _reference_requested or _reference_blocked:return _prepare_finish_pass(rd,fragment,framebuffer,uniforms)
 # _color is assigned after _build; borrow source_color texture dimensions instead.
 var source:RID=uniforms[0].get_ids()[1]
 var format:=rd.texture_get_format(source)
 var image:=_texture(rd,format.width,format.height,COLOR_FORMAT)
 if not image.is_valid():_report("error","Display-edge target unsupported");return false
 var target:=_keep(rd.framebuffer_create([image]))
 if not target.is_valid():return false
 if not _prepare_finish_pass(rd,fragment,target,uniforms):return false
 if not _baseline_buffer.is_valid():_report("error","Display edges require owned final color transfer");return false
 var parameters:=RDUniform.new();parameters.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;parameters.binding=1;parameters.add_id(_baseline_buffer)
 var linear:=_sampler(rd,RenderingDevice.SAMPLER_FILTER_LINEAR)
 if not linear.is_valid()or not super._prepare_pass(rd,EDGES.FRAGMENT,framebuffer,[_sample(0,linear,image),parameters]):return false
 _report("edge_active",true);_report("edge_bytes",format.width*format.height*4);_report("edge_size",[format.width,format.height]);_report("edge_error","")
 return true
