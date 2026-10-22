extends SceneTree
## Actual lab regression: flat pooled bullets, stronger deaths and contact arrest.
var failures:Array[String]=[]
var checks:=0
var metrics:Dictionary={}
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func ticks(count:int)->void:
 for i in count:await physics_frame
 await process_frame
func finish(lab:Node)->void:
 lab.free()
 print("COMBAT_FEEL_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
 quit(0 if failures.is_empty() else 1)
func run():
 var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;lab.grass_vegetation_enabled=false;root.add_child(lab)
 lab.player.scripted_input=true
 var fire=lab.rifle_fire
 check(lab.get("grass_vegetation_enabled")==false,"Combat fixture explicitly pauses vegetation while preserving the enabled100m gameplay field")
 var hidden:=true
 for child in lab.grass_field.get_children():
  if child.name.begins_with("GrassRegion_"):hidden=hidden and not child.visible
 check(hidden and not lab.grass_field.is_processing() and not lab.grass_field.is_physics_processing(),"Grass draw and interaction work are paused, with source retained")
 check(lab.grass_field.get_node("ThirtyByThirtyBlocks").visible and lab.grass_field.instance_count==1317,"Ground remains visible and all grass data is retained")
 check(fire.get("level_trajectory")==true,"Current lab levels the projectile trajectory")
 check(fire.get("projectile_speed_multiplier")==1.5,"Current lab bullets travel 50 percent faster")
 check(fire.get("projectile_range_multiplier")==3.,"Current lab range extends to 45 metres")
 var zombie=lab.zombie_combat.zombies[0]
 check(zombie.corpse_lifetime==2.5,"Corpse lifetime is 2.5 seconds")
 check(zombie.combat_rifle.linear_impulse==480. and zombie.combat_rifle.upward_impulse==96.,"One doubled impulse gives doubled launch speed without a second multiplier")
 if not failures.is_empty():finish(lab);return
 # Test the real firing path with an intentionally downward animated barrel.
 lab.zombie_combat.spawn_batch(0);lab.rifle_auto_aim.set_physics_process(false)
 lab.set_process(false);lab.player.set_physics_process(false)
 var visual=lab.player.visual
 visual.set_process(false);fire.set_physics_process(false)
 visual.set_rifle_aim(true)
 for i in 60:visual.drive_jump_motion(Vector3.ZERO,false,{"grounded":true,"body_position":Vector3.ZERO,"vertical_speed":0.,"takeoff":false,"sprinting":false},1./60.)
 var pose:Transform3D=visual.skeleton.get_bone_global_pose(visual.carrier_bone)
 pose.basis=Basis(Vector3.RIGHT,deg_to_rad(35.))*pose.basis
 visual.skeleton.set_bone_global_pose(visual.carrier_bone,pose)
 var barrel:Vector3=(visual.skeleton.global_basis*pose.basis).y
 check(absf(barrel.y)>.1,"Trajectory regression exercises a pitched animated barrel")
 var profile:Dictionary=fire.Profiles.PROFILES[1]
 fire.reset_fire();fire._fire(profile)
 var slot:int=fire.ages.find(0.)
 check(slot>=0,"Pitched-barrel shot spawns from the actual muzzle")
 if slot<0:finish(lab);return
 var origin:Vector3=fire.bullets[slot].global_position
 var direction:Vector3=fire.directions[slot]
 check(absf(direction.y)<.000001 and absf(direction.length()-1.)<.000001,"Actual shot is level and normalized despite barrel pitch")
 var before_hits:int=fire.hit_count
 for i in 10:fire._move_projectiles(.1,profile)
 var distance:float=fire.bullets[slot].global_position.distance_to(origin)
 check(fire.ages[slot]>=0. and absf(distance-30.)<.0001,"Bullet travels 30m in one second, passing the invisible 15m boundary")
 check(absf(fire.bullets[slot].global_position.y-origin.y)<.000001 and fire.hit_count==before_hits,"Long flight neither sinks nor hits the ground")
 for i in 6:fire._move_projectiles(.1,profile)
 check(fire.active_projectiles()==0,"Extended 45m range still expires pooled bullets")
 metrics["bullet_distance_at_1s_m"]=distance
 metrics["pitched_barrel_y"]=barrel.y
 # A fast swept bullet must still damage the existing zombie collision body.
 fire.reset_fire()
 visual.drive_jump_motion(Vector3.ZERO,false,{"grounded":true,"body_position":Vector3.ZERO,"vertical_speed":0.,"takeoff":false,"sprinting":false},1./60.)
 lab.zombie_combat.spawn_batch(1);zombie=lab.zombie_combat.zombies[0]
 origin=visual.socket.muzzle_position()
 var carrier:Transform3D=visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(visual.carrier_bone)
 direction=fire._flight_direction(carrier.basis.y)
 zombie.position=origin+direction*3.;zombie.position.y=0.
 zombie.set_physics_process(false)
 await ticks(2)
 var hp:int=zombie.current_hp
 fire._fire(profile);fire._move_projectiles(.2,profile)
 check(zombie.current_hp<hp,"Swept collision at the faster speed still damages a real zombie")
 fire.reset_fire();lab.zombie_combat.spawn_batch(2);zombie=lab.zombie_combat.zombies[0]
 var spectator=lab.zombie_combat.zombies[1]
 spectator.position=Vector3(0,0,3.7);spectator.set_physics_process(false)
 zombie.position=Vector3(0,0,5)
 await ticks(3)
 zombie.take_damage(zombie.current_hp,Vector3.FORWARD)
 check(zombie.death_triggers==1 and zombie.ragdoll.total_applied_impulse.is_equal_approx(Vector3(0,96,-480)),"One lethal hit starts one doubled native impact")
 var parts:Array=zombie.ragdoll.bodies.values().duplicate()
 var first_contact:=Vector3.ZERO;var later_contact:=Vector3.ZERO;var contact_time:=-1.;var air_speed:=0.
 var touched_living:=false;var tested_living_sweep:=false;var living_sweep_blocked:=false
 for i in 120:
  await ticks(1)
  if not is_instance_valid(zombie):break
  var center:=Vector3.ZERO;var velocity:=Vector3.ZERO;var mass:=0.
  for part in zombie.ragdoll.bodies.values():
   center+=part.global_position*part.mass;velocity+=part.linear_velocity*part.mass;mass+=part.mass
   var state:=PhysicsServer3D.body_get_direct_state(part.get_rid())
   for j in state.get_contact_count():
    touched_living=touched_living or state.get_contact_collider_id(j)==spectator.get_instance_id()
  if not tested_living_sweep and zombie.corpse_age>=.10:
   tested_living_sweep=true
   var chest:PhysicalBone3D=zombie.ragdoll.bodies.Chest
   var from:Transform3D=spectator.global_transform
   from.origin=Vector3(chest.global_position.x-.8,.01,chest.global_position.z)
   var collision:=KinematicCollision3D.new()
   if spectator.test_move(from,Vector3(1.6,0,0),collision):
    for j in collision.get_collision_count():living_sweep_blocked=living_sweep_blocked or collision.get_collider(j) is PhysicalBone3D
  center/=mass;velocity/=mass;center.y=0.;velocity.y=0.
  if not zombie.ground_arrested:air_speed=maxf(air_speed,velocity.length())
  elif contact_time<0.:
   contact_time=zombie.corpse_age;first_contact=center
  elif zombie.corpse_age>=contact_time+.10 and later_contact==Vector3.ZERO:later_contact=center
  if zombie.corpse_age>=1.5:break
 check(is_instance_valid(zombie) and zombie.corpse_age>=1.49,"Corpse survives beyond the former cleanup time")
 check(zombie.ground_arrested and contact_time>.08 and contact_time<1.2,"Only actual core landing engages ground arrest, after the airborne throw")
 var drift:float=first_contact.distance_to(later_contact)
 check(air_speed>5. and drift>.09 and drift<.4,"Strong throw has a short readable slide after landing, without an icy glide")
 check(not touched_living,"Flying native corpse passes through an actual living zombie without contact")
 check(tested_living_sweep and not living_sweep_blocked,"Living zombie movement cannot collide with or push a flying corpse")
 metrics["peak_airborne_com_speed_mps"]=air_speed
 metrics["first_core_contact_s"]=contact_time
 metrics["ground_drift_first_0_1s_m"]=drift
 metrics["corpse_contact_with_living"]=touched_living
 metrics["living_sweep_blocked_by_corpse"]=living_sweep_blocked
 zombie.take_damage(999,Vector3.BACK)
 check(zombie.death_triggers==1,"Repeated lethal damage cannot accumulate launch impulses")
 await ticks(75)
 var freed:=true
 for part in parts:freed=freed and not is_instance_valid(part)
 check(not is_instance_valid(zombie) and freed,"2.5-second cleanup releases all native body resources")
 finish(lab)
