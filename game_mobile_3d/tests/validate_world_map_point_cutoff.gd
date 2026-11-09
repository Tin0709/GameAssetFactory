extends SceneTree
var checks:=0
var failures=[]
func check(value,label):
 checks+=1
 if not value:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 32:await process_frame
func radius(w):return w.showcase.point_kernel_state.w
func run():
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 await settle()
 check(w.showcase.has_method("set_source_point_cutoff"),"Existing main exposes recovered point radial cutoff")
 check(w.showcase.source_point_cutoff,"Supported point radial cutoff defaults ON")
 check(not w.showcase.source_warm_light,"No-signal warm air trial stays OFF")
 var native=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 if native:
  check(radius(w)==0.,"Noon source disabled")
  w.showcase.set_hour(22.);await settle()
  check(is_equal_approx(radius(w),8.),"Actual main camera receives native8m correction")
  var energy=w.showcase._player_light.light_energy
  w.showcase.set_source_point_cutoff(false);await settle();check(radius(w)==0.,"OFF restores prior quartic window")
  w.showcase.set_source_point_cutoff(true);await settle();check(is_equal_approx(radius(w),8.),"ON restores source window")
  check(w.showcase._player_light.light_energy==energy,"No energy retune")
  w.showcase.set_noninverse_player_light(false);await settle();check(radius(w)==0.,"Old inverse-square mode does not receive new cutoff")
  w.showcase.set_noninverse_player_light(true);await settle()
  w.showcase.point_response.kernel_verified=false;await settle();check(radius(w)==0.,"Missing proof falls back")
  w.showcase.point_response.kernel_verified=true;await settle();check(is_equal_approx(radius(w),8.),"Valid proof restores kernel")
  w.look.set_direct_clouds(false);await settle();check(radius(w)==0.,"F3 built-in receiver fallback suspends kernel")
  w.look.set_direct_clouds(true);await settle();check(is_equal_approx(radius(w),8.),"F3 restored custom receivers resume kernel")
  var extra=OmniLight3D.new();w.add_child(extra);await settle();check(radius(w)==0.,"Additional local light suspends single-owned-light correction")
  extra.light_cull_mask=2;await settle();check(is_equal_approx(radius(w),8.),"Non-receiver light does not affect owned layer")
  extra.free();await settle()
  w.showcase.compare_baseline();await settle();check(radius(w)==0.,"B original unchanged")
  w.showcase.compare_baseline();await settle();check(is_equal_approx(radius(w),8.),"B combined restores source window")
  w.showcase.set_hour(12.);await settle();check(radius(w)==0.,"Noon returns to no correction")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Approved gameplay/audio preserved")
 w.free();await process_frame
 # Owner reset is exercised by actual multi-instance controller and renderer probes.
 print("POINT_CUTOFF checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty()else 1)
