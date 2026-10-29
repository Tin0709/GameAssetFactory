extends CompositorEffect
## Original generic log-domain 3D color-transform pass. Private LUT supplied by caller.
var lut:ImageTexture3D
var settings:=PackedFloat32Array()
var rd:RenderingDevice
var shader:=RID()
var pipeline:=RID()
var sampler:=RID()
var error:=""
const CODE:="""
#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform image2D scene;
layout(set=0,binding=1) uniform sampler3D transform_lut;
layout(push_constant,std430) uniform Params {vec4 size_exposure;vec4 encoding;vec4 finish;} p;
vec3 to_linear(vec3 c){return mix(c/12.92,pow((c+.055)/1.055,vec3(2.4)),greaterThan(c,vec3(.04045)));}
void main(){
 ivec2 q=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(q,ivec2(p.size_exposure.xy))))return;
 vec4 source=imageLoad(scene,q);
 vec2 centered=(vec2(q)+.5)/p.size_exposure.xy*2.-1.;
 float vignette=pow(1.+dot(centered*p.finish.x,centered*p.finish.x),-2.);
 vec3 hdr=max(source.rgb*p.size_exposure.z*vignette,vec3(0.));
 vec3 coordinate=clamp(log2(hdr+vec3(p.encoding.x))*p.encoding.y+p.encoding.z,0.,1.);
 vec3 display=clamp(textureLod(transform_lut,coordinate*(31./32.)+vec3(1./64.),0.).rgb*p.encoding.w,0.,1.);
 imageStore(scene,q,vec4(to_linear(display),source.a));
}
"""
func _init()->void:
	effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT;access_resolved_color=true
	rd=RenderingServer.get_rendering_device()
func _render_callback(kind:int,data:RenderData)->void:
	if rd==null or lut==null or kind!=effect_callback_type:return
	if not shader.is_valid():
		var code:=RDShaderSource.new();code.source_compute=CODE
		var spirv:=rd.shader_compile_spirv_from_source(code)
		if not spirv.compile_error_compute.is_empty():error=spirv.compile_error_compute;push_error(error);return
		shader=rd.shader_create_from_spirv(spirv);pipeline=rd.compute_pipeline_create(shader)
		var state:=RDSamplerState.new();state.mag_filter=RenderingDevice.SAMPLER_FILTER_LINEAR;state.min_filter=RenderingDevice.SAMPLER_FILTER_LINEAR
		state.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE;state.repeat_v=state.repeat_u;state.repeat_w=state.repeat_u;sampler=rd.sampler_create(state)
	var buffers:RenderSceneBuffersRD=data.get_render_scene_buffers();var size:=buffers.get_internal_size()
	if size.x==0 or size.y==0:return
	var constants:=settings.duplicate();constants[0]=size.x;constants[1]=size.y
	for view in buffers.get_view_count():
		var image:=RDUniform.new();image.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE;image.binding=0;image.add_id(buffers.get_color_layer(view))
		var lookup:=RDUniform.new();lookup.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;lookup.binding=1;lookup.add_id(sampler);lookup.add_id(RenderingServer.texture_get_rd_texture(lut.get_rid()))
		var uniforms:=UniformSetCacheRD.get_cache(shader,0,[image,lookup])
		var commands:=rd.compute_list_begin();rd.compute_list_bind_compute_pipeline(commands,pipeline);rd.compute_list_bind_uniform_set(commands,uniforms,0)
		rd.compute_list_set_push_constant(commands,constants.to_byte_array(),48);rd.compute_list_dispatch(commands,ceili(size.x/8.),ceili(size.y/8.),1);rd.compute_list_end()
func _notification(what:int)->void:
	if what==NOTIFICATION_PREDELETE and rd!=null:
		if shader.is_valid():rd.free_rid(shader)
		if sampler.is_valid():rd.free_rid(sampler)
