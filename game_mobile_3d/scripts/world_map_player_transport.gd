extends Node
## Original low-frequency actor illumination; not recovered Lumen or native SSS.
const SAMPLER=preload("res://scripts/world_map_actor_irradiance.gd")
const PATH="res://assets/graphics/world_map_actor_light_v001/field.res"
const NOON_BOUNCE_FULL_ANGLE := .04
const NOON_BOUNCE_END_ANGLE := .75
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
var _last_shade_sky := Vector3(-1., -1., -1.)
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
  var noon_weight := 0.
  if level.look._ground_bounce_requested:
   noon_weight = _noon_bounce_weight(sun.global_basis.z.normalized(), Vector3(d[0], d[1], d[2]))
  var key_strength := sun.light_energy * noon_weight
  var bounce_mix:float=level.showcase._lighting_scale(&"player_bounce")
  if bounce_mix>0. and noon_weight < 1. and level.look._ground_bounce_requested \
   and (level.look.player_local_light_enabled or level.look.player_reflection_enabled):
   var local:bool=local_phase_bounce.available() and local_phase_bounce.fade(p)>0.
   var bounce=local_phase_bounce if local else phase_bounce
   if bounce.available():
    var slots:Vector4=level.showcase.directional_air.sun_slots()
    var values:PackedVector3Array=bounce.sample(p,slots)
    if values.size()==18:
     bounce_sun=values
     var phase_strength := sun.light_energy * bounce_mix * slots.w * bounce.fade(p) * (1. - noon_weight)
     if key_strength > 0. and phase_strength > 0.:
      # Both fields share the same shader key. Interpolate their probe values
      # by energy so the combined incident light is continuous through Noon.
      bounce_sun = values.duplicate()
      var phase_fraction := phase_strength / (key_strength + phase_strength)
      for axis in bounce_sun.size():
       bounce_sun[axis] = _sun[axis].lerp(values[axis], phase_fraction)
     key_strength += phase_strength
     phase_bounce_active=true
  key = Vector3(c.r, c.g, c.b) * key_strength
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

static func _noon_bounce_weight(direction: Vector3, baked_direction: Vector3) -> float:
 # Chord length is stable at near-identical directions.
 var chord := direction.distance_to(baked_direction.normalized())
 return 1. - smoothstep(2. * sin(deg_to_rad(NOON_BOUNCE_FULL_ANGLE) * .5),
  2. * sin(deg_to_rad(NOON_BOUNCE_END_ANGLE) * .5), chord)

