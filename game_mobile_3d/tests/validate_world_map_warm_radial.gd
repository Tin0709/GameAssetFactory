extends SceneTree
var checks:=0
var failures=[]
func check(value,label):
 checks+=1
 if not value:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 40:await process_frame
func run():
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 await settle()
 check(w.showcase.has_method("set_source_warm_light"),"Existing main exposes recovered radial air source")
 if not w.showcase.has_method("set_source_warm_light"):
  print("WARM_RADIAL checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(1);return
 check(not w.showcase.source_warm_light,"Unvalidated warm transport stays OFF")
 w.showcase.set_source_warm_light(true)
 var native=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 if native:
  w.showcase.set_hour(22.);await settle()
  var mist=w.showcase.mist;var n=mist.effect.snapshot().rebuilds
  check(mist.effect.snapshot().get("point_kernel",false),"Actual field receives recovered radial mode")
  w.showcase.set_source_warm_light(false);await settle()
  check(not mist.effect.snapshot().get("point_kernel",true),"OFF restores previous mask")
  w.showcase.set_source_warm_light(true);await settle()
  check(mist.effect.snapshot().get("point_kernel",false),"ON restores source mask")
  check(mist.effect.snapshot().rebuilds==n,"Toggles do not rebuild volume")
  w.showcase.set_noninverse_player_light(false);await settle()
  check(not mist.effect.snapshot().get("point_kernel",true),"Legacy inverse mode cannot retain source air response")
  w.showcase.set_noninverse_player_light(true);await settle()
  check(mist.effect.snapshot().get("point_kernel",false),"Recovered main mode resumes air response")
  w.showcase.set_hour(12.);await settle()
  check(w.showcase._player_light.light_energy==0. and not w.showcase._player_light.visible,"Noon warm source remains zero")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Controller/audio unchanged")
 print("WARM_RADIAL checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
