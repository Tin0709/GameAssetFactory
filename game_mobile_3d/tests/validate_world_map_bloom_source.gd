extends SceneTree
class FailingSource extends "res://scripts/world_map_bloom_source.gd":
 var fired:=false
 func _prepare_pass(rd:RenderingDevice,fragment:String,framebuffer:RID,uniforms:Array[RDUniform])->bool:
  if not fired and fragment.contains("// GAF_RECON_SOURCE_ORDER"):
   fired=true;_report("error","Injected optional source build failure");return false
  return super(rd,fragment,framebuffer,uniforms)
var failures=[]
var checks:=0
var w
func check(v:bool,label:String):
 checks+=1
 if not v:failures.append(label)
func settle():
 for i in 32:await process_frame
func active()->bool:return w.look._exposure_effect.snapshot().get("source_order_active",false)
func _initialize():call_deferred("run")
func run():
 if RenderingServer.get_rendering_device()==null or RenderingServer.get_current_rendering_method()!="mobile":
  print("Requires the private Mobile WorldMap with RenderingDevice");quit(2);return
 w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w);current_scene=w
 await create_timer(.8).timeout
 w.showcase.set_hour(22.);w.showcase.phase_finish.set_source_order(true);await settle();check(active(),"ON")
 w.showcase.set_source_bloom_shape(true);await settle();check(not active(),"six-scale exclusion")
 w.showcase.set_source_bloom_shape(false);await settle();check(active(),"shape OFF resumes")
 w.showcase.set_coherent_bloom(false);await settle();check(not active(),"noncoherent excludes")
 w.showcase.set_coherent_bloom(true);await settle();check(active(),"coherent resumes")
 w.look.set_local_exposure(false);await settle();check(w.look._exposure_effect==null,"F7 OFF")
 w.look.set_local_exposure(true);await settle();check(active(),"F7 resumes")
 for mode in ["previous","haze","lighting","combined"]:
  w.showcase.set_atmosphere_review(mode);await settle();check(active()==(mode=="combined"),"context "+mode)
 var phase=w.showcase.phase_finish
 w.process_mode=Node.PROCESS_MODE_DISABLED;phase.refresh();await settle()
 phase._native.enabled=false;await settle();check(not active(),"disabled native")
 phase._native.enabled=true;await settle();check(active(),"native resumed")
 phase.release();await settle();check(not active(),"native release")
 w.process_mode=Node.PROCESS_MODE_INHERIT;await settle();check(active(),"release recovery")
 phase.release()
 var previous=w.look._exposure_effect;var replacement=FailingSource.new();replacement.set_review_strength(w.showcase.LOCAL_EXPOSURE_STRENGTH)
 var chain=w.look._exposure_compositor.compositor_effects.duplicate();chain[chain.find(previous)]=replacement;w.look._exposure_compositor.compositor_effects=chain;w.look._exposure_effect=replacement
 previous.enabled=false;RenderingServer.call_on_render_thread(previous.release_on_render_thread)
 await settle();await settle()
 check(replacement.fired,"injected failure executed")
 check(replacement.failure().is_empty(),"optional failure cleared")
 check(not replacement._reference_blocked,"grade not poisoned")
 check(w.showcase.phase_finish.active,"phase owner retained")
 check(not active(),"failed source falls back")
 replacement.set_bloom_source_reference(phase._native,false,0.);phase.set_source_order(false);await settle();phase.set_source_order(true);await settle();check(active(),"retry recovers")
 var rows={"checks":checks,"failures":failures}
 var receipt=OS.get_environment("GAF_BLOOM_SOURCE_RESULT")
 if not receipt.is_empty():FileAccess.open(receipt,FileAccess.WRITE).store_string(JSON.stringify(rows))
 print("SOURCE_ORDER_CONTROLS ",JSON.stringify(rows));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
