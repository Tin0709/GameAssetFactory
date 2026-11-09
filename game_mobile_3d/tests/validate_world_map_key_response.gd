extends SceneTree
var checks:=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 24:await process_frame
func radiance(w):
 var light=w.get_node("Sun");var c:Color=light.light_color.srgb_to_linear()*light.light_energy
 return Vector3(c.r,c.g,c.b)
func run():
 var loader=load("res://scripts/world_map_key_response.gd")
 var prior:=OS.get_environment("MD2_RESEARCH_ROOT")
 var research:=prior if not prior.is_empty()else "C:/Users/ADMIN/Desktop/MD2 Research"
 var source=JSON.parse_string(FileAccess.get_file_as_string(research.path_join(loader.FILE)))
 var curve=loader.new()
 for row in source.anchors:
  var a:Array=row.rgb_ratio
  check(curve.sample(row.hour).distance_to(Vector3(a[0],a[1],a[2]))<.000001,"Recovered anchor "+str(row.hour))
 var a:Array=source.anchors[1].rgb_ratio;var b:Array=source.anchors[2].rgb_ratio
 check(curve.sample(5.75).distance_to(Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),.15625))<.000001,"Original fractional interpolation")
 check(curve.sample(18.5)==curve.sample(5.5)and curve.sample(-5.5)==curve.sample(18.5),"Original mirror/wrap")
 check(curve.sample(NAN)==Vector3.ONE and curve.sample(INF)==Vector3.ONE,"Invalid clock neutral")
 var fixture:=research.path_join("godot_lab/world_map_unified_showcase_v001/player_direct_balance_v001/loader_fixtures/"+str(Time.get_ticks_usec()))
 OS.set_environment("MD2_RESEARCH_ROOT",fixture);check(not loader.new().available(),"Missing file neutral")
 var file:String=fixture.path_join(loader.FILE);DirAccess.make_dir_recursive_absolute(file.get_base_dir());FileAccess.open(file,FileAccess.WRITE).store_string("{}")
 check(not loader.new().available(),"Corrupt file rejected")
 FileAccess.open(file,FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(research.path_join(loader.FILE)))
 check(loader.new().available(),"Exact proof accepted")
 OS.set_environment("MD2_RESEARCH_ROOT",prior)
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w);await settle()
 check(w.showcase.has_method("set_captured_key_response"),"Source direct-key phase comparison exists")
 if not failures.is_empty():
  w.free();print("KEY_RESPONSE checks=",checks," failures=",JSON.stringify(failures));quit(1);return
 var native=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 if native:
  check(w.showcase.key_response.available(),"Private source curve verified")
  w.showcase.set_captured_key_response(false);w.showcase.set_hour(12.);await settle()
  var noon=radiance(w);var soft_scale=w.showcase.noon_direct_scale(12.)
  w.showcase.set_captured_key_response(true);await settle()
  check(radiance(w)==noon,"Noon exact bypass")
  for hour in [0.,5.5,6.5,7.,8.,9.,10.,12.,16.5,18.5,22.,23.99]:
   w.showcase.set_captured_key_response(false);w.showcase.set_hour(hour);await settle()
   var before=radiance(w);var direction=w.get_node("Sun").rotation;var env=w.get_node("WorldEnvironment").environment
   var ambient=[env.ambient_light_color,env.ambient_light_energy];var point=w.showcase._player_light.light_energy
   w.showcase.set_captured_key_response(true);await settle()
   var expected=noon/soft_scale*w.showcase.key_response.sample(hour)*w.showcase.noon_direct_scale(hour)
   check(radiance(w).distance_to(expected)<.000005,"Measured relative key at "+str(hour))
   check(w.get_node("Sun").rotation==direction and [env.ambient_light_color,env.ambient_light_energy]==ambient and w.showcase._player_light.light_energy==point,"Other lighting preserved "+str(hour))
   w.showcase.set_captured_key_response(false);await settle();check(radiance(w)==before,"OFF restores prior palette "+str(hour))
  w.showcase.set_hour(22.);w.showcase.set_captured_key_response(true);await settle()
  w.showcase.key_response.verified=false;w.showcase.set_captured_key_response(true);await settle();var fallback=radiance(w)
  w.showcase.set_captured_key_response(false);await settle();check(radiance(w)==fallback,"Missing proof falls back")
  w.showcase.key_response.verified=true
  w.showcase.set_captured_key_response(true);w.showcase.compare_baseline();await settle()
  check(not w.showcase.key_response_active,"Baseline no source phase response")
  w.showcase.compare_baseline();await settle();check(w.showcase.key_response_active,"Combined restores response")
  w.showcase.set_atmosphere_review("haze");await settle();check(not w.showcase.key_response_active,"Haze-only does not alter key")
  w.showcase.set_atmosphere_review("combined");await settle();check(w.showcase.key_response_active,"Lighting scope resumes")
  w.showcase.set_gentle_noon(false);await settle();var ungentle=radiance(w)
  w.showcase.set_gentle_noon(true);await settle();check(radiance(w)==ungentle,"Gentle Noon toggle does not retune Night")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Approved gameplay/audio preserved")
 w.free();await process_frame
 print("KEY_RESPONSE checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty()else 1)
