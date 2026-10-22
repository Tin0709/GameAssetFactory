extends SceneTree
## Exact source-pose equivalence plus the steady-state native sampling budget.
class CountedSampler extends RefCounted:
 var source:RefCounted
 var calls:=0
 func _init(original:RefCounted):source=original
 func position(bone:int,time:float)->Vector3:calls+=1;return source.position(bone,time)
 func rotation(bone:int,time:float)->Quaternion:calls+=1;return source.rotation(bone,time)
 func scale(bone:int,time:float)->Vector3:calls+=1;return source.scale(bone,time)
var failures:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func run():
 var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;lab.grass_vegetation_enabled=false;root.add_child(lab);lab.player.scripted_input=true
 var z=lab.zombie_combat.zombies[0];z.set_physics_process(false)
 var visual=z.visual
 var idle:=CountedSampler.new(visual.idle);var walk:=CountedSampler.new(visual.walk);var attack:=CountedSampler.new(visual.attack)
 visual.idle=idle;visual.walk=walk;visual.attack=attack
 var worst:=0.;var sample_counts:Dictionary={}
 for state in [{"name":"Idle","walk":0.,"attack":0.},{"name":"Walk","walk":1.,"attack":0.},{"name":"Attack","walk":.65,"attack":1.},{"name":"Blend","walk":.37,"attack":.29}]:
  visual.life=1.723;visual.walk_clock=7.123;visual.attack_time=.27;visual.walk_weight=state.walk;visual.attack_weight=state.attack
  idle.calls=0;walk.calls=0;attack.calls=0
  visual._process(0.)
  sample_counts[state.name]=idle.calls+walk.calls+attack.calls
  if state.name!="Blend":check(sample_counts[state.name]<=visual.skeleton.get_bone_count()*3,"Full "+state.name+" samples only its contributing source clip")
  var it:float=fposmod(visual.life+visual.phase_offset*3.6,3.6)
  var wt:float=fposmod(visual.walk_clock+visual.phase_offset*18.,18.)
  for bone in visual.skeleton.get_bone_count():
   var p:Vector3=idle.source.position(bone,it).lerp(walk.source.position(bone,wt),visual.walk_weight)
   var q:Quaternion=idle.source.rotation(bone,it).slerp(walk.source.rotation(bone,wt),visual.walk_weight)
   var s:Vector3=idle.source.scale(bone,it).lerp(walk.source.scale(bone,wt),visual.walk_weight)
   p=p.lerp(attack.source.position(bone,visual.attack_time),visual.attack_weight)
   q=q.slerp(attack.source.rotation(bone,visual.attack_time),visual.attack_weight)
   s=s.lerp(attack.source.scale(bone,visual.attack_time),visual.attack_weight)
   worst=maxf(worst,p.distance_to(visual.skeleton.get_bone_pose_position(bone)))
   worst=maxf(worst,s.distance_to(visual.skeleton.get_bone_pose_scale(bone)))
   worst=maxf(worst,1.-absf(q.dot(visual.skeleton.get_bone_pose_rotation(bone))))
 check(worst<.00001,"Optimized Idle/Walk/Attack/blends retain original source PRS poses")
 var dormant:=0
 for actor in lab.zombie_combat.zombies:
  for part in actor.ragdoll.bodies.values():
   for child in part.get_children():
    if child is CollisionShape3D and child.disabled:dormant+=1
 check(dormant==lab.zombie_combat.zombies.size()*7,"All living corpse shapes stay outside native broadphase")
 z.take_damage(z.current_hp,Vector3.RIGHT)
 var enabled:=0
 for part in z.ragdoll.bodies.values():
  for child in part.get_children():
   if child is CollisionShape3D and not child.disabled:enabled+=1
 check(z.ragdoll.running and enabled==7,"Lethal handoff enables all7 original collision shapes immediately")
 lab.free();print("HORDE_EFFICIENCY ",JSON.stringify({"checks":checks,"failures":failures,"worst_pose_error":worst,"source_calls":sample_counts}));quit(0 if failures.is_empty() else 1)