func _kai_ground_bounce(position: Vector3) -> Vector4:
 var review = level.showcase
 var light: OmniLight3D = review._player_light
 if (not position.is_finite() or not is_instance_valid(review._kai_skin) or not review._kai_skin.is_visible_in_tree()
  or level.look.stage != 2 or not level.look.player_adapter_enabled or not level.look.player_local_light_enabled
  or level.view_mode != "gameplay" or not review.source_terrain_active or not is_instance_valid(light)
  or not light.is_visible_in_tree() or light.light_energy <= 0. or light.omni_range <= 0.):
  return Vector4.ZERO
 var gain: float = review.kai_lantern_ground_return_weight()
 if gain <= 0.:
  return Vector4.ZERO
 var look = level.look
 var reflectance: PackedVector3Array = review._source_terrain_tiles.get_meta("surface_reflectance", PackedVector3Array())
 var field: Image = look.path_map_image
 if reflectance.size() != 5 or field == null:
  return Vector4.ZERO
 # Blend a patch of terrain around the feet so thin paths return some
 # light from their grassy edges as well as from the cell under Kai.
 var pixel: Vector2 = Vector2(position.x, position.z) - look.path_map_origin - Vector2(.5, .5)
 var corner := Vector2i(pixel.floor())
 var fraction := pixel - Vector2(corner)
 var x_weights := _ground_return_weights(fraction.x)
 var z_weights := _ground_return_weights(fraction.y)
 var nearby_boulders: Array = []
 for rock in review.basin_boulders:
  if rock.active and rock.ground_bounce_bounds.has_point(Vector2(position.x, position.z)):
   nearby_boulders.append(rock)
 var roadside_rock = review.playable_boulder
 if is_instance_valid(roadside_rock) and roadside_rock.active \
  and roadside_rock.ground_bounce_bounds.has_point(Vector2(position.x, position.z)):
  nearby_boulders.append(roadside_rock)
 var lamp_position := light.global_position
 var range_squared := light.omni_range * light.omni_range
 var incident := Vector3.ZERO
 var surface_height := 0.
 var surface_weight := 0.
 var bounds := Rect2i(Vector2i.ZERO, field.get_size())
 for z in 4:
  for x in 4:
   var cell := corner + Vector2i(x - 1, z - 1)
   if not bounds.has_point(cell):
    continue
   var info := field.get_pixelv(cell)
   var cell_weight := x_weights[x] * z_weights[z]
   var world_cell: Vector2 = look.path_map_origin + Vector2(cell) + Vector2(.5, .5)
   var remaining := 1.
   for rock in nearby_boulders:
    var surface: Vector2 = rock.ground_bounce_cells.get(Vector2i(world_cell.floor()), Vector2.ZERO)
    if surface.x <= 0.:
     continue
    var coverage := minf(surface.x, remaining)
    var sample := _ground_return_sample(rock.ground_bounce_reflectance, Vector3(world_cell.x, surface.y, world_cell.y),
     position.y, lamp_position, range_squared, cell_weight * coverage)
    incident += Vector3(sample.x, sample.y, sample.z)
    surface_height += surface.y * sample.w
    surface_weight += sample.w
    remaining -= coverage
   if info.a <= 0. or remaining <= 0.:
    continue
   var layer := 4 if info.b < .5 else (0 if info.b < 1.5 else 3)
   var sample := _ground_return_sample(reflectance[layer], Vector3(world_cell.x, info.g, world_cell.y),
    position.y, lamp_position, range_squared, cell_weight * remaining)
   incident += Vector3(sample.x, sample.y, sample.z)
   surface_height += info.g * sample.w
   surface_weight += sample.w
 if surface_weight <= .0001:
  return Vector4.ZERO
 var warm := light.light_color.srgb_to_linear()
 # Broad diffuse return. Scale with the existing lantern rather than adding a light.
 var diffuse := incident * Vector3(warm.r, warm.g, warm.b) * minf(light.light_energy * gain * 1.35, 2.)
 var luminance := diffuse.dot(Vector3(.2126, .7152, .0722))
 # The broad return mixes with neighboring surfaces and the cool night fill.
 diffuse = (Vector3.ONE * luminance).lerp(diffuse, .58)
 return Vector4(diffuse.x, diffuse.y, diffuse.z, surface_height / surface_weight)


static func _ground_return_sample(reflectance: Vector3, surface: Vector3, foot_height: float,
 lamp_position: Vector3, range_squared: float, coverage: float) -> Vector4:
 var distance_from_floor := foot_height - surface.y
 var support := smoothstep(-.65, -.18, distance_from_floor) * (1. - smoothstep(.28, 1.8, distance_from_floor))
 var weight := coverage * support
 var to_light := lamp_position - surface
 var distance_squared := to_light.length_squared()
 var radius_ratio := distance_squared / range_squared
 var falloff := pow(maxf(0., 1. - radius_ratio * radius_ratio) / (1. + radius_ratio), 2.)
 var cosine := clampf(to_light.y / maxf(sqrt(distance_squared), .001), 0., 1.)
 var source := reflectance * (weight * falloff * cosine)
 return Vector4(source.x, source.y, source.z, weight)

static func _ground_return_weights(fraction: float) -> Vector4:
 # Cubic B-spline over four cell centers. The weights sum to one and
 # meet smoothly at cell boundaries, without temporal lag when turning.
 var squared := fraction * fraction
 var cubed := squared * fraction
 var opposite := 1. - fraction
 return Vector4(opposite * opposite * opposite, 4. - 6. * squared + 3. * cubed,
  1. + 3. * fraction + 3. * squared - 3. * cubed, cubed) / 6.
func refresh_shade_sky(force: bool = false) -> void:
 var strength := Vector3.ZERO
 if _active and level.look.player_local_light_enabled:
  strength = Vector3(level.showcase.actor_shade_sky_weight(), level.showcase.actor_side_sky_weight(),
   level.showcase.actor_shade_sky_weight(&"kai_shade_sky"))
 if not force and _last_shade_sky == strength:
  return
 _last_shade_sky = strength
 for material: ShaderMaterial in level.look._direct_actor_materials:
  if material != null and material.get_meta("verified_valorie", false):
   material.set_shader_parameter("actor_shade_sky", strength.x)
   material.set_shader_parameter("actor_side_sky", strength.y)
  elif material != null and material.get_meta("kai_matte_lighting", false):
   material.set_shader_parameter("actor_shade_sky", strength.z)

func _process(_delta:float)->void:refresh()
