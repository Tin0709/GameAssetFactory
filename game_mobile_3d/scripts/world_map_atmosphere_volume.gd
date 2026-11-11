extends Node3D
## Shared camera-scoped medium. No scene-color/depth copy or fullscreen overlay.
const FIELD=preload("res://scripts/world_map_mist_field.gd")
static var _owner:WeakRef
var effect:CompositorEffect
var noise:ImageTexture
var _camera:Camera3D
var _profile:Dictionary={}
var _actor:=Vector3.ZERO
var _base:=0.
var _clock:=0.
var _radius:=8.
var _bound_generation:=-1
var _gate:=false
var noise_strength:=1.
var recovered_point_kernel:=false
var material_provider:Callable
var compositor_owned:Callable
var medium_state:Callable
var light_provider:Callable
var _variants:Dictionary={}
var _bound_materials:Dictionary={}
var _owned_compositor:Compositor
var _previous_compositor:Compositor
func setup()->void:
 name="SpatialAtmosphereVolume";process_mode=Node.PROCESS_MODE_ALWAYS;process_priority=100
 _camera=get_parent() as Camera3D
 effect=FIELD.new();effect.enabled=false
 _owner=weakref(self)
 RenderingServer.global_shader_parameter_set("gaf_mist_enabled",false)
 var image:=Image.create(64,64,false,Image.FORMAT_RF)
 var source:=FastNoiseLite.new();source.seed=318;source.frequency=.04;source.fractal_octaves=3
 for y in 64:
  for x in 64:
   image.set_pixel(x,y,Color(clampf(source.get_noise_2d((x-32)*4.,(y-32)*4.)*.5+.5,0.,1.),0,0))
 noise=ImageTexture.create_from_image(image);hide()
func publish(p:Dictionary,actor:Vector3,base:float,time:float,_ortho:bool,radius:float)->void:
 _profile=p;_actor=actor;_base=base;_clock=time;_radius=radius
func set_warm_emitter(point:Vector3)->void:
 if point.is_finite():_actor=point-Vector3.UP*1.4
func _append(v:Vector3,values:PackedFloat32Array,w:float=0.)->void:values.append_array(PackedFloat32Array([v.x,v.y,v.z,w]))
func _process(_delta:float)->void:
 if effect==null:return
 if _owner==null or _owner.get_ref()!=self:effect.enabled=false;_gate=false;_sync_materials(false);return
 var active:=visible and is_visible_in_tree() and not _profile.is_empty() and _camera!=null
 effect.enabled=active
 if not active:
  _set_gate(false);_sync_materials(false);return
 var compositor:=_camera.compositor
 if compositor==null or not effect in compositor.compositor_effects:
  # The showcase exposure owner explicitly grants its single-camera resource.
  # All other resources are borrowed: clone the list, including environment fallback.
  if compositor==null or not compositor_owned.is_valid() or not compositor_owned.call(compositor):
   _previous_compositor=compositor
   var source:=compositor
   if source==null:
    var world_environment:=_camera.get_tree().current_scene.get_node_or_null("WorldEnvironment") if _camera.get_tree().current_scene!=null else null
    if world_environment is WorldEnvironment:source=world_environment.compositor
   compositor=Compositor.new()
   if source!=null:compositor.compositor_effects=source.compositor_effects.duplicate()
   _owned_compositor=compositor;_camera.compositor=compositor
  var effects=compositor.compositor_effects.duplicate();effects.append(effect);compositor.compositor_effects=effects
 var viewport_size:=_camera.get_viewport().get_visible_rect().size
 var size:=Vector2i(clampi(ceili(viewport_size.x/16.),16,128),clampi(ceili(viewport_size.y/16.),16,96))
 var is_ortho:=_camera.projection==Camera3D.PROJECTION_ORTHOGONAL
 var origin:=_camera.global_position
 var tl:=_camera.project_position(Vector2.ZERO,1.)
 var tr:=_camera.project_position(Vector2(viewport_size.x,0),1.)
 var bl:=_camera.project_position(Vector2(0,viewport_size.y),1.)
 var ray:Vector3
 var dx:=Vector3.ZERO;var dy:=Vector3.ZERO;var ray_dx:=Vector3.ZERO;var ray_dy:=Vector3.ZERO
 if is_ortho:
  ray=-_camera.global_basis.z;origin=tl-ray;dx=tr-tl;dy=bl-tl
 else:
  ray=tl-origin;ray_dx=tr-tl;ray_dy=bl-tl
 var data:=PackedFloat32Array()
 var near_layer:Vector3=_profile.get("near_layer",Vector3.ZERO)
 if not is_ortho or near_layer.y<=0. or near_layer.x<=0. or near_layer.x>=float(_profile.fog_begin):
  near_layer=Vector3.ZERO
 _append(origin,data,near_layer.x)
 _append(dx,data,near_layer.y)
 _append(dy,data,near_layer.z)
 for v in [ray,ray_dx,ray_dy]:_append(v,data)
 data.append_array(PackedFloat32Array([_profile.volume_density,_profile.height_falloff,_base,_clock]))
 var rgb:Vector3=_profile.fog_color;var color:=Color(rgb.x,rgb.y,rgb.z).srgb_to_linear()
 var linear:Vector3=_profile.get("linear_scatter_rgb",Vector3(color.r,color.g,color.b))
 _append(linear,data,float(_profile.get("scatter_energy",.25)))
 _append(_actor,data,_profile.player_light_weight)
 var warm:Vector3=_profile.player_light_color;var warm_linear:=Color(warm.x,warm.y,warm.z).srgb_to_linear()
 _append(Vector3(warm_linear.r,warm_linear.g,warm_linear.b),data,_radius)
 data.append_array(PackedFloat32Array([_profile.fog_begin,_camera.far,noise_strength,1. if recovered_point_kernel else 0.]))
 var light:Dictionary=light_provider.call()if light_provider.is_valid()else {"valid":false}
 var light_rid:=RID()
 if light.get("texture")!=null:light_rid=light.texture.get_rid()
 var near_fade_start := float(_profile.get("near_fade_start", 0.)) if near_layer.y > 0. else 0.
 if light.get("valid",false):
  _append(light.origin,data,1.);_append(light.step,data,.2);_append(light.dimensions,data,near_fade_start)
 else:
  for i in 2:_append(Vector3.ZERO,data)
  _append(Vector3.ZERO,data,near_fade_start)
 effect.configure(data.to_byte_array(),size,noise.get_rid(),light_rid)
 var state:Dictionary=effect.snapshot()
 var ready:bool=state.ready and state.error.is_empty()
 if medium_state.is_valid():medium_state.call(ready,str(state.error))
 if ready:
  if _bound_generation!=int(state.rebuilds):
   RenderingServer.global_shader_parameter_set("gaf_mist_volume",effect.texture);_bound_generation=state.rebuilds
  RenderingServer.global_shader_parameter_set("gaf_mist_far",_camera.far)
  RenderingServer.global_shader_parameter_set("gaf_mist_near_entry",near_layer.x)
  RenderingServer.global_shader_parameter_set("gaf_mist_camera_position",_camera.global_position)
  RenderingServer.global_shader_parameter_set("gaf_mist_camera_direction",-_camera.global_basis.z)
  var projection:=_camera.get_camera_projection()
  RenderingServer.global_shader_parameter_set("gaf_mist_projection_scale",Vector2(projection.x.x,projection.y.y))
 _set_gate(ready);_sync_materials(ready)
