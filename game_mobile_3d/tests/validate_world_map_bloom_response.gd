extends SceneTree
var checks:=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 28:await process_frame
func run():
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 await settle()
 var s=w.showcase
 check(s.has_method("set_measured_bloom_response"),"Existing showcase exposes measured bloom response")
 if not s.has_method("set_measured_bloom_response"):
  print("BLOOM_RESPONSE checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(1);return
 check(s.measured_bloom_response,"Measured response selected by default")
 check(s.bloom_response.available(),"Verified private gain profile available")
 check(is_equal_approx(s.bloom_response.sample(12.),1.),"Noon is exactly source-relative unity")
 check(is_equal_approx(s.bloom_response.sample(NAN),1.),"Invalid clock falls back to unity")
 check(s.bloom_response.sample(0.)>1.79,"Dark captured anchor has recovered stronger response")
 check(s.bloom_response.sample(6.5)<.46,"Captured low-response anchor retained")
 check(is_equal_approx(s.bloom_response.sample(18.5),s.bloom_response.sample(5.5)),"Explicit original mirrored evening policy")
 check(w.find_child("MeasuredBloomResponse",true,false)!=null,"L menu comparison exists")
 var native=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 if native:
  for hour in [0.,6.5,7.,10.,12.,18.5,22.]:
   s.set_hour(hour);await settle()
   var e=w.look._exposure_effect
   check(e!=null,"Existing exposure survives at "+str(hour))
   var wanted=.16*s.bloom_response.sample(hour)
   check(absf(e._parameters.decode_float(16)-wanted)<.00000004,"Actual existing air uniform follows observed relative gain at "+str(hour))
  s.set_measured_bloom_response(false);await settle()
  check(is_equal_approx(w.look._exposure_effect._parameters.decode_float(16),.16),"OFF restores previous fixed response")
  s.set_measured_bloom_response(true);await settle()
  s.set_coupled_bloom(false);await settle()
  check(w.look._exposure_effect._parameters.decode_float(16)==0.,"Bloom OFF remains fully OFF")
  s.set_coupled_bloom(true);await settle()
  check(w.look._exposure_effect._parameters.decode_float(16)>.16,"Selected Night response resumes")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Gameplay and muted audio retained")
 print("BLOOM_RESPONSE checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
