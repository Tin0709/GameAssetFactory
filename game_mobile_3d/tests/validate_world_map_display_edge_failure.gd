extends SceneTree
class FailedFinish extends "res://scripts/world_map_phase_finish_effect.gd":
 var reject_edges:=true
 func _prepare_pass(rd:RenderingDevice,fragment:String,framebuffer:RID,uniforms:Array[RDUniform])->bool:
  if reject_edges and fragment==EDGES.FRAGMENT:
   _report("error","Injected optional edge shader failure");return false
  return super._prepare_pass(rd,fragment,framebuffer,uniforms)
var failures=[]
var checks:=0
func check(ok,label):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 32:await process_frame
func run():
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 await settle()
 var f=w.showcase.phase_finish;f.set_edge_softening(true)
 w.showcase.set_hour(22.)
 var warmup_bad=false
 for i in 40:
  await process_frame
  var e=w.look._exposure_effect
  if e!=null and e.get("_render_edge")==true and not e.get("_reference_enabled"):warmup_bad=true
 check(not warmup_bad,"No edge target/quantization while the owned final transfer is disabled")
 check(f.active,"Valid owned finish ready")
 f.set_requested(false);await settle()
 var old=w.look._exposure_effect;var compositor=w.look._exposure_compositor
 var broken=FailedFinish.new();broken.set_review_strength(.12);broken.set_air_bloom(true)
 var chain:Array[CompositorEffect]=compositor.compositor_effects.duplicate()
 var index=chain.find(old);check(index>=0,"Locate owned existing effect")
 chain[index]=broken;compositor.compositor_effects=chain;w.look._exposure_effect=broken
 old.enabled=false;RenderingServer.call_on_render_thread(old.release_on_render_thread)
 f.set_requested(true);await settle();await settle()
 check(w.look.local_exposure_active(),"Optional edge failure preserves existing F7 local exposure")
 check(w.look._exposure_effect==broken and broken.failure().is_empty(),"Fallback clears optional error without losing owner")
 check(not broken.snapshot().get("edge_active",false),"Failed optional edges inactive")
 check(not f.active,"Failed reference bridge yields engine finish")
 print("DISPLAY_EDGE_FAILURE checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
