extends CompositorEffect
## Integrates one original participating medium before any surface is shaded.
var texture:=Texture3DRD.new()
var _mutex:=Mutex.new()
const PATH_SOURCE_BYTES := 32
const GPU_PARAMETER_BYTES := 256
const DIRECTIONAL_PARAMETER_BYTES := 64
const LOCAL_MIST_BYTES := 48
var directional_grid: ImageTexture3D
var directional_provider: Callable
var _directional_parameters := PackedByteArray()
var _parameters:=PackedByteArray()
var _path_parameters := PackedByteArray()
var _local_mist_parameters := PackedByteArray()
var _additional_mist_parameters := PackedByteArray()
var _size:=Vector2i.ZERO
var _noise:=RID()
var _light:=RID()
var _allocated_light:=RID()
var _state:={"ready":false,"error":"","frames":0,"rebuilds":0,"bytes":0,"local_mist_gain":0.,"additional_mist_gain":0.}
var _resources:Array[RID]=[]
var _allocated:=Vector2i.ZERO
var _buffer:=RID()
var _pipeline:=RID()
var _uniform:=RID()
func _init():effect_callback_type=EFFECT_CALLBACK_TYPE_PRE_OPAQUE
func configure(parameters:PackedByteArray,size:Vector2i,noise:RID,light:RID=RID())->void:
	configure_path_light(parameters,size,noise,light,PackedFloat32Array())

func configure_path_light(parameters: PackedByteArray, size: Vector2i, noise: RID, light: RID, path_light: PackedFloat32Array) -> void:
	configure_with_local_mist(parameters,size,noise,light,path_light,PackedFloat32Array())

func configure_with_local_mist(parameters: PackedByteArray, size: Vector2i, noise: RID, light: RID,
		path_light: PackedFloat32Array, local_mist: PackedFloat32Array) -> void:
	configure_with_mist_regions(parameters, size, noise, light, path_light, local_mist, PackedFloat32Array())

func configure_with_mist_regions(parameters: PackedByteArray, size: Vector2i, noise: RID, light: RID,
		path_light: PackedFloat32Array, local_mist: PackedFloat32Array, additional_mist: PackedFloat32Array) -> void:
	var path_bytes := path_light.to_byte_array()
	if path_bytes.size() != PATH_SOURCE_BYTES:
		path_bytes.resize(PATH_SOURCE_BYTES)
		path_bytes.fill(0)
	var directional_bytes := PackedByteArray()
	if directional_grid != null:
		if directional_provider.is_valid():
			var values: PackedFloat32Array = directional_provider.call()
			directional_bytes = values.to_byte_array()
		if directional_bytes.size() != DIRECTIONAL_PARAMETER_BYTES:
			directional_bytes.resize(DIRECTIONAL_PARAMETER_BYTES)
			directional_bytes.fill(0)
	var local_bytes := local_mist.to_byte_array()
	if local_bytes.size() != LOCAL_MIST_BYTES:
		local_bytes.resize(LOCAL_MIST_BYTES)
		local_bytes.fill(0)
	var additional_bytes := additional_mist.to_byte_array()
	if additional_bytes.size() != LOCAL_MIST_BYTES:
		additional_bytes.resize(LOCAL_MIST_BYTES)
		additional_bytes.fill(0)
	_mutex.lock()
	_parameters=parameters.duplicate()
	_path_parameters = path_bytes
	_directional_parameters = directional_bytes
	_local_mist_parameters = local_bytes
	_additional_mist_parameters = additional_bytes
	if _parameters.size()==176:_parameters.resize(224) # Legacy fixtures: neutral new-light branch.
	_state.point_kernel=_parameters.size()==224 and _parameters.decode_float(172)>.5
	_size=size;_noise=noise;_light=light
	if size!=_allocated or light!=_allocated_light:_state.ready=false
	_mutex.unlock()
func snapshot()->Dictionary:
	_mutex.lock();var copy:=_state.duplicate();_mutex.unlock()
	if not enabled:
		copy.local_mist_gain=0.
		copy.additional_mist_gain=0.
	return copy
func near_entry_m() -> float:
	_mutex.lock()
	var entry := _parameters.decode_float(12) if _parameters.size() >= 16 else 0.0
	_mutex.unlock()
	return entry
func _report(key:String,value:Variant):
	_mutex.lock();_state[key]=value;_mutex.unlock()
func _keep(rid:RID)->RID:
	if rid.is_valid():_resources.append(rid)
	return rid
