extends "res://scripts/world_map_multiscale_bloom.gd"
## Original source-order experiment. Native clock/radiometry are not established.
var _source_reference:WeakRef
var _source_requested:=false
var _source_weight:=0.
var _source_blocked:=false
var _source_render:=false
var _source_key:Array=[]
var _source_inputs:Dictionary={}
var _source_buffer:=RID()
var _source_uniform:=RID()
var _source_last:=PackedByteArray()
var _source_build:=false
var source_output:=RID() # Read-only diagnostic; owned by the ordinary air pass.

func set_bloom_source_reference(reference:Variant,value:bool,weight:float)->void:
	_guard.lock()
	if value and not _source_requested:_source_blocked=false
	_source_reference=weakref(reference)if reference!=null else null
	_source_requested=value
	_source_weight=clampf(weight,0.,1.)if is_finite(weight)else 0.
	_guard.unlock()

func _candidate(data:RenderData)->Dictionary:
	_guard.lock();var reference:=_source_reference;var requested:=_source_requested;var weight:=_source_weight;var blocked:=_source_blocked;var allowed:=_reference_requested and _reference_enabled and not _reference_blocked and _finish_wanted;var shape:=_shape_requested;_guard.unlock()
	if not requested or blocked or not allowed or shape or weight<=0. or reference==null:return {}
	var native=reference.get_ref()
	if native==null or not native.enabled or not native._ready_live or not native._error.is_empty()or not native.has_method("rendered_source"):return {}
	var buffers:=data.get_render_scene_buffers()as RenderSceneBuffersRD
	if buffers==null or buffers.get_view_count()!=1 or native._color!=buffers.get_color_layer(0)or native._size!=buffers.get_internal_size():return {}
	var graph:Dictionary=native._graph.outputs
	if not graph.has("grid")or not graph.has("blur"):return {}
	var raw:RID=native._copy;var grid:RID=graph.grid;var blur:RID=graph.blur
	if not raw.is_valid()or not grid.is_valid()or not blur.is_valid():return {}
	var bytes:PackedByteArray=native._parameters.get("final",PackedByteArray())
	if bytes.size()!=64:return {}
	bytes=bytes.duplicate()
	var state:Dictionary=native.rendered_source()
	var strength:=float(state.get("strength",0.))
	if state.get("frame",-1)!=native._frames or not is_finite(strength)or strength<=0. or strength>1.:return {}
	bytes.append_array(PackedFloat32Array([strength,strength,0.,0.]).to_byte_array())
	return {"raw":raw,"grid":grid,"blur":blur,"parameters":bytes}

func _render_callback(kind:int,data:RenderData)->void:
	if kind!=effect_callback_type:return
	var rd:=RenderingServer.get_rendering_device()
	if rd==null:return
	var candidate:=_candidate(data);var key:Array=[]
	if not candidate.is_empty():key=[candidate.raw,candidate.grid,candidate.blur]
	if key!=_source_key:_release(rd);_source_key=key
	_source_inputs=candidate;_source_render=not candidate.is_empty()
	if _source_buffer.is_valid()and _source_render and candidate.parameters!=_source_last:
		rd.buffer_update(_source_buffer,0,80,candidate.parameters);_source_last=candidate.parameters
	super(kind,data)
	_report("source_order_active",_source_render and _source_buffer.is_valid())
	_report("source_order_bytes",80 if _source_buffer.is_valid()else 0)

func _release(rd:RenderingDevice)->void:
	# Native texture teardown can already have invalidated this dependent set.
	if _source_uniform.is_valid():
		_resources.erase(_source_uniform)
		if rd.uniform_set_is_valid(_source_uniform):rd.free_rid(_source_uniform)
		_source_uniform=RID()
	_source_buffer=RID();_source_last=PackedByteArray();source_output=RID()
	_report("source_order_active",false);_report("source_order_bytes",0)
	super(rd)

func _texture(rd:RenderingDevice,width:int,height:int,format:int)->RID:
	var image:=super(rd,width,height,format)
	if _source_build and not source_output.is_valid():source_output=image
	return image

