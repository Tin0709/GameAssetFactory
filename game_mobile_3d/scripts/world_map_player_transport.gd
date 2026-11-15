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
var source_field=preload("res://scripts/world_map_actor_source_field.gd").new()
var phase_bounce=preload("res://scripts/world_map_actor_bounce.gd").new()
var local_phase_bounce=preload("res://scripts/world_map_actor_bounce.gd").new()
var phase_bounce_active:=false
var source_field_enabled:=false
var source_field_active:=false
var _source_key:Array=[]
var _last_shade_sky := Vector2(-1., -1.)
func set_source_field(value:bool)->void:
 source_field_enabled=value;refresh(true)
func set_phase_sky(value:bool)->void:
 phase_sky=value;refresh(true)
func setup(world:Node3D)->void:
 level=world;process_priority=30
 if RenderingServer.get_current_rendering_method()!="mobile"or RenderingServer.get_rendering_device()==null or not level.showcase.private_primary:return
 if ResourceLoader.exists(PATH):
  cache=load(PATH)
  cache_ready=cache.get_meta("scope","")=="Original GAF actor incident field; not MD2 radiance" and cache.get_meta("source_runtime_sha256","")==FileAccess.get_sha256(level.map_layout_path) and context_matches() and field.initialize(cache)
  if cache_ready:source_field.prepare(field)
  if cache_ready:phase_bounce.setup(level,PATH,level.showcase._lighting_scale(&"player_bounce")>0.)
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
 var phase_context:bool=phase_sky and level.look._private_player_material_scope()and level.showcase.forest_spatial_sky_context()and level.look.player_material.available()
 var day_context:bool=level.showcase.is_day_anchor()and level.look.player_effects_available()
 if not(day_context or phase_context)or not level.look.player_adapter_enabled or level.look.player_material_review!="combined":return false
 return true
