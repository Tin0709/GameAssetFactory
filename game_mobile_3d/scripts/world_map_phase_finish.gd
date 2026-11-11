extends Node
## Owns an original phase bridge, never light/materials or source assets.
const REFERENCE=preload("res://scenes/dev/actions_stuff_research/overworld_fidelity_v001/graphics_review_v001/local_exposure_v001/local_exposure_effect.gd")
const SOURCE_REFERENCE=preload("res://scripts/world_map_source_reference.gd")
const PROFILE="godot_lab/world_map_unified_showcase_v001/native_exposure_transfer_v001/parameters_v002.private.json"
const SHA="c82d5489028813cdd1a2061d845fabca43789112e2a96e67dfe8eba80f8c71a3"
var showcase:Node
var requested:=true
var active:=false
var edge_softening:=false
var source_order:=false
var source_order_toggle:CheckButton
func set_source_order(value:bool)->void:
 source_order=value;refresh()
func set_edge_softening(value:bool)->void:
 edge_softening=value;refresh()
var last_error:=""
var toggle:CheckButton
var source_toggle:CheckButton
var edge_toggle:CheckButton
var _profile_path:=""
var _verified:=false
var _native:CompositorEffect
var _effect:CompositorEffect
var _compositor:Compositor
var _environment:Environment
var _saved:Dictionary={}
var _saved_strength:=.12
var _grade_owned:=false
var _saved_grade:=false
static func phase_weight(time:float)->float:
 if not is_finite(time):return 0.
 var h:=fposmod(time,24.)
 return 1.-smoothstep(7.,12.,h)if h<=12. else smoothstep(12.,16.5,h)
func setup(value:Node)->void:
 showcase=value;process_priority=25;_saved_strength=showcase.LOCAL_EXPOSURE_STRENGTH
 if not OS.has_feature("editor"):return
 var root:=OS.get_environment("MD2_RESEARCH_ROOT")
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 _profile_path=root.path_join(PROFILE)
 _verified=FileAccess.file_exists(_profile_path)and FileAccess.get_sha256(_profile_path)==SHA
func available()->bool:
 if not _verified or showcase==null or showcase.level==null or not showcase.unavailable_reason.is_empty():return false
 var effect=showcase.level.look._exposure_effect
 var compositor:Compositor=showcase.level.look._exposure_compositor
 if compositor!=null:
  for item in compositor.compositor_effects:
   if item is REFERENCE and item!=_native:return false
 return effect!=null and effect.has_method("configure_finish")and effect.get("reference_available")==true and effect.failure().is_empty()and str(effect.snapshot().get("reference_failure","")).is_empty()and RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
func owns_grade()->bool:return _grade_owned
func set_requested(value:bool)->void:
 if value:last_error=""
 requested=value;refresh()
func restore_environment()->void:
 if _environment!=null:
  for key in _saved:
   _environment.set(key,_saved[key])
   if showcase._forest_expected.has(key):showcase._forest_expected[key]=_saved[key]
 _environment=null;_saved.clear();active=false
func release()->void:
 restore_environment()
 if _effect!=null:
  if _effect.has_method("set_bloom_source_reference"):_effect.set_bloom_source_reference(null,false,0.)
  _effect.set_reference_grade(false);_effect.prepare_reference_grade(false);_effect.configure_finish(false);_effect.set_display_edges(false)
  _effect.set_review_strength(_saved_strength*showcase.local_exposure_mix_scale())
 if _compositor!=null and _native!=null:
  var keep:Array[CompositorEffect]=[]
  for effect in _compositor.compositor_effects:
   if effect!=_native:keep.append(effect)
  _compositor.compositor_effects=keep
 if _native!=null:
  var previous=_native;previous.enabled=false;RenderingServer.call_on_render_thread(previous.release_on_render_thread)
 _native=null;_effect=null;_compositor=null
 if _grade_owned:
  _grade_owned=false;showcase.grade_review.set_requested(_saved_grade)
  if source_toggle!=null:source_toggle.set_pressed_no_signal(_saved_grade)