func _build(rd:RenderingDevice,size:Vector2i,noise:RID,light:RID)->bool:
	var shape:=RDTextureFormat.new();shape.texture_type=RenderingDevice.TEXTURE_TYPE_3D
	shape.width=size.x;shape.height=size.y;shape.depth=32;shape.format=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	shape.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	if not rd.texture_is_format_supported_for_usage(shape.format,shape.usage_bits):_report("error","RGBA16F volume storage unavailable");return false
	var volume:=_keep(rd.texture_create(shape,RDTextureView.new()))
	var source:=RDShaderSource.new();source.source_compute=FileAccess.get_file_as_string("res://materials/world_map_mist_field.glsl").replace("#[compute]","")
	if directional_grid != null:
		source.source_compute = source.source_compute.replace("#version 450", "#version 450\n#define GAF_DIRECTIONAL_AIR")
	var spirv:=rd.shader_compile_spirv_from_source(source)
	var error:=spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if not error.is_empty():_report("error",error);return false
	var shader:=_keep(rd.shader_create_from_spirv(spirv));_pipeline=_keep(rd.compute_pipeline_create(shader))
	var parameter_size := GPU_PARAMETER_BYTES + 2 * LOCAL_MIST_BYTES + (DIRECTIONAL_PARAMETER_BYTES if directional_grid != null else 0)
	_buffer=_keep(rd.uniform_buffer_create(parameter_size))
	var sampler_state:=RDSamplerState.new();sampler_state.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;sampler_state.mag_filter=RenderingDevice.SAMPLER_FILTER_LINEAR
	var sampler:=_keep(rd.sampler_create(sampler_state));var noise_rd:=RenderingServer.texture_get_rd_texture(noise)
	if not volume.is_valid() or not shader.is_valid() or not _pipeline.is_valid() or not noise_rd.is_valid():return false
	var image:=RDUniform.new();image.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;image.binding=0;image.add_id(volume)
	var sample:=RDUniform.new();sample.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;sample.binding=1;sample.add_id(sampler);sample.add_id(noise_rd)
	var settings:=RDUniform.new();settings.uniform_type=RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER;settings.binding=2;settings.add_id(_buffer)
	var light_rd:=RenderingServer.texture_get_rd_texture(light)if light.is_valid()else RID()
	if not light_rd.is_valid():
		var white:=RDTextureFormat.new();white.texture_type=RenderingDevice.TEXTURE_TYPE_3D;white.width=1;white.height=1;white.depth=1;white.format=RenderingDevice.DATA_FORMAT_R8_UNORM;white.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		light_rd=_keep(rd.texture_create(white,RDTextureView.new(),[PackedByteArray([255])]))
	var lighting:=RDUniform.new();lighting.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;lighting.binding=3;lighting.add_id(sampler);lighting.add_id(light_rd)
	var bindings: Array[RDUniform] = [image, sample, settings, lighting]
	if directional_grid != null:
		var direction_rd := RenderingServer.texture_get_rd_texture(directional_grid.get_rid())
		if not direction_rd.is_valid(): return false
		var direction := RDUniform.new()
		direction.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		direction.binding = 4
		direction.add_id(sampler)
		direction.add_id(direction_rd)
		bindings.append(direction)
	_uniform=_keep(rd.uniform_set_create(bindings,shader,0))
	if not _uniform.is_valid():return false
	texture.texture_rd_rid=volume
	_mutex.lock();_allocated=size;_allocated_light=light;_state.bytes=size.x*size.y*32*8;_state.rebuilds+=1;_mutex.unlock()
	return true
func _render_callback(kind:int,data:RenderData)->void:
	if kind!=effect_callback_type:return
	_mutex.lock();var parameters:=_parameters.duplicate();var path_parameters:=_path_parameters;var directional_parameters:=_directional_parameters;var local_parameters:=_local_mist_parameters;var additional_parameters:=_additional_mist_parameters;var size:=_size;var noise:=_noise;var light:=_light;var error:String=_state.error;_mutex.unlock()
	if parameters.size()!=224 or size.x<=0 or not error.is_empty():return
	var rd:=RenderingServer.get_rendering_device();var buffers:=data.get_render_scene_buffers() as RenderSceneBuffersRD
	if rd==null or buffers==null or buffers.get_view_count()!=1:return
	if size!=_allocated or light!=_allocated_light:
		_release(rd)
		if not _build(rd,size,noise,light):
			if snapshot().error.is_empty():_report("error","Could not create mist field")
			return
	parameters.append_array(path_parameters)
	parameters.append_array(directional_parameters)
	parameters.append_array(local_parameters)
	parameters.append_array(additional_parameters)
	rd.buffer_update(_buffer,0,parameters.size(),parameters)
	var list:=rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(list,_pipeline);rd.compute_list_bind_uniform_set(list,_uniform,0)
	rd.compute_list_dispatch(list,ceili(size.x/8.),ceili(size.y/8.),1);rd.compute_list_end()
	_mutex.lock()
	_state.ready=true
	_state.frames+=1
	_state.local_mist_gain=local_parameters.decode_float(12)
	_state.additional_mist_gain=additional_parameters.decode_float(12)
	_mutex.unlock()
func release_on_render_thread():
	var rd:=RenderingServer.get_rendering_device()
	if rd!=null:_release(rd)
func _release(rd:RenderingDevice):
	texture.texture_rd_rid=RID()
	_resources.reverse()
	for rid in _resources:rd.free_rid(rid)
	_resources.clear();_mutex.lock();_allocated=Vector2i.ZERO;_allocated_light=RID();_state.ready=false;_mutex.unlock()
