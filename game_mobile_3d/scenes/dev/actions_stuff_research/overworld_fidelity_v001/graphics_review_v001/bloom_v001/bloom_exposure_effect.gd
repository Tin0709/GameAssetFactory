extends "../local_exposure_v001/local_exposure_effect.gd"
## Original optional bloom layered onto the unchanged conformed exposure effect.
const BloomGraph=preload("bloom_pipeline.gd")
const Units=preload("unit_contract.gd")
const BLOOM_FOLDER="res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/bloom_v001/shaders"
var _bloom_graph=BloomGraph.new()
var _bloom_enabled:=false
var _bloom_ready:=false
var _bloom_data:Dictionary={}
var _bloom_sets:Array[RID]=[]
var _bloom_owned:Array[RID]=[]
var _bloom_frames:=0
var _bloom_profile_hash:=""
var _setup_fb:=RID()
var _setup_pipeline:=RID()
var _setup_set:=RID()
var _combine_pipeline:=RID()
var _combine_set:=RID()
func _numeric(value:Variant)->bool:
 return typeof(value)in[TYPE_INT,TYPE_FLOAT]and is_finite(float(value))
func configure_bloom_external(path:String)->bool:
 if _bloom_ready or not _bloom_data.is_empty():return true
 var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not raw is Dictionary or raw.get("schema","")!="original_reference_bloom_parameters_v1"or not raw.get("steps",null)is Array or raw.steps.size()!=17:return false
 if not raw.get("units",null)is Dictionary or not raw.get("setup",null)is Dictionary:return false
 for key:String in["grade","eye","pre_exposure"]:
  if not _numeric(raw.units.get(key,null)):return false
 for key:String in["path","sha256"]:
  if not raw.setup.get(key,null)is String:return false
 var u:Dictionary=raw.get("units",{});var units:Dictionary=Units.conversion(float(u.get("grade",0.)),float(u.get("eye",0.)),float(u.get("pre_exposure",0.)))
 if not units.valid or abs(units.physical_scale-float(_parameters.final.decode_float(44)))>1e-6 or abs(float(u.eye)-float(_parameters.final.decode_float(0)))>1e-7:return false
 var setup:Dictionary=raw.get("setup",{});var bytes:=FileAccess.get_file_as_bytes(str(setup.get("path","")))
 if bytes.size()!=96 or _digest(bytes)!=setup.get("sha256",""):return false
 if abs(float(bytes.decode_float(8))-units.physical_scale)>1e-6 or abs(float(bytes.decode_float(12))-float(u.pre_exposure))>1e-7:return false
 var prepared:Array=[];var available:Dictionary={"source":true}
 for step:Variant in raw.steps:
  if not step is Dictionary or step.get("kind","")not in["downsample","gaussian"]or not step.get("inputs",null)is Array or step.inputs.size()<1 or step.inputs.size()>2:return false
  for key:String in["tap_count","width","height"]:
   if not _numeric(step.get(key,null))or float(step[key])!=floorf(float(step[key])):return false
  for key:String in["path","sha256","output"]:
   if not step.get(key,null)is String:return false
  for id:Variant in step.inputs:
   if not id is String:return false
  var taps:=int(step.get("tap_count",0));var size:=Vector2i(int(step.get("width",0)),int(step.get("height",0)))
  if size.x<1 or size.y<1 or size.x>1024 or size.y>576:return false
  if step.kind=="gaussian"and taps not in[8,12,27,32]:return false
  if step.kind=="downsample"and(taps!=4 or step.inputs.size()!=1):return false
  for id:String in step.inputs:
   if not available.has(id):return false
  var out:String=step.get("output","")
  if out.is_empty()or available.has(out):return false
  available[out]=true
  var p:=FileAccess.get_file_as_bytes(str(step.get("path","")))
  if p.size()!=(32 if step.kind=="downsample"else(1+2*taps)*16)or _digest(p)!=step.get("sha256",""):return false
  var next:Dictionary=step.duplicate(true);next.parameters=p;prepared.append(next)
 var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(BLOOM_FOLDER.path_join("manifest.json")))
 if not manifest is Dictionary or not manifest.get("files",null)is Dictionary:return false
 for file:String in manifest.files:
  if not manifest.files[file]is String:return false
  if file.get_file()!=file or FileAccess.get_sha256(BLOOM_FOLDER.path_join(file))!=manifest.files[file]:return false
 _bloom_data={"setup":bytes,"steps":prepared,"to_current":float(units.to_current)};_bloom_profile_hash=FileAccess.get_sha256(path);return true
func bloom_configured()->bool:return not _bloom_data.is_empty()
func set_bloom_enabled(value:bool)->void:
 _mutex.lock();_bloom_enabled=value;_mutex.unlock()
func _publish_snapshot()->void:
 super._publish_snapshot();_mutex.lock();_published.bloom_requested=_bloom_enabled;_published.bloom_frames=_bloom_frames;_published.bloom_ready=_bloom_ready;_published.bloom_profile_sha256=_bloom_profile_hash;_published.bloom_graph_RIDs=_bloom_graph.owned.size();_published.bloom_shader_hashes=_bloom_graph.source_hashes.duplicate();_mutex.unlock()