func is_active()->bool:return _active
func refresh(force:bool=false)->void:
 var started:=Time.get_ticks_usec()
 var active:=available();var p:Vector3=level.presentation.player_position()
 var use_source:bool=active and source_field_enabled and source_field.available()and phase_sky and level.showcase.captured_sky_response and level.showcase.sky_response.available()and level.showcase.forest_spatial_sky_context()and not level.showcase.is_day_anchor()
 var source_hour:float=level.showcase.reference_hour() if use_source else 12.
 var source_mean:Vector3=level.showcase.sky_response.sample(source_hour)if use_source else Vector3.ONE
 var next_source_key:Array=[use_source,source_hour,source_mean]
 # Eligibility can change without a position/input change. Rebuild on re-entry,
 # including when an optional source was disabled while transport was inactive.
 if active and (not _active or p!=_position or force or next_source_key!=_source_key):
  _position=p;_sky.clear();_sun.clear()
  var corrected:=PackedVector3Array();var correction_ok:=true
  for height in [.25,1.,1.8]:
   var q:Dictionary=field.sample(p+Vector3.UP*height)
   if not q.valid:active=false;break
   _sky.append_array(q.sky);_sun.append_array(q.sun)
   if use_source:
    var response:Dictionary=source_field.sample(p+Vector3.UP*height,source_hour,source_mean)
    if response.valid:corrected.append_array(response.sky)
    else:correction_ok=false
  source_field_active=active and use_source and correction_ok and corrected.size()==18
  if source_field_active:_sky=corrected
 elif active and _sky.size()!=18:active=false
 source_field_active=source_field_active and active and use_source
 _source_key=next_source_key
 _active=active
 var env:Environment=level.get_node("WorldEnvironment").environment
 var original:Array=cache.get_meta("ambient_srgb",[])if cache_ready else []
 var tint:=Vector3.ONE;var scale:=0.;var key:=Vector3.ZERO
 var bounce_sun:=_sun
 phase_bounce_active=false
 if active:
  var a:=Color(original[0],original[1],original[2]).srgb_to_linear();var b:=env.ambient_light_color.srgb_to_linear()
  tint=Vector3(b.r/a.r,b.g/a.g,b.b/a.b);scale=env.ambient_light_energy/float(cache.get_meta("ambient_energy"))
  scale*=level.showcase.player_sky_fill_mix_scale()
  var sun:DirectionalLight3D=level.get_node("Sun");var c:=sun.light_color.srgb_to_linear();var d:Array=cache.get_meta("sun_direction")
  if level.look._ground_bounce_requested and sun.global_basis.z.normalized().dot(Vector3(d[0],d[1],d[2]))>cos(deg_to_rad(.1)):key=Vector3(c.r,c.g,c.b)*sun.light_energy
  var bounce_mix:float=level.showcase._lighting_scale(&"player_bounce")
  if bounce_mix>0. and key==Vector3.ZERO and level.look._ground_bounce_requested \
   and (level.look.player_local_light_enabled or level.look.player_reflection_enabled):
   var local:bool=local_phase_bounce.available() and local_phase_bounce.fade(p)>0.
   var bounce=local_phase_bounce if local else phase_bounce
   if bounce.available():
    var slots:Vector4=level.showcase.directional_air.sun_slots()
    var values:PackedVector3Array=bounce.sample(p,slots)
    if values.size()==18:
     bounce_sun=values
     key=Vector3(c.r,c.g,c.b)*(sun.light_energy*bounce_mix*slots.w*bounce.fade(p))
     phase_bounce_active=true
 var skin_verified:bool=level.look.player_effects_available()
 var sun_shoulder:float=level.showcase.player_sun_shoulder_weight()
 var sun_specular:float=level.showcase.player_sun_specular_weight()
 var canopy_color:float=level.showcase.player_canopy_color_weight() if active and level.look.player_local_light_enabled else 0.
 var view_fill_chroma: float = level.showcase.actor_view_fill_chroma_weight() if active and level.look.player_local_light_enabled else 0.
 var twilight_view_fill: float = level.showcase.actor_twilight_view_fill_weight() if active and level.look.player_local_light_enabled else 0.
 var ground_bounce := _kai_ground_bounce(p)
 refresh_shade_sky(force)
 var bind_key:Array=[active,p,level.look.player_local_light_enabled,level.look.player_reflection_enabled,level.look.player_skin_enabled,tint,scale,key,skin_verified,_source_key,source_field_active,phase_bounce_active,bounce_sun if phase_bounce_active else null,sun_shoulder,sun_specular,canopy_color,view_fill_chroma,twilight_view_fill,ground_bounce]
 if not force and bind_key==_last_bind_key:
  update_usec=Time.get_ticks_usec()-started;return
 _last_bind_key=bind_key
 for m:ShaderMaterial in level.look._direct_actor_materials:
  if m==null:continue
  var diffuse:bool=active and level.look.player_local_light_enabled
  m.set_shader_parameter("player_local_light",diffuse)
  m.set_shader_parameter("player_rough_reflection",active and level.look.player_reflection_enabled)
  var verified_valorie:bool=m.get_meta("verified_valorie",false)
  var kai_matte: bool = m.get_meta("kai_matte_lighting", false)
  var daylight_receiver: bool = verified_valorie or kai_matte
  if kai_matte:
   m.set_shader_parameter("kai_ground_bounce", ground_bounce)
  m.set_shader_parameter("player_sun_shoulder",sun_shoulder if daylight_receiver else 0.)
  m.set_shader_parameter("player_sun_specular_normalization",sun_specular if verified_valorie else 0.)
  m.set_shader_parameter("actor_canopy_color_mix",canopy_color if verified_valorie else 0.)
  m.set_shader_parameter("actor_view_fill_chroma", view_fill_chroma if verified_valorie else 0.)
  m.set_shader_parameter("actor_twilight_view_fill", twilight_view_fill if verified_valorie else 0.)
  m.set_shader_parameter("skin_wrap_enabled",active and skin_verified and level.look.player_skin_enabled and m.get_meta("has_profile_mask",false))
  if active:
   m.set_shader_parameter("player_probe_sky",_sky);m.set_shader_parameter("player_probe_sun",bounce_sun)
   m.set_shader_parameter("player_probe_base",p.y);m.set_shader_parameter("player_probe_tint",tint)
   m.set_shader_parameter("player_probe_scale",scale);m.set_shader_parameter("player_probe_key",key)
 update_usec=Time.get_ticks_usec()-started

