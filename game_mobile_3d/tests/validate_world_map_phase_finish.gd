extends SceneTree
var failures=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 24:await process_frame
func run():
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w);current_scene=w
 await create_timer(.8).timeout
 check(w.showcase.get("phase_finish")!=null,"Existing main scene owns coherent phase finishing")
 if w.showcase.get("phase_finish")==null:
  print("PHASE_FINISH checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(1);return
 var f=w.showcase.phase_finish
 check(f.requested,"Improved phase finish is selected by default")
 check(is_equal_approx(f.phase_weight(12.),0.),"Noon anchor is preserved")
 for time in [0.,7.,16.5,18.5,22.]:check(is_equal_approx(f.phase_weight(time),1.),"Full atmospheric finishing outside Noon: "+str(time))
 check(f.phase_weight(10.)>0. and f.phase_weight(10.)<1.,"Smooth morning blend")
 check(f.phase_weight(14.)>0. and f.phase_weight(14.)<1.,"Smooth afternoon blend")
 var native:bool=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 check(f.available()==native,"Private finishing only available on supported renderer with verified data")
 check(not f.active,"Noon uses the unchanged original finish")
 if native:
  var sun:float=w.get_node("Sun").light_energy
  w.showcase.set_hour(22.);await settle()
  check(f.active,"Night uses coupled exposure and grade")
  check(f.last_error.is_empty(),"No GPU or ownership failure")
  check(w.get_node("WorldEnvironment").environment.tonemap_mode==Environment.TONE_MAPPER_LINEAR,"Final grade replaces engine curve without stacking")
  check(w.look._exposure_effect._review_strength==0.,"No duplicate bounded exposure at full reference weight")
  check(w.terrain_light.is_active()and w.player_light.is_active(),"Existing spatial light survives neutral final tone")
  w.showcase.set_hour(12.);await settle()
  check(not f.active,"Returning to Noon releases reference resources")
  check(is_equal_approx(w.get_node("Sun").light_energy,sun),"Gentler Noon sunlight unchanged")
  check(is_equal_approx(w.look._exposure_effect._review_strength,.12),"Noon bounded exposure restored")
  w.showcase.set_hour(7.);await settle();check(f.active,"Morning resumes")
  w.look.set_local_exposure(false);await settle();check(not f.active,"F7 OFF suspends finishing")
  w.look.set_local_exposure(true);await settle();check(f.active,"F7 ON resumes finishing")
  w.showcase.set_hdr_air(false);await settle();check(not f.active,"Packed fallback suspends finishing")
  w.showcase.set_hdr_air(true);await settle();check(f.active,"HDR resumes finishing")
  w.showcase.compare_baseline();await settle();check(not f.active,"B baseline suspends finishing")
  w.showcase.compare_baseline();await settle();check(f.active,"B Combined resumes finishing")
  f.set_requested(false);await settle();check(not f.active,"OFF restores existing phase treatment")
  check(is_equal_approx(w.look._exposure_effect._review_strength,.12),"OFF restores bounded exposure")
 check(w.player.run_speed==7.and AudioServer.is_bus_mute(0),"Movement and muted audio unchanged")
 print("PHASE_FINISH checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
