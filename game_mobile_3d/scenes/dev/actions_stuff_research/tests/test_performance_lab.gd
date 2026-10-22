extends SceneTree
## Real scene/button regression: full100m grass, additive batches and native cleanup.
var failures:Array[String]=[]
var checks:=0
var fps:=60
var metrics:Dictionary={}
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
func spacing(group:Node3D,player:Node3D)->void:
 var nearest:=INF;var separation:=INF;var valid:=true;var names:Dictionary={}
 for a in group.zombies:
  if a.is_dead:continue
  valid=valid and absf(a.position.x)<=49.001 and absf(a.position.z)<=49.001
  nearest=minf(nearest,a.position.distance_to(player.position))
  check(not names.has(a.name),"Added zombies have unique names");names[a.name]=true
  check(a.chasing and a.persistent_chase and a.visual.source_library!=null,"Added zombies retain existing chase/source animation")
  for b in group.zombies:
   if a!=b and not b.is_dead:separation=minf(separation,a.position.distance_to(b.position))
 check(valid and nearest>=1.999,"All added zombies remain inside100m bounds and clear of player")
 check(separation>=.7499,"Added living capsules do not overlap existing or newly spawned actors")
 metrics["minimum_separation_m"]=separation;metrics["nearest_spawn_m"]=nearest