func _ensure_bloom(rd:RenderingDevice)->bool:
 if _bloom_ready:return true
 if _bloom_data.is_empty():_error="Bloom reference parameters unavailable";return false
 var f:=RDTextureFormat.new();f.width=1024;f.height=576;f.format=RenderingDevice.DATA_FORMAT_B10G11R11_UFLOAT_PACK32;f.usage_bits=RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
 var setup_texture:=rd.texture_create(f,RDTextureView.new(),[]);_setup_fb=rd.framebuffer_create([setup_texture]);_bloom_owned.append_array([setup_texture,_setup_fb])
 var st:=RDSamplerState.new();st.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;st.mag_filter=st.min_filter;st.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;st.repeat_v=st.repeat_u;st.repeat_w=st.repeat_u;st.min_lod=0.;st.max_lod=0.;var sampler:=rd.sampler_create(st);_bloom_owned.append(sampler)
 var shader:=_compile_raster(rd,FileAccess.get_file_as_string(BLOOM_FOLDER.path_join("setup.frag.glslinc")))
 if not _error.is_empty():return false
 _setup_pipeline=_raster_pipeline(rd,shader,_setup_fb)
 _setup_set=rd.uniform_set_create([_sampler_uniform(0,_half,sampler),_sampler_uniform(1,_graph.outputs.grid,sampler),_sampler_uniform(2,_graph.outputs.blur,sampler),_storage_uniform(rd,3,_bloom_data.setup)],shader,0);_bloom_sets.append(_setup_set)
 if not _bloom_graph.initialize_bloom(rd,setup_texture,_bloom_data.steps,BLOOM_FOLDER):_error=_bloom_graph.error;return false
 var fragment:="""#version 450
layout(set=0,binding=0)uniform sampler2D source_color;
layout(set=0,binding=1)uniform sampler3D exposure_grid;
layout(set=0,binding=2)uniform sampler2D blurred_log;
layout(std430,set=0,binding=3)readonly buffer Parameters{vec4 p[];};
layout(set=0,binding=4)uniform sampler2D filtered_bloom;
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
 float contrast=delta>0.?p[0].z:p[0].w;float gain=exp2((contrast-1.)*delta);
 vec2 half_texel=.5/vec2(textureSize(filtered_bloom,0));vec2 bloom_uv=clamp(uv,half_texel,1.-half_texel);
 vec3 bloom=textureLod(filtered_bloom,bloom_uv,0.).rgb*control.value.y;
 output_color=vec4(color.rgb*gain+bloom,color.a);
}
"""
 var final_shader:=_compile_raster(rd,fragment)
 if not _error.is_empty():return false
 _combine_pipeline=_raster_pipeline(rd,final_shader,_scene_fb)
 var last:String=_bloom_data.steps[-1].output
 _combine_set=rd.uniform_set_create([_sampler_uniform(0,_copy,sampler),_sampler_uniform(1,_graph.outputs.grid,sampler),_sampler_uniform(2,_graph.outputs.blur,sampler),_storage_uniform(rd,3,_parameters.final),_sampler_uniform(4,_bloom_graph.outputs[last],sampler)],final_shader,0);_bloom_sets.append(_combine_set)
 _bloom_ready=_setup_set.is_valid()and _combine_set.is_valid()and _combine_pipeline.is_valid()
 if not _bloom_ready:_error="Bloom resources unsupported"
 return _bloom_ready
func _render_pass(rd:RenderingDevice,framebuffer:RID,pipeline:RID,uniform_set:RID,control:PackedByteArray=PackedByteArray())->void:
 _mutex.lock();var use_bloom:=_bloom_enabled and not _neutral;_mutex.unlock()
 if use_bloom and framebuffer==_scene_fb and pipeline==_final_pipeline:
  if not _ensure_bloom(rd):return
  super._render_pass(rd,_setup_fb,_setup_pipeline,_setup_set,PackedFloat32Array([0.,0.,0.,0.]).to_byte_array())
  if not _bloom_graph.execute_bloom():_error=_bloom_graph.error;return
  super._render_pass(rd,_scene_fb,_combine_pipeline,_combine_set,PackedFloat32Array([1.,float(_bloom_data.to_current),0.,0.]).to_byte_array());_bloom_frames+=1;return
 super._render_pass(rd,framebuffer,pipeline,uniform_set,control)
func _release_resources()->void:
 var rd:=RenderingServer.get_rendering_device()
 _bloom_sets.reverse()
 for r:RID in _bloom_sets:
  if r.is_valid()and rd.uniform_set_is_valid(r):rd.free_rid(r)
 _bloom_sets.clear();_bloom_graph.release();_bloom_graph=BloomGraph.new();_bloom_owned.reverse()
 for r:RID in _bloom_owned:
  if r.is_valid():rd.free_rid(r)
 _bloom_owned.clear();_bloom_ready=false;super._release_resources()
