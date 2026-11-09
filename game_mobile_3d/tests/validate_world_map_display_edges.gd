extends SceneTree
var checks:=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 32:await process_frame
func run():
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 await settle()
 var f=w.showcase.phase_finish
 check(f.has_method("set_edge_softening"),"Existing phase finish exposes reversible display-edge comparison")
 if not f.has_method("set_edge_softening"):
  print("DISPLAY_EDGES checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(1);return
 check(not f.edge_softening,"Unapproved filter stays OFF by default")
 f.set_edge_softening(true)
 check(f.edge_softening,"Selection retained")
 var native=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 w.showcase.set_hour(22.);await settle()
 if native:
  check(f.active,"Night phase finish active")
  var s=w.look._exposure_effect.snapshot()
  check(s.get("edge_active",false),"Edge filter executes after owned color transfer")
  check(s.get("edge_bytes",0)==1280*720*4,"One display RGB10 target")
  check(s.get("edge_error","").is_empty(),"Shader valid")
  var n=s.rebuilds
  await settle();check(w.look._exposure_effect.snapshot().rebuilds==n,"Stable phase never reallocates each frame")
  f.set_edge_softening(false);await settle();s=w.look._exposure_effect.snapshot()
  check(not s.get("edge_active",false)and s.get("edge_bytes",0)==0,"OFF releases target and original APPLY restored")
  f.set_edge_softening(true);await settle()
  w.showcase.set_hour(12.);await settle();s=w.look._exposure_effect.snapshot()
  check(not f.active and not s.get("edge_active",false)and s.get("edge_bytes",0)==0,"Noon anchor has no filter/allocation")
  w.showcase.set_hour(18.5);await settle();check(w.look._exposure_effect.snapshot().get("edge_active",false),"Evening resumes selected filter")
  f.set_requested(false);await settle();check(not w.look._exposure_effect.snapshot().get("edge_active",false),"Owner OFF releases edge filter")
  f.set_requested(true);await settle()
  w.showcase.compare_baseline();await settle();check(not w.look._exposure_effect.snapshot().get("edge_active",false),"Baseline excludes edge experiment")
  w.showcase.compare_baseline();await settle()
  w.showcase.set_hdr_air(false);await settle();check(not w.look._exposure_effect.snapshot().get("edge_active",false),"Packed fallback excludes edge experiment")
 else:check(not f.active,"Unsupported renderer remains inert")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Gameplay speed and muted audio preserved")
 print("DISPLAY_EDGES checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