func _kai_ground_bounce(position: Vector3) -> Vector4:
 var review = level.showcase
 var light: OmniLight3D = review._player_light
 if (not position.is_finite() or not is_instance_valid(review._kai_skin) or not review._kai_skin.is_visible_in_tree()
  or level.look.stage != 2 or not level.look.player_adapter_enabled or not level.look.player_local_light_enabled
  or level.view_mode != "gameplay" or not review.source_terrain_active or not is_instance_valid(light)
  or not light.is_visible_in_tree() or light.light_energy <= 0. or light.omni_range <= 0.):
  return Vector4.ZERO
 var gain: float = review._night_grass_weight() * review._lighting_scale(&"kai_ground_bounce")
 if gain <= 0.:
  return Vector4.ZERO
 var look = level.look
 var reflectance: PackedVector3Array = review._source_terrain_tiles.get_meta("surface_reflectance", PackedVector3Array())
 var field: Image = look.path_map_image
 if reflectance.size() != 5 or field == null:
  return Vector4.ZERO
 # Interpolate the terrain's existing top cells across their centers.
 var pixel: Vector2 = Vector2(position.x, position.z) - look.path_map_origin - Vector2(.5, .5)
 var corner := Vector2i(pixel.floor())
 var fraction := pixel - Vector2(corner)
 var incident := Vector3.ZERO
 var surface_height := 0.
 var surface_weight := 0.
 var bounds := Rect2i(Vector2i.ZERO, field.get_size())
 for y in 2:
  for x in 2:
   var cell := corner + Vector2i(x, y)
   if not bounds.has_point(cell):
    continue
   var info := field.get_pixelv(cell)
   if info.a <= 0.:
    continue
   var distance_from_floor := position.y - info.g
   var support := smoothstep(-.65, -.18, distance_from_floor) * (1. - smoothstep(.28, 1.8, distance_from_floor))
   var weight := (fraction.x if x == 1 else 1. - fraction.x) * (fraction.y if y == 1 else 1. - fraction.y) * support
   var world_cell: Vector2 = look.path_map_origin + Vector2(cell) + Vector2(.5, .5)
   var to_light := light.global_position - Vector3(world_cell.x, info.g, world_cell.y)
   var distance_squared := to_light.length_squared()
   var radius_ratio := distance_squared / (light.omni_range * light.omni_range)
   var falloff := pow(maxf(0., 1. - radius_ratio * radius_ratio) / (1. + radius_ratio), 2.)
   var cosine := clampf(to_light.y / maxf(sqrt(distance_squared), .001), 0., 1.)
   var layer := 4 if info.b < .5 else (0 if info.b < 1.5 else 3)
   incident += reflectance[layer] * (weight * falloff * cosine)
   surface_height += info.g * weight
   surface_weight += weight
 if surface_weight <= .0001:
  return Vector4.ZERO
 var warm := light.light_color.srgb_to_linear()
 # Broad diffuse return. Scale with the existing lantern rather than adding a light.
 var diffuse := incident * Vector3(warm.r, warm.g, warm.b) * minf(light.light_energy * gain * 1.35, 2.)
 var luminance := diffuse.dot(Vector3(.2126, .7152, .0722))
 # The broad return mixes with neighboring surfaces and the cool night fill.
 diffuse = (Vector3.ONE * luminance).lerp(diffuse, .58)
 return Vector4(diffuse.x, diffuse.y, diffuse.z, surface_height / surface_weight)

func refresh_shade_sky(force: bool = false) -> void:
 var strength := Vector2.ZERO
 if _active and level.look.player_local_light_enabled:
  strength = Vector2(level.showcase.actor_shade_sky_weight(), level.showcase.actor_side_sky_weight())
 if not force and _last_shade_sky == strength:
  return
 _last_shade_sky = strength
 for material: ShaderMaterial in level.look._direct_actor_materials:
  if material != null and material.get_meta("verified_valorie", false):
   material.set_shader_parameter("actor_shade_sky", strength.x)
   material.set_shader_parameter("actor_side_sky", strength.y)

func _process(_delta:float)->void:refresh()
