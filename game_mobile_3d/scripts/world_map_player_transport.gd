extends Node
## Original low-frequency actor illumination; not recovered Lumen or native SSS.
const SAMPLER=preload("res://scripts/world_map_actor_irradiance.gd")
const PATH="res://assets/graphics/world_map_actor_light_v001/field.res"
var level:Node3D
var field=SAMPLER.new()
var cache:Resource
var cache_ready:=false
var _active:=false
var _position:=Vector3.INF
var _sky:=PackedVector3Array()
var _sun:=PackedVector3Array()
var update_usec:=0
var _last_bind_key:Array=[]
var phase_sky:=true
func set_phase_sky(value:bool)->void:
 phase_sky=value;refresh(true)
func setup(world:Node3D)->void:
 level=world;process_priority=30
 if RenderingServer.get_current_rendering_method()!="mobile"or RenderingServer.get_rendering_device()==null or not level.showcase.private_primary:return
 if ResourceLoader.exists(PATH):
  cache=load(PATH)
  cache_ready=cache.get_meta("scope","")=="Original GAF actor incident field; not MD2 radiance" and cache.get_meta("source_runtime_sha256","")==FileAccess.get_sha256(level.DATA) and context_matches() and field.initialize(cache)
 refresh(true)
func context_matches()->bool:
 if cache==null or level.get("terrain_light")==null or not level.terrain_light.installed:return false
 # Compare against the independently validated terrain recipe. Matching map
 # bytes alone cannot establish colors, sky normalization or sun orientation.
 for key in ["ambient_srgb","ambient_energy","sun_direction","material_fingerprints","surface_recipe_sha256","ambient_recipe_identity"]:
  if not cache.has_meta(key)or cache.get_meta(key)!=level.terrain_light.cache.get_meta(key,null):return false
 return true
func available()->bool:
 if not cache_ready or not context_matches()or not level.terrain_light.available():return false
 # The original sky basis is source-independent and may follow the same
 # attributed phase sky as terrain. Native Day bounce rays remain angle-gated.
 var phase_context:bool=phase_sky and level.showcase.forest_spatial_sky_context()and level.look.player_material.available()
 if not(level.look.player_effects_available()or phase_context)or not level.look.player_adapter_enabled or level.look.player_material_review!="combined":return false
 return true
func is_active()->bool:return _active
func refresh(force:bool=false)->void:
 var started:=Time.get_ticks_usec()
 var active:=available();var p:Vector3=level.presentation.player_position()
 if active and (p!=_position or force):
  _position=p;_sky.clear();_sun.clear()
  for height in [.25,1.,1.8]:
   var q:Dictionary=field.sample(p+Vector3.UP*height)
   if not q.valid:active=false;break
   _sky.append_array(q.sky);_sun.append_array(q.sun)
 elif active and _sky.size()!=18:active=false
 _active=active
 var env:Environment=level.get_node("WorldEnvironment").environment
 var original:Array=cache.get_meta("ambient_srgb",[])if cache_ready else []
 var tint:=Vector3.ONE;var scale:=0.;var key:=Vector3.ZERO
 if active:
  var a:=Color(original[0],original[1],original[2]).srgb_to_linear();var b:=env.ambient_light_color.srgb_to_linear()
  tint=Vector3(b.r/a.r,b.g/a.g,b.b/a.b);scale=env.ambient_light_energy/float(cache.get_meta("ambient_energy"))
  var sun:DirectionalLight3D=level.get_node("Sun");var c:=sun.light_color.srgb_to_linear();var d:Array=cache.get_meta("sun_direction")
  if level.look._ground_bounce_requested and sun.global_basis.z.normalized().dot(Vector3(d[0],d[1],d[2]))>cos(deg_to_rad(.1)):key=Vector3(c.r,c.g,c.b)*sun.light_energy
 var skin_verified:bool=level.look.player_effects_available()
 var bind_key:Array=[active,p,level.look.player_local_light_enabled,level.look.player_reflection_enabled,level.look.player_skin_enabled,tint,scale,key,skin_verified]
 if not force and bind_key==_last_bind_key:
  update_usec=Time.get_ticks_usec()-started;return
 _last_bind_key=bind_key
 for m:ShaderMaterial in level.look._direct_actor_materials:
  if m==null:continue
  var diffuse:bool=active and level.look.player_local_light_enabled
  m.set_shader_parameter("player_local_light",diffuse)
  m.set_shader_parameter("player_rough_reflection",active and level.look.player_reflection_enabled)
  m.set_shader_parameter("skin_wrap_enabled",active and skin_verified and level.look.player_skin_enabled and m.get_meta("has_profile_mask",false))
  if active:
   m.set_shader_parameter("player_probe_sky",_sky);m.set_shader_parameter("player_probe_sun",_sun)
   m.set_shader_parameter("player_probe_base",p.y);m.set_shader_parameter("player_probe_tint",tint)
   m.set_shader_parameter("player_probe_scale",scale);m.set_shader_parameter("player_probe_key",key)
 update_usec=Time.get_ticks_usec()-started
func _process(_delta:float)->void:refresh()