func _fail(message:String)->void:
 last_error=message;requested=false;release()
 if toggle!=null:toggle.set_pressed_no_signal(false)
func refresh()->void:
 if showcase==null or showcase.level==null:return
 var level=showcase.level;var effect=level.look._exposure_effect
 var weight:=phase_weight(showcase.hour)
 var env:Environment=level.get_node("WorldEnvironment").environment
 var palette=env.adjustment_color_correction
 var compatible:bool=palette is Texture3D and palette.get_width()==32 and palette.get_height()==32 and palette.get_depth()==32
 var wanted:bool=requested and weight>0. and compatible and available()and showcase.forest_active()and showcase.atmosphere_review=="combined"and showcase.coupled_bloom and not env.glow_enabled and level.look.day_finish_active()and level.look.local_exposure_active()and level.get_viewport().use_hdr_2d and level.get_viewport().screen_space_aa==Viewport.SCREEN_SPACE_AA_DISABLED
 var compositor:Compositor=level.look._exposure_compositor
 if _effect!=null and(not wanted or effect!=_effect or compositor!=_compositor):release()
 if source_toggle!=null:source_toggle.disabled=_grade_owned or not showcase.grade_review.available()
 if not wanted:return
 if _native==null:
  if FileAccess.get_sha256(_profile_path)!=SHA:_fail("Private phase-finishing profile changed");return
  _native=SOURCE_REFERENCE.new()
  if not _native.configure_external(_profile_path):_fail(_native.snapshot().error);return
  _native.set_strength(0.)
  _effect=effect;_compositor=compositor
  _saved_grade=showcase.grade_review.requested;showcase.grade_review.set_requested(false);_grade_owned=true
  var chain:Array[CompositorEffect]=[]
  for item in compositor.compositor_effects:
   if item==effect:chain.append(_native)
   chain.append(item)
  if not _native in chain:_fail("Main exposure compositor ownership changed");return
  compositor.compositor_effects=chain
 if _environment==null:
  if not effect.configure_finish(true,env,weight):_fail("Unsupported original finish; previous appearance restored");return
 effect.set_display_edges(edge_softening);effect.set_reference_hour(showcase.reference_hour());effect.prepare_reference_grade(true)
 if effect.has_method("set_bloom_source_reference"):
  var chain:=compositor.compositor_effects
  var adjacent:=chain.find(effect)>0 and chain[chain.find(effect)-1]==_native
  effect.set_bloom_source_reference(_native,source_order and adjacent,weight)
 var state:Dictionary=effect.snapshot();var native_state:Dictionary=_native.snapshot()
 var error:String=str(state.get("error",""))+str(state.get("reference_failure",""))+str(native_state.get("error",""))
 if not error.is_empty():_fail(error);return
 if not state.get("finish_ready",false)or not state.get("reference_ready",false)or native_state.frames==0:return
 if _environment==null:
  _environment=env
  for key in ["tonemap_mode","tonemap_exposure","adjustment_enabled"]:_saved[key]=env.get(key)
 var gain_scale:float=showcase.local_exposure_mix_scale()
 var finish_scale:float=showcase.reference_finish_mix_scale()
 _native.set_strength(weight*gain_scale);effect.set_review_strength(_saved_strength*(1.-weight)*gain_scale)
 effect.set_finish_weight(weight*finish_scale);effect.set_reference_grade(true)
 env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.;env.adjustment_enabled=false
 for key in ["tonemap_exposure","adjustment_enabled"]:
  if showcase._forest_expected.has(key):showcase._forest_expected[key]=env.get(key)
 active=true
func _process(_delta:float)->void:
 refresh()
 if toggle!=null:toggle.set_pressed_no_signal(requested)
 if edge_toggle!=null:
  edge_toggle.set_pressed_no_signal(edge_softening);edge_toggle.disabled=not available()
 if source_order_toggle!=null:
  source_order_toggle.set_pressed_no_signal(source_order)
  source_order_toggle.disabled=not available()or not showcase.coherent_bloom or showcase.source_bloom_shape
func _exit_tree()->void:release()