func _build_air(rd:RenderingDevice,copy:RID,meter:RID,format:RDTextureFormat,linear:RID)->RID:
	var count:=_resources.size();var passes:=_passes.size();_source_build=true
	var result:=super(rd,copy,meter,format,linear);_source_build=false
	if result.is_valid()or not _source_render:return result
	# Failure is local to this optional build. Preserve existing grade/F7 owners.
	var reason:=failure()
	for i in range(_resources.size()-1,count-1,-1):rd.free_rid(_resources[i])
	_resources.resize(count);_passes.resize(passes)
	_source_buffer=RID();_source_uniform=RID();_source_last=PackedByteArray();source_output=RID()
	_guard.lock();_source_blocked=true;_guard.unlock()
	_source_render=false;_report("source_order_error",reason);_report("error","")
	_source_build=true;result=super(rd,copy,meter,format,linear);_source_build=false
	return result

func _coherent_air_source(block:int=4)->String:
	var source:=super(block)
	if not _source_render:return source
	var ending:="result=vec4(sum/"+str(block*block)+".,1.);"
	if not source.contains(ending):_report("error","Optional source-order contract changed");return ""
	var helpers:="""// GAF_RECON_SOURCE_ORDER
layout(set=0,binding=2)uniform sampler2D raw_scene;
layout(set=0,binding=3)uniform sampler3D source_statistics;
layout(set=0,binding=4)uniform sampler2D source_broad_log;
layout(set=0,binding=5,std430)readonly buffer SourceSettings{vec4 s[];};
float source_gain(vec3 rgb,vec2 uv){
 float value=log2(max(dot(rgb*s[2].w,s[3].xyz),s[2].z));
 float depth=(value*s[1].z+s[1].w)*s[2].x+s[2].y;
 vec2 pair=textureLod(source_statistics,vec3(uv,depth),0.).rg;
 float broad=textureLod(source_broad_log,uv,0.).r;
 float local=pair.y<s[1].y?broad:pair.x/pair.y;
 float delta=local+(broad-local)*s[1].x+log2(s[0].x/s[0].y);
 float contrast=mix(1.,delta>0.?s[0].z:s[0].w,s[4].x);
 return exp2((contrast-1.)*delta);
}
"""
	source=source.replace("void main(){",helpers+"void main(){")
	var body:="""vec3 raw_sum=vec3(0.);
 for(int y=0;y<BLOCK;y++)for(int x=0;x<BLOCK;x++)raw_sum+=texelFetch(raw_scene,min(first+ivec2(x,y),dimensions-1),0).rgb;
 vec3 mean_raw=raw_sum/AREA;
 // Preserve the source half-resolution grid's one-full-pixel corner offset.
 // Quarter-resolution support and the phase crossfade are original adaptations.
 vec2 center=vec2(first)+vec2(HALF_BLOCK);
 vec2 stat_uv=(center-vec2(1.))/vec2(dimensions);
 vec3 candidate=mean_raw*source_gain(mean_raw,stat_uv);
 candidate*=scene_gain(candidate,center);
 result=vec4(mix(sum/AREA,candidate,s[4].y),1.);"""
	body=body.replace("HALF_BLOCK",str(float(block)*.5)).replace("BLOCK",str(block)).replace("AREA",str(float(block*block)))
	return source.replace(ending,body)

func _prepare_pass(rd:RenderingDevice,fragment:String,framebuffer:RID,uniforms:Array[RDUniform])->bool:
	var source_pass:=fragment.contains("// GAF_RECON_SOURCE_ORDER")
	if source_pass:
		var sampler:RID=uniforms[0].get_ids()[0]
		uniforms=uniforms.duplicate()
		uniforms.append(_sample(2,sampler,_source_inputs.raw));uniforms.append(_sample(3,sampler,_source_inputs.grid));uniforms.append(_sample(4,sampler,_source_inputs.blur))
		_source_last=_source_inputs.parameters;_source_buffer=_keep(rd.storage_buffer_create(80,_source_last))
		if not _source_buffer.is_valid():_report("error","Optional source parameter allocation failed");return false
		var setting:=RDUniform.new();setting.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;setting.binding=5;setting.add_id(_source_buffer);uniforms.append(setting)
	var valid:=super(rd,fragment,framebuffer,uniforms)
	if valid and source_pass:_source_uniform=_passes[-1][2]
	return valid
