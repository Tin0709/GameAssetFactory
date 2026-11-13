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
 var old_root:=OS.get_environment("MD2_RESEARCH_ROOT")
 var research:=old_root if not old_root.is_empty()else"C:/Users/ADMIN/Desktop/MD2 Research"
 var script=load("res://scripts/world_map_bloom_response.gd")
 var original:=FileAccess.get_file_as_bytes(research.path_join(script.FILE))
 var fallbacks=[]
 for kind in ["valid","missing","corrupt"]:
  var fixture:=research.path_join("godot_lab/world_map_unified_showcase_v001/multiscale_bloom_v001/loader_fixtures/"+kind)
  var path:=fixture.path_join(script.FILE);DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  if kind!="missing":
   var bytes:=original.duplicate()
   if kind=="corrupt":bytes.append(32)
   FileAccess.open(path,FileAccess.WRITE).store_buffer(bytes)
  OS.set_environment("MD2_RESEARCH_ROOT",fixture)
  var profile=script.new()
  check(profile.available()==(kind=="valid"),"Actual "+kind+" private profile loading")
  if kind!="valid":
   check(profile.sample(0.)==1.,kind+" profile yields conservative unity")
   fallbacks.append(profile)
 OS.set_environment("MD2_RESEARCH_ROOT",old_root)
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
  for hour in [0.,4.,6.5,7.,10.,12.,18.5,20.25,22.]:
   s.set_hour(hour);await settle()
   var e=w.look._exposure_effect
   check(e!=null,"Existing exposure survives at "+str(hour))
   var night_gain:float=1.7 if hour in [0.,22.] else (1.35 if hour in [4.,20.25] else 1.)
   # 20:15 is midway into moonlight and one quarter into the smooth twilight fade-out.
   var twilight_gain:float=1.2953125 if hour==20.25 else 1.
   var wanted=.16*s.bloom_response.sample(s.reference_hour())*night_gain*twilight_gain
   check(absf(e._parameters.decode_float(16)-wanted)<.00000008,"Measured phase and overlapping evening bloom reach the GPU at "+str(hour))
  s.set_lighting_scale(&"night_soft_bloom",0.);await settle()
  check(is_equal_approx(w.look._exposure_effect._parameters.decode_float(16),.16*s.bloom_response.sample(0.)),"Soft night bloom at 0% restores prior midnight weight")
  s.set_lighting_scale(&"night_soft_bloom",1.);await settle()
  s.set_night_reference_atmosphere(false);await settle()
  check(absf(w.look._exposure_effect._parameters.decode_float(16)-.16*s.bloom_response.sample(22.)*1.7)<.00000008,"Night reference comparison uses mirrored phase with the same soft bloom setting")
  s.set_night_reference_atmosphere(true);await settle()
  s.set_measured_bloom_response(false);await settle()
  check(is_equal_approx(w.look._exposure_effect._parameters.decode_float(16),.16),"OFF restores previous fixed response")
  s.set_measured_bloom_response(true);await settle()
  s.set_coupled_bloom(false);await settle()
  check(w.look._exposure_effect._parameters.decode_float(16)==0.,"Bloom OFF remains fully OFF")
  s.set_coupled_bloom(true);await settle()
  check(w.look._exposure_effect._parameters.decode_float(16)>.16,"Selected Night response resumes")
  for profile in fallbacks:
   s.bloom_response=profile;s.set_measured_bloom_response(true);await settle()
   check(is_equal_approx(w.look._exposure_effect._parameters.decode_float(16),.16),"Invalid source proof preserves actual previous GPU uniform")
  var e=w.look._exposure_effect;e.set_air_bloom_response(NAN)
  check(is_equal_approx(e._parameters.decode_float(16),.16),"Nonfinite direct scalar input safely restores unity")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Gameplay and muted audio retained")
 print("BLOOM_RESPONSE checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
