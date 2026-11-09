extends Node
## Owns only the optional phase final-transfer comparison, never material lighting.
var showcase:Node
var requested:=false
var _effect:CompositorEffect
var _environment:Environment
var _saved:Dictionary={}
var _vignette_visible:=false
func setup(value:Node)->void:
 showcase=value;process_priority=20
func available()->bool:
 if showcase==null or showcase.level==null:return false
 var e=showcase.level.look._exposure_effect
 return e!=null and e.get("reference_available")==true and str(e.snapshot().get("reference_failure","")).is_empty()
func active()->bool:return _environment!=null
func _phase_owned()->bool:
 return showcase!=null and showcase.get("phase_finish")!=null and showcase.phase_finish.owns_grade()
func set_requested(value:bool)->void:
 requested=value;refresh()
func release(disable_effect:bool=true)->void:
 if disable_effect and _effect!=null and not _phase_owned():_effect.set_reference_grade(false)
 if _environment!=null:
  for key in _saved:
   _environment.set(key,_saved[key])
   if showcase._forest_expected.has(key):showcase._forest_expected[key]=_saved[key]
  if showcase._vignette!=null:showcase._vignette.visible=_vignette_visible
 _environment=null;_saved.clear()
func refresh()->void:
 if showcase==null or showcase.level==null:return
 if _phase_owned():return
 var effect=showcase.level.look._exposure_effect
 var wanted:bool=requested and available()and showcase.forest_active()and showcase.level.get_viewport().use_hdr_2d
 if _effect!=effect:release();_effect=effect
 if effect!=null and effect.has_method("set_reference_grade"):
  effect.set_reference_hour(showcase.hour);effect.prepare_reference_grade(wanted)
 var state:Dictionary=effect.snapshot()if effect!=null else {}
 if not wanted or not state.get("reference_ready",false)or state.get("color_format",0)!=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT or not str(state.get("error","")).is_empty():
  release();return
 var env:Environment=showcase.level.get_node("WorldEnvironment").environment
 if _environment!=null and _environment!=env:release(false)
 if _environment==null:
  _environment=env
  for key in ["tonemap_mode","tonemap_exposure","adjustment_enabled"]:_saved[key]=env.get(key)
  _vignette_visible=showcase._vignette!=null and showcase._vignette.visible
 effect.set_reference_grade(true)
 env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.;env.adjustment_enabled=false
 for key in ["tonemap_exposure","adjustment_enabled"]:
  if showcase._forest_expected.has(key):showcase._forest_expected[key]=env.get(key)
 if showcase._vignette!=null:showcase._vignette.hide()
func _process(_delta:float)->void:refresh()
func _exit_tree()->void:release()