func run():
 if OS.get_cmdline_user_args().has("30"):fps=30
 Engine.physics_ticks_per_second=fps
 var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab)
 lab.player.scripted_input=true
 var group=lab.zombie_combat;var ui=lab.performance_controls;var field=lab.grass_field
 check(group.living_count()==20 and ui.selected_count==20,"Default remains20 living zombies")
 check(group.has_method("add_batch") and ui.spawn_button.text=="Spawn +20","Real UI exposes additive spawning")
 check(lab.find_child("ExistingAssetLightingEvaluation",true,false)==null,"Unrelated blocks/tree/flower props remain absent")
 check(lab.grass_field_blocks==100 and field.terrain.multimesh.instance_count==10000,"Existing lab now has100x100 unit terrain blocks")
 check(lab.grass_vegetation_enabled and field.cells.size()==10000 and field.instance_count>=10000,"Every terrain cell has enabled grass")
 check(field.meshes.size()==8 and field.short_count>4000 and field.tall_count>4000 and field.batch_count==392,"All eight existing variants are regionally instanced across the expanded map")
 check(field.interaction.size==196 and field.interaction.extent==104. and absf(field.interaction.cell-34./64.)<.001,"Interaction covers100m with original physical cell density")
 for material in field.materials:check(material.get_shader_parameter("field_extent")==104.,"GPU grass sampling uses expanded contact extent")
 check(lab.get_node("FlatGround").get_child(0).shape.size==Vector3(100,.4,100),"Floor collision expands with terrain")
 var walls:=true
 for wall in lab.get_node("FieldBoundary").get_children():walls=walls and absf(maxf(absf(wall.position.x),absf(wall.position.z))-50.2)<.001
 check(walls,"All four boundaries move to new map edges")
 check(lab.camera.far>=400.,"Whole-map overview remains inside camera far range")
 lab.grass_overview=true;lab._update_camera()
 check(absf(lab.camera.size-43.*100./30.)<.001,"Overview scales to show the full expanded map")
 lab.grass_overview=false;lab._update_camera()
 check(absf(lab.player.walk_speed-2.16)<.00001 and absf(lab.player.run_speed-6.0372)<.00001 and lab.camera_size==14.5,"Approved movement and normal camera remain unchanged")
 var state=field.interaction
 state.advance(0.,Vector3(45,0,-45),Vector3.ZERO)
 for i in 12:state.advance(1./60.,Vector3(45,0,-45),Vector3.ZERO)
 check(state.sample_at(Vector2(45.35,-44.65)).length()>.15,"Grass responds to player contact beyond old30m map")
 field.reset();check(state.sample_at(Vector2(45.35,-44.65))==Vector2.ZERO,"Reset clears distant contact histories")
 var original:=group.zombies.duplicate();var old_parts:=bodies(group)
 lab._fire_key_held=true;lab._sync_rifle_controls()
 lab.rifle_auto_aim.target=original[0];lab.player.visual.auto_aim_target=original[0]
 ui.select_count(20);ui.spawn_button.pressed.emit();ui.spawn_button.pressed.emit()
 check(group.living_count()==60 and group.zombies.size()==60,"Two Spawn+20 clicks add20 to40 then60, with no total50cap")
 var preserved:=true
 for z in original:preserved=preserved and is_instance_valid(z) and group.zombies.has(z)
 for part in old_parts:preserved=preserved and is_instance_valid(part)
 check(preserved,"Append preserves every original actor and native body")
 check(lab.rifle_auto_aim.target==original[0] and lab.player.visual.auto_aim_target==original[0] and lab._fire_key_held,"Spawn retains active aim and held trigger")
 spacing(group,lab.player)
 ui.select_count(0);ui.spawn_button.pressed.emit()
 check(group.living_count()==60 and group.zombies.has(original[0]),"Spawn+0 leaves all existing actors intact")
 lab._fire_key_held=false;lab._sync_rifle_controls();await ticks(3)
 check(group.zombies[0].visual.walk_clock>0.,"Added actors advance existing locomotion")
 var previous:=bodies(group)
 ui.kill_button.pressed.emit()
 check(group.living_count()==0 and group.active_ragdolls()==60 and group.zombies.size()==60,"KillAll starts native death physics for all60 simultaneously")
 check(previous.size()==420,"All420 native physical parts remain present")
 ui.kill_button.pressed.emit()
 check(group.active_ragdolls()==60,"Repeated KillAll cannot duplicate death events")
 ui.select_count(13);ui.spawn_button.pressed.emit()
 check(group.living_count()==13 and group.active_ragdolls()==60 and group.zombies.size()==73,"Spawn adds living actors while retaining all existing corpses")
 preserved=true
 for part in previous:preserved=preserved and is_instance_valid(part)
 check(preserved,"Adding a batch never retires native death graphs")
 var survivors:Array=[]
 for z in group.zombies:
  if not z.is_dead:survivors.append(z)
 await ticks(ceili(.5*fps))
 check(group.active_ragdolls()==60,"No hidden early corpse retirement reduces simultaneous physics load")
 await ticks(ceili(2.2*fps))
 check(group.living_count()==13 and group.active_ragdolls()==0 and group.kills==60,"All60 corpses clean up once after2.5s while13new actors survive")
 released(previous,"Normal corpse cleanup frees all420 native bodies")
 ui.spawn_button.pressed.emit()
 check(group.living_count()==26 and group.kills==60,"Later addition preserves survivors and kill statistics")
 preserved=true
 for z in survivors:preserved=preserved and is_instance_valid(z) and group.zombies.has(z)
 check(preserved,"Existing living actors survive repeated arbitrary13-count additions")
 previous=bodies(group);lab.reset_player()
 check(group.living_count()==13 and group.active_ragdolls()==0 and group.kills==0,"Explicit Rreset rebuilds last selected count and clears encounter stats")
 released(previous,"Explicit reset releases preceding native graphs")
 check(lab.rifle_auto_aim.target==null and lab.player.visual.auto_aim_target==null and lab.rifle_fire.active_projectiles()==0,"Explicit reset clears stale targets and projectiles")
 group.spawn_batch(0);lab.player.position=Vector3(49,0,49)
 ui.select_count(50);ui.spawn_button.pressed.emit();ui.spawn_button.pressed.emit()
 check(group.living_count()==100,"Per-click50 limit permits100 accumulated actors")
 spacing(group,lab.player)
 previous=bodies(group);lab.reset_player();released(previous,"R frees accumulated100actor graphs")
 check(group.living_count()==50,"R from a map corner restores the last applied50 around reset player")
 spacing(group,lab.player)
 metrics["blocks"]=10000;metrics["grass_clumps"]=field.instance_count;metrics["grass_batches"]=field.batch_count;metrics["interaction_size"]=state.size
 previous=bodies(group);lab.free();released(previous,"Scene exit releases all remaining native graphs");await process_frame
 var legacy=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
 legacy.performance_test_enabled=false;legacy.grass_field_blocks=30;legacy.grass_vegetation_enabled=false;root.add_child(legacy)
 check(legacy.zombie_combat.living_count()==4 and legacy.performance_controls==null and legacy.find_child("ExistingAssetLightingEvaluation",true,false)!=null,"Opt-out retains original four-zombie lighting fixture")
 legacy.free()
 print("PERFORMANCE_LAB_CHECKS ",JSON.stringify({"fps":fps,"checks":checks,"failures":failures,"metrics":metrics}));quit(0 if failures.is_empty() else 1)
