extends SceneTree
class ControlFailure extends "res://scripts/world_map_multiscale_bloom.gd":
 func _shape_control(_rd:RenderingDevice,_weight:float)->RID:return RID()
var checks:=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 40:await process_frame
func snapshot(w):return w.look._exposure_effect.snapshot()if w.look._exposure_effect!=null else {}
func run():
 var original_root=OS.get_environment("MD2_RESEARCH_ROOT")
 var fixture="user://shape_fixture_%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()]
 DirAccess.make_dir_recursive_absolute(fixture)
 OS.set_environment("MD2_RESEARCH_ROOT",ProjectSettings.globalize_path(fixture))
 check(not load("res://scripts/world_map_bloom_shapes.gd").new().available(),"Missing pinned profile unavailable")
 var path=fixture.path_join(load("res://scripts/world_map_bloom_shapes.gd").FILE)
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 FileAccess.open(path,FileAccess.WRITE).store_string("{}")
 check(not load("res://scripts/world_map_bloom_shapes.gd").new().available(),"Corrupt pinned profile unavailable")
 OS.set_environment("MD2_RESEARCH_ROOT",original_root)
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 await settle()
 check(w.showcase.has_method("set_source_bloom_shape"),"Existing main exposes reversible six-radius study")
 if not w.showcase.has_method("set_source_bloom_shape"):
  print("BLOOM_SHAPE checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(1);return
 check(not w.showcase.source_bloom_shape,"Unreviewed shape defaults OFF")
 check(w.find_child("SourceBloomShape",true,false)!=null,"Existing L menu shape control")
 var native=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 w.showcase.set_source_bloom_shape(true);await settle()
 check(not snapshot(w).get("shape_active",false),"Noon keeps approved original shape")
 if native:
  var before=snapshot(w)
  w.showcase.set_hour(22.);await settle();await settle()
  var s=snapshot(w)
  check(s.get("shape_active",false),"Six-radius kernel executes in Night main scene")
  check(s.get("shape_error","").is_empty(),"Kernel compilation and ownership healthy")
  check(s.get("shape_levels",0)==6,"Six actual spatial levels")
  check(s.get("shape_bytes",0)>0,"Allocation measured")
  check(w.showcase.phase_finish.active and w.look.local_exposure_active(),"Phase grade and F7 remain owned")
  check(absf(s.get("air_bloom_weight",0.)-.16*w.showcase.bloom_response.sample(22.))<.00000004,"Shape does not duplicate intensity")
  var n=s.rebuilds
  await settle();check(snapshot(w).rebuilds==n,"Stable scene does not reallocate")
  w.showcase.set_source_bloom_shape(false);await settle();s=snapshot(w)
  check(not s.get("shape_active",false)and s.get("shape_bytes",0)==0,"OFF releases extra shape and restores old field")
  w.showcase.set_source_bloom_shape(true);await settle()
  w.showcase.set_hour(12.);await settle();s=snapshot(w)
  check(not s.get("shape_active",false)and s.get("shape_bytes",0)==0,"Noon release has no shape texture/pass")
  w.showcase.set_hour(10.);await settle();s=snapshot(w)
  check(s.get("shape_active",false)and s.get("shape_weight",0.)>0. and s.get("shape_weight",1.)<1.,"Original fade blends toward Noon rather than switches")
  w.showcase.phase_finish.set_requested(false);await settle();check(not snapshot(w).get("shape_active",false),"Standalone/previous grade cannot run unvalidated shape")
  w.showcase.phase_finish.set_requested(true);await settle();await settle()
  var original_size=root.size
  root.size=Vector2i(961,541);await settle();await settle()
  s=snapshot(w)
  check(s.get("shape_active",false)and s.get("render_size",[0,0])[0]==961,"Odd resolution rebuilds shape against actual 3D buffer")
  check(s.get("shape_error","").is_empty()and w.look.local_exposure_active(),"Resize retains healthy optional graph and F7")
  root.size=original_size;await settle();await settle()
  # Replace the current compositor effect to exercise optional late allocation failure.
  var old=w.look._exposure_effect;var compositor=w.look._exposure_compositor
  w.showcase.phase_finish.set_requested(false);await settle()
  var broken=ControlFailure.new();broken.set_review_strength(.12);broken.set_air_bloom(true)
  var chain:Array[CompositorEffect]=compositor.compositor_effects.duplicate()
  var index=chain.find(old);chain[index]=broken;compositor.compositor_effects=chain;w.look._exposure_effect=broken
  old.enabled=false;RenderingServer.call_on_render_thread(old.release_on_render_thread)
  w.showcase.phase_finish.set_requested(true);w.showcase.set_source_bloom_shape(true);await settle();await settle()
  check(w.look.local_exposure_active()and broken.failure().is_empty(),"Shape fade allocation failure preserves existing F7")
  check(not broken.snapshot().get("shape_active",false),"Shape fade allocation failure rolls back optional shape")
  check(w.showcase.phase_finish.active,"Shape failure preserves owned phase grade")
  w.look.set_local_exposure(false);await settle();check(not w.look.local_exposure_active(),"F7 OFF still releases everything")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Approved controller/audio unchanged")
 print("BLOOM_SHAPE checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
