extends SceneTree
## Exercise the real existing scene and button signals, including native cleanup.
var failures:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok and not failures.has(message):failures.append(message);push_error(message)
func ticks(count:int)->void:
 for i in count:await physics_frame
 await process_frame
func bodies(group:Node3D)->Array:
 var result:Array=[]
 for zombie in group.zombies:result.append_array(zombie.ragdoll.bodies.values())
 return result
func released(parts:Array,message:String)->void:
 var gone:=true
 for part in parts:gone=gone and not is_instance_valid(part)
 check(gone,message)
func run():
 var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab)
 lab.player.scripted_input=true
 var group=lab.zombie_combat
 check(group.living_count()==20,"Performance lab starts with exactly 20 living zombies")
 check(group.has_method("spawn_batch"),"Performance lab supports an exact adjustable batch")
 if not group.has_method("spawn_batch"):lab.free();quit(1);return
 var ui=lab.performance_controls
 check(ui!=null and ui.selected_count==20,"Count selector opens at 20")
 check(lab.find_child("ExistingAssetLightingEvaluation",true,false)==null,"Blocks, trees, flowers and their props colliders are removed")
 check(lab.grass_field.get_node("ThirtyByThirtyBlocks").multimesh.instance_count==900 and lab.grass_field.instance_count==1317,"The 30x30 terrain and mixed grass remain intact")
 check(lab.player.walk_speed==2.7 and absf(lab.player.run_speed-7.5465)<.00001,"Approved player movement speeds remain unchanged")
 var previous:=bodies(group)
 ui.select_count(0);ui.spawn_button.pressed.emit()
 check(group.living_count()==0 and group.zombies.is_empty(),"Spawn 0 removes the entire group for a clean baseline")
 released(previous,"Spawn 0 frees all dormant native bones")
 ui.select_count(1);ui.spawn_button.pressed.emit()
 check(group.living_count()==1,"Spawn selector supports one actor")
 previous=bodies(group)
 ui.select_count(50);ui.spawn_button.pressed.emit()
 check(group.living_count()==50 and group.zombies.size()==50,"Spawn 50 creates every actor in the same batch")
 released(previous,"Replacing a batch releases its old native graph")
 var nearest:=INF;var separation:=INF
 for a in group.zombies:
  check(absf(a.position.x)<=14.001 and absf(a.position.z)<=14.001,"Spawn stays inside the existing terrain")
  nearest=minf(nearest,a.position.distance_to(lab.player.position))
  check(a.chasing and a.persistent_chase and a.visual.source_library!=null,"Every spawned actor uses the existing active chase/source animation")
  for b in group.zombies:
   if a!=b:separation=minf(separation,a.position.distance_to(b.position))
 check(separation>.60 and nearest>=2.,"Same-frame spawns neither overlap capsules nor the player")
 await ticks(3)
 check(group.zombies[0].visual.walk_clock>0.,"Living actors actually advance the existing walk pose")
 previous=bodies(group)
 ui.kill_button.pressed.emit()
 check(group.living_count()==0,"Kill All kills all 50 immediately")
 check(group.active_ragdolls()==4 and group.zombies.size()==4,"Kill All keeps at most four native ragdolls")
 var active_parts:=0
 for part in previous:
  if is_instance_valid(part):active_parts+=1
 check(active_parts==28,"Bulk death promptly releases excess native bodies, retaining 28")
 var kills:int=group.kills
 ui.kill_button.pressed.emit()
 check(group.kills==kills and group.active_ragdolls()==4,"Repeated Kill All cannot trigger duplicate deaths")
 await ticks(80)
 check(group.zombies.is_empty() and group.active_ragdolls()==0 and group.kills==50,"All 50 kills settle and retire once after the short corpse lifetime")
 released(previous,"Bulk cleanup frees every physical bone")
 # Also exercise same-frame kill before pose sampling is warmed.
 ui.select_count(50);ui.spawn_button.pressed.emit();previous=bodies(group)
 ui.kill_button.pressed.emit()
 check(group.living_count()==0 and group.zombies.size()==4,"Immediate spawn then Kill All is bounded before pose warmup")
 await ticks(3)
 check(group.active_ragdolls()==4,"Pending corpse handoff starts cleanly on the existing physics clock")
 ui.select_count(13);ui.spawn_button.pressed.emit()
 released(previous,"Spawn during death retires old running and dormant native resources")
 check(group.living_count()==13,"Slider supports arbitrary integer batches")
 previous=bodies(group);ui.spawn_button.pressed.emit()
 released(previous,"Repeated Spawn replaces rather than accumulates actors")
 check(group.living_count()==13 and get_nodes_in_group("zombies").size()==13,"Actor registry/group contains exactly the replacement batch")
 lab.rifle_auto_aim.target=group.zombies[0]
 lab.player.visual.auto_aim_target=group.zombies[0]
 previous=bodies(group);lab.reset_player()
 check(group.living_count()==13 and group.active_ragdolls()==0,"R restores the last applied count")
 released(previous,"R releases all preceding native graphs")
 check(lab.rifle_auto_aim.target==null and lab.player.visual.auto_aim_target==null and lab.rifle_fire.active_projectiles()==0,"Reset clears stale targets and projectiles")
 group.spawn_batch(-1);check(group.living_count()==0,"Negative request is bounded to zero")
 group.spawn_batch(100);check(group.living_count()==50,"Request above 50 is bounded to 50")
 previous=bodies(group);group.spawn_batch(0);released(previous,"Leaving the maximum batch releases all native resources")
 # At an edge the ring must remain on the map and clear of the player.
 lab.player.position=Vector3(14.,0.,14.);group.spawn_batch(50)
 var valid:=true
 for z in group.zombies:valid=valid and absf(z.position.x)<=14.001 and absf(z.position.z)<=14.001 and z.position.distance_to(lab.player.position)>=2.
 check(valid,"Maximum batch stays valid when the player is near a map corner")
 lab.free();await process_frame
 var legacy=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();legacy.performance_test_enabled=false;root.add_child(legacy)
 check(legacy.zombie_combat.living_count()==4 and legacy.performance_controls==null and legacy.find_child("ExistingAssetLightingEvaluation",true,false)!=null,"Opt-out retains the original four-zombie lighting review fixture")
 legacy.free()
 print("PERFORMANCE_LAB_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"minimum_spawn_separation_m":separation,"nearest_spawn_m":nearest}));quit(0 if failures.is_empty() else 1)
