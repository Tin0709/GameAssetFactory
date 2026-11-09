extends SceneTree
var checks:=0
var failures=[]
func check(value,label):
 checks+=1
 if not value:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 32:await process_frame
func run():
 var loader=load("res://scripts/world_map_point_response.gd")
 var research:=OS.get_environment("MD2_RESEARCH_ROOT")
 var original_root:=research if not research.is_empty()else "C:/Users/ADMIN/Desktop/MD2 Research"
 var fixture:=original_root.path_join("godot_lab/world_map_unified_showcase_v001/player_soft_source_v001/loader_fixtures/"+str(Time.get_ticks_usec()))
 # Real file absence/corruption, not a mocked verified flag.
 for file in [loader.FILE,loader.KERNEL_FILE]:
  var path:String=fixture.path_join(file);DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  FileAccess.open(path,FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(original_root.path_join(file)))
 OS.set_environment("MD2_RESEARCH_ROOT",fixture)
 var missing=loader.new();check(missing.kernel_available()and not missing.soft_available(),"Absent soft profile keeps radial but disables specular")
 var soft_path:String=fixture.path_join(loader.SOFT_FILE);DirAccess.make_dir_recursive_absolute(soft_path.get_base_dir())
 FileAccess.open(soft_path,FileAccess.WRITE).store_string("{}")
 check(not loader.new().soft_available(),"Corrupt soft profile rejected")
 FileAccess.open(soft_path,FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(original_root.path_join(loader.SOFT_FILE)))
 check(loader.new().soft_available(),"Pinned profile accepted")
 OS.set_environment("MD2_RESEARCH_ROOT",research)
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w)
 await settle()
 check(w.showcase.has_method("set_player_soft_source"),"Player finite-source comparison exists")
 if not failures.is_empty():
  w.free();print("SOFT_SOURCE checks=",checks," failures=",JSON.stringify(failures));quit(1);return
 var native=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 if native:
  check(w.showcase.point_response.soft_available(),"Pinned private soft-source proof available")
  check(w.showcase.point_soft_state==Vector2.ZERO,"Noon bypass")
  w.showcase.set_hour(22.);w.showcase.set_player_soft_source(true);await settle()
  check(is_equal_approx(w.showcase.point_soft_state.x,6.),"Recorded source size converted cm to m")
  var energy=w.showcase._player_light.light_energy
  w.showcase.set_player_soft_source(false);await settle();check(w.showcase.point_soft_state==Vector2.ZERO,"OFF neutral")
  w.showcase.set_player_soft_source(true);await settle()
  w.showcase.point_response.soft_verified=false;await settle();check(w.showcase.point_soft_state==Vector2.ZERO,"Missing proof neutral")
  w.showcase.point_response.soft_verified=true;await settle();check(w.showcase.point_soft_state.x>0.,"Proof restore")
  w.showcase.set_source_point_cutoff(false);await settle();check(w.showcase.point_soft_state==Vector2.ZERO,"Unsupported radial mode neutral")
  w.showcase.set_source_point_cutoff(true);await settle()
  var extra=OmniLight3D.new();w.add_child(extra);await settle();check(w.showcase.point_soft_state==Vector2.ZERO,"Other local light neutral")
  extra.free();await settle()
  w.look.set_direct_clouds(false);await settle();check(w.showcase.point_soft_state==Vector2.ZERO,"Fallback receivers neutral")
  w.look.set_direct_clouds(true);await settle()
  w.showcase.compare_baseline();await settle();check(w.showcase.point_soft_state==Vector2.ZERO,"Original baseline neutral")
  w.showcase.compare_baseline();await settle();check(w.showcase.point_soft_state.x>0.,"Combined restored")
  check(w.showcase._player_light.light_energy==energy,"No energy retune")
  w.showcase.set_hour(12.);await settle();check(w.showcase.point_soft_state==Vector2.ZERO,"Noon return neutral")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Gameplay/audio unchanged")
 w.free();await process_frame
 print("SOFT_SOURCE checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty()else 1)
