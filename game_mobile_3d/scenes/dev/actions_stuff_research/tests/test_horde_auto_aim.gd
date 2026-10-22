extends SceneTree
## Same real physics LOS/registry/hysteresis result as the original scan, with
## distance-ordered queries. Frozen AI isolates target selection from motion.
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message);push_error(message)
func original(aim:Node,group:Node,player:CharacterBody3D,previous:Node3D)->Dictionary:
 var query:=PhysicsRayQueryParameters3D.new();query.collision_mask=5;query.exclude=[player.get_rid()];query.hit_from_inside=true
 var closest:Node3D;var best:float=pow(15.,2);var origin:=player.global_position;var rays:=0
 query.from=origin+Vector3(0,1.02,0)
 for zombie:Node3D in group.zombies:
  if not is_instance_valid(zombie) or zombie.is_dead:continue
  var offset:Vector3=zombie.global_position-origin;offset.y=0.;var distance:=offset.length_squared()
  if distance>best:continue
  query.to=zombie.global_position+Vector3(0,1.02,0);rays+=1
  var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
  if not hit.is_empty() and hit.collider!=zombie:continue
  best=distance;closest=zombie
 if closest!=previous and is_instance_valid(previous) and not previous.is_dead:
  var offset:Vector3=previous.global_position-origin;offset.y=0.;var distance:=offset.length()
  if distance<=15. and distance<=sqrt(best)+aim.RETARGET_MARGIN:
   query.to=previous.global_position+Vector3(0,1.02,0);rays+=1
   var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
   if hit.is_empty() or hit.collider==previous:closest=previous
 return {"target":closest,"rays":rays}
func run():
 var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;lab.grass_vegetation_enabled=false;root.add_child(lab)
 lab.player.scripted_input=true;lab.player.set_physics_process(false);lab.rifle_auto_aim.set_physics_process(false);lab.rifle_fire.set_physics_process(false)
 lab.zombie_combat.spawn_batch(0);lab.zombie_combat.add_batch(50);lab.zombie_combat.add_batch(50)
 for z in lab.zombie_combat.zombies:z.set_physics_process(false)
 lab.player.visual.set_rifle_aim(true)
 var before:=0;var after:=0;var comparisons:=0
 # Include center overlaps, dense occlusion, peripheral positions, equal distances,
 # current-target retention, a target leaving range and dead entries.
 for i in 120:
  var t:=float(i)*.113;lab.player.position=Vector3(sin(t)*7.,0.,cos(t)*7.)
  if i==40:lab.zombie_combat.zombies[0].is_dead=true
  if i==80:lab.zombie_combat.zombies[1].position=lab.player.position+Vector3(15.1,0,0)
  await physics_frame;await process_frame
  var expected:=original(lab.rifle_auto_aim,lab.zombie_combat,lab.player,lab.rifle_auto_aim.target)
  lab.rifle_auto_aim._physics_process(1./60.)
  check(lab.rifle_auto_aim.target==expected.target,"Exact nearest-visible/hysteresis result "+str(i))
  before+=expected.rays;after+=lab.rifle_auto_aim.last_ray_count;comparisons+=1
 check(after<before,"Dense scan reduces actual native LOS queries")
 var rows:int=lab.rifle_auto_aim._candidate_rows.size()
 for i in 10:lab.rifle_auto_aim._physics_process(1./60.)
 check(rows==lab.rifle_auto_aim._candidate_rows.size(),"Steady scans reuse candidate storage")
 print("HORDE_AUTO_AIM ",JSON.stringify({"failures":failures,"comparisons":comparisons,"original_rays":before,"ordered_rays":after,"rows":rows}))
 lab.free();quit(0 if failures.is_empty() else 1)
