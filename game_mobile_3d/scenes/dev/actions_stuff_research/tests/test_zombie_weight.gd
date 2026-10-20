extends SceneTree
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message);push_error(message)
func ticks(count:int)->void:
 for i in count:await physics_frame
 await process_frame
func run()->void:
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();scene.auto_aim_enabled=false;root.add_child(scene);scene.player.scripted_input=true
 var group=scene.zombie_combat
 for i in 4:
  var z=group.zombies[i];z.target=null;z.move_speed=0.;z.position=Vector3(5+i*3,0,5);z.velocity=Vector3.ZERO
 await ticks(12)
 var z=group.zombies[0];var start:Vector3=z.ragdoll.current.Chest.origin
 z.take_damage(999,Vector3.FORWARD)
 var impulse:Vector3=z.ragdoll.total_applied_impulse
 var age:=0.;var peak_rise:=0.;var reach:=0.;var contact_time:=-1.;var min_floor:=0.;var joint_error:=0.
 while is_instance_valid(z):
  if z.ragdoll.running:
   var chest:PhysicalBone3D=z.ragdoll.bodies.Chest
   peak_rise=maxf(peak_rise,chest.global_position.y-start.y)
   reach=maxf(reach,Vector2(chest.global_position.x-start.x,chest.global_position.z-start.z).length())
   min_floor=minf(min_floor,z.ragdoll.minimum_corner_y());joint_error=maxf(joint_error,z.ragdoll.max_anchor_error())
   if contact_time<0. and z.ragdoll.contact_motion().core_contacts>0:contact_time=age
  await ticks(1);age+=1./Engine.physics_ticks_per_second
 check(peak_rise<.15,"Rifle death does not loft the torso like a lightweight balloon")
 check(contact_time>=0. and contact_time<=.55,"Heavy core reaches the floor decisively within0.55seconds")
 check(reach<3.0,"Corpse throw stays short instead of sailing away")
 check(min_floor>-.08 and joint_error<.06,"Faster fall retains bounded floor/joint contacts")
 check(group.last_corpse_lifetime>=1.1 and group.last_corpse_lifetime<=1.3,"Mobile corpse lifetime remains1.2seconds")
 var report:={"passed":failures.is_empty(),"failures":failures,"physics_hz":Engine.physics_ticks_per_second,"impulse":str(impulse),"peak_torso_rise_m":peak_rise,"first_core_ground_contact_s":contact_time,"maximum_horizontal_torso_travel_m":reach,"minimum_corner_y_m":min_floor,"maximum_joint_error_m":joint_error,"corpse_lifetime":group.last_corpse_lifetime}
 print("ZOMBIE_WEIGHT ",JSON.stringify(report))
 var dest:=OS.get_environment("ZOMBIE_WEIGHT_RESULTS")
 if not dest.is_empty():FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 scene.free();quit(0 if failures.is_empty() else 1)