func _sync_materials(active:bool):
 var current: Dictionary = {}
 if active and material_provider.is_valid():
  for m:ShaderMaterial in material_provider.call():
   if m==null:continue
   var key := m.get_instance_id()
   current[key] = true
   if not _bound_materials.has(key):_bound_materials[key]=weakref(m)
 for key in _bound_materials.keys():
  var m:ShaderMaterial=_bound_materials[key].get_ref()
  if m==null:_bound_materials.erase(key);continue
  var base:Shader=base_shader(m.shader)
  if base==null or not base.code.contains("GAF_SHARED_MIST"):
   _bound_materials.erase(key)
   continue
  var target:=base
  if current.has(key):
   if not _variants.has(base):
    var wrapped:=Shader.new();wrapped.code=base.code.replace("shader_type spatial;","shader_type spatial;\n#define GAF_SHARED_MIST");wrapped.set_meta("gaf_mist_base",base);_variants[base]=wrapped
   target=_variants[base]
  else:_bound_materials.erase(key)
  if m.shader!=target:m.shader=target
static func base_shader(shader:Shader)->Shader:
 return shader.get_meta("gaf_mist_base",shader) if shader!=null else null
func _set_gate(value:bool):
 if value==_gate:return
 _gate=value;RenderingServer.global_shader_parameter_set("gaf_mist_enabled",value)
func failure()->String:return "" if effect==null else str(effect.snapshot().error)
func _exit_tree():
 if effect==null:return
 effect.enabled=false;_sync_materials(false)
 if _camera!=null and is_instance_valid(_camera) and _camera.compositor!=null:
  var effects=_camera.compositor.compositor_effects.duplicate();effects.erase(effect);_camera.compositor.compositor_effects=effects
  if _camera.compositor==_owned_compositor:_camera.compositor=_previous_compositor
 if _owner!=null and _owner.get_ref()==self:
  RenderingServer.global_shader_parameter_set("gaf_mist_enabled",false)
  RenderingServer.global_shader_parameter_set("gaf_mist_volume",null);_owner=null
 RenderingServer.call_on_render_thread(effect.release_on_render_thread)

static func integral(origin:Vector3,end:Vector3,density:float,falloff:float,base:float,begin:float,count:int)->float:
 var distance:=origin.distance_to(end)
 if distance<=begin:return 0.
 var ds:float=(distance-begin)/count;var sum:=0.
 for i in count:
  var p:=origin.lerp(end,(begin+(i+.5)*ds)/distance)
  sum+=density*exp(clampf(-(p.y-base)*falloff,-16.,2.))*ds
 return sum
