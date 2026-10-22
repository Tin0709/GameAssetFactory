extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func ticks(n:int)->void:
 for i in n:await physics_frame
 await process_frame
func run():
 Engine.physics_ticks_per_second=60
 var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;lab.grass_vegetation_enabled=false;root.add_child(lab);lab.player.scripted_input=true
 lab.zombie_combat.spawn_batch(2)
 var jam=lab.zombie_combat.zombies[0];var free=lab.zombie_combat.zombies[1]
 check(jam.get("ai_steps")!=null,"Performance actors expose bounded blocked-motion scheduling")
 if jam.get("ai_steps")==null:lab.free();print("HORDE_CROWD ",JSON.stringify({"checks":checks,"failures":failures}));quit(1);return
 var wall:=StaticBody3D.new();wall.position=Vector3(0,1,-2)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6,2,.2);shape.shape=box;wall.add_child(shape);lab.add_child(wall)
 jam.position=Vector3(0,0,-3.5);free.position=Vector3(8,0,-6)
 await ticks(90)
 check(jam._ai_blocked and jam.is_on_floor(),"Actual native wall contact detects a blocked grounded chaser")
 free.position=Vector3(8,0,-6);free.velocity=Vector3.ZERO
 var ai:int=jam.ai_steps;var samples:int=jam.ragdoll.sample_count;var poses:int=jam.visual.source_frames;var free_ai:int=free.ai_steps
 await ticks(30)
 var blocked_steps:int=jam.ai_steps-ai
 check(blocked_steps>=14 and blocked_steps<=16,"Blocked native movement retries at30Hz rather than60Hz")
 check(jam.visual.source_frames-poses==30 and jam.ragdoll.sample_count-samples==30,"Blocked actor retains full60Hz source poses and death handoff samples")
 check(free.ai_steps-free_ai==30,"Unblocked movement still updates at every60Hz physics tick")
 jam.take_damage(1,Vector3.BACK)
 check(not jam._ai_blocked,"A bullet immediately wakes blocked movement and knockback")
 await ticks(2)
 check(jam.knockback.length()>0. and jam.visual.hit_count>0,"Existing live hit reaction and knockback remain active")
 wall.free();var before:Vector3=jam.position;await ticks(30)
 check(jam.position.distance_to(before)>.35,"Removing the blocker resumes native approach promptly")
 var death_before:int=jam.death_triggers;jam.take_damage(999,Vector3.BACK)
 check(jam.death_triggers==death_before+1 and jam.ragdoll.running,"Blocked scheduling cannot defer native lethal handoff")
 check(jam.corpse_lifetime==2.5 and jam.combat_rifle.linear_impulse==480.,"Approved corpse lifetime and impact remain exact")
 jam.take_damage(999,Vector3.BACK);check(jam.death_triggers==death_before+1,"Repeated lethal hits remain idempotent")
 var parts:Array=jam.ragdoll.bodies.values();await ticks(160)
 var released:=true
 for part in parts:released=released and not is_instance_valid(part)
 check(released,"Existing2.5s cleanup releases every native part")
 lab.free();print("HORDE_CROWD ",JSON.stringify({"checks":checks,"failures":failures,"blocked_steps_in30ticks":blocked_steps}));quit(0 if failures.is_empty() else 1)
