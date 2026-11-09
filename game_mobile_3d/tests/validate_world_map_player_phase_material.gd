extends SceneTree
var failures=[];var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func settle():
 for i in 4:await process_frame
func loader_cases():
 var previous:=OS.get_environment("MD2_RESEARCH_ROOT");var root:=previous
 if root.is_empty():root="C:/Users/ADMIN/Desktop/MD2 Research"
 var fixture:=root.path_join("godot_lab/world_map_unified_showcase_v001/player_material_phases_v001/loader_fixtures_v001")
 for mode in ["good","missing_proof","corrupt_proof","missing_cb","corrupt_cb","corrupt_base"]:
  OS.set_environment("MD2_RESEARCH_ROOT",fixture.path_join(mode))
  var material=load("res://scripts/world_map_player_material.gd").new()
  check(material.phase_verified==(mode=="good"),"Loader verifies or rejects actual private fixture: "+mode)
  check(material.profile.is_empty()==(mode=="corrupt_base"),"Phase-proof failure preserves valid original Day profile: "+mode)
 if previous.is_empty():OS.unset_environment("MD2_RESEARCH_ROOT")
 else:OS.set_environment("MD2_RESEARCH_ROOT",previous)
func run():
 loader_cases()
 var w=load("res://scenes/WorldMap.tscn").instantiate();root.add_child(w);current_scene=w
 await create_timer(.8).timeout
 var look=w.look;var native:=RenderingServer.get_current_rendering_method()=="mobile"and RenderingServer.get_rendering_device()!=null
 check(look.has_method("set_player_phase_material"),"Independent captured-phase material control exists")
 if not look.has_method("set_player_phase_material"):
  print("PLAYER_PHASE_MATERIAL checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(1);return
 check(look.player_phase_material_enabled,"Verified phase material selected by default")
 check(look.player_material.phase_verified,"Nine-frame proof matches source scalars and textures")
 if native:
  var materials:Array=look._direct_actor_materials.filter(func(m):return m!=null)
  for hour in [0.,7.,10.,11.999,12.,12.001,16.5,18.5,22.]:
   w.showcase.hour=hour;w.showcase.apply_time();await settle()
   var verified:=0
   for m in materials:
    if m.get_meta("verified_valorie",false):
     verified+=1
     check(m.get_shader_parameter("recovered_roughness")and m.get_shader_parameter("recovered_self_light"),"Verified material terms follow captured shader at "+str(hour))
     check(m.get_shader_parameter("roughness_transform")==look.player_material.profile.roughness,"Recovered roughness scalars remain exact at "+str(hour))
     check(m.get_shader_parameter("self_light_scale")==look.player_material.profile.self_light,"Recovered self-light scalar remains exact at "+str(hour))
    else:check(not m.get_shader_parameter("recovered_roughness")and not m.get_shader_parameter("recovered_self_light"),"Attachments never receive Valorie parameters")
   check(verified==2,"Only the identified body/face receive verified parameters")
  w.showcase.set_hour(22.);await settle()
  look.set_player_phase_material(false);await settle()
  for m in materials:check(not m.get_shader_parameter("recovered_roughness")and not m.get_shader_parameter("recovered_self_light"),"OFF restores previous Night material scope")
  check(w.player_light.is_active(),"Original phase sky remains independent")
  look.set_player_phase_material(true);w.player_light.set_phase_sky(false);await settle()
  check(not w.player_light.is_active(),"Phase sky OFF remains respected with material proof ON")
  for m in materials:
   if m.get_meta("verified_valorie",false):check(m.get_shader_parameter("recovered_self_light"),"Verified material remains independent of sky comparison")
  w.player_light.set_phase_sky(true);await settle()
  var valid:bool=look.player_material.phase_verified;look.player_material.phase_verified=false;await settle()
  for m in materials:check(not m.get_shader_parameter("recovered_self_light"),"Missing phase proof restores Day-only scope")
  look.player_material.phase_verified=valid;await settle()
  look.set_player_material_review("neutral");await settle()
  for m in materials:check(not m.get_shader_parameter("recovered_roughness")and not m.get_shader_parameter("recovered_self_light"),"Neutral comparison stays neutral")
  look.set_player_material_review("combined");w.showcase.compare_baseline();await settle()
  for row in look.actor_materials:check(row[0].get_surface_override_material(row[1])==row[2],"Baseline restores original material")
 check(w.player.run_speed==7. and AudioServer.is_bus_mute(0),"Gameplay and muted audio preserved")
 print("PLAYER_PHASE_MATERIAL checks=",checks," failures=",JSON.stringify(failures));w.free();await process_frame;quit(0 if failures.is_empty()else 1)
