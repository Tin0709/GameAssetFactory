extends SceneTree
var checks: Array=[]
var failures: Array=[]
var samples: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks.append({"check":message,"passed":ok})
 if not ok:failures.append(message);push_error(message)
func run() -> void:
 var scene=load("res://scenes/dev/RifleStylizedV2IntegrationTest.tscn").instantiate();root.add_child(scene);current_scene=scene
 var actor=scene.actor;var v=actor.visual;var socket=v.socket;actor.scripted_input=true
 await scene.tick(45)
 var original_grip: Vector3
 var original_support: Vector3
 scene.select_rifle(false);original_grip=socket.grips[1];original_support=socket.supports[1]
 scene.select_rifle(true)
 check(socket.grips[1].distance_to(original_grip)<.00001,"Right trigger-grip target matches preserved R13")
 check(socket.supports[1].distance_to(original_support)<.00001,"Left support target matches preserved R13")
 check(socket.hand_transforms[1].basis.get_scale().distance_to(Vector3.ONE*1.05)<.00001,"Ready mount uses uniform scale preserving model proportions")
 check(socket.r13_stow_mounts[1].basis.get_scale().distance_to(Vector3.ONE*1.05)<.00001,"Back mount uses uniform scale preserving model proportions")
 for marker in ["RightHandGrip","LeftHandGuide","Muzzle","AimReference","RecoilPivot","HolsterAttach","Grip_Point","Support_Hand_Point","Muzzle_Point"]:
  check(scene.candidate_rifle.find_child("*"+marker+"*",true,false)!=null,"Exported marker: "+marker)
 for label in ["Idle","Walk","Run","Turn","Jump","Fall","Recovery"]:
  actor.requested_run=label in ["Run","Turn","Jump","Fall","Recovery"]
  actor.requested_direction=Vector2.ZERO if label=="Idle" else (Vector2(-1,0) if label=="Turn" else Vector2(0,1))
  if label=="Jump":actor.request_jump()
  if label=="Fall":actor.review_drop(6)
  var peak_grip:=0.0;var peak_support:=0.0;var scale_error:=0.0
  for tick in 65:
   await scene.tick(1,label)
   var model: Node3D=socket.instances[1]
   var grip: Node3D=model.find_child("*Grip_Point*",true,false)
   var support: Node3D=model.find_child("*Support_Hand_Point*",true,false)
   peak_grip=maxf(peak_grip,grip.global_position.distance_to(socket.global_transform*socket.grips[1]))
   peak_support=maxf(peak_support,support.global_position.distance_to(socket.global_transform*socket.supports[1]))
   scale_error=maxf(scale_error,(model.transform.basis.get_scale()-Vector3.ONE*1.05).length())
  check(peak_grip<.00001,label+" grip remains attached to active socket")
  check(peak_support<.00001,label+" support marker follows native support target")
  check(scale_error<.00001,label+" preserves uniform mount and rigid model")
  samples.append({"phase":label,"socket_grip_error_m":peak_grip,"socket_support_error_m":peak_support,"uniform_scale_error":scale_error})
 actor.requested_direction=Vector2.ZERO;await scene.tick(90)
 scene.display_back(true);await scene.tick(45)
 check(socket.instances[1].get_parent()==socket.back_socket,"Rifle stows on Chest back attachment")
 check(scene.candidate_rifle.visible,"Back rifle visible")
 check(not v.weapon_equipped,"Back fit leaves relaxed native arms")
 var back: Transform3D=scene.candidate_rifle.transform
 check(back.origin.distance_to(scene.original_back.origin)<.00001,"Back anchor position preserved")
 check(back.basis.get_scale().distance_to(Vector3.ONE*1.05)<.00001,"Back fit preserves proportions")
 scene.display_back(false);await scene.tick(30)
 scene.select_rifle(false);await scene.tick(10)
 check(socket.instances[1]==scene.original_rifle and not scene.candidate_rifle.visible,"Previous production model remains selectable")
 scene.select_rifle(true);await scene.tick(30)
 check(socket.instances[1]==scene.candidate_rifle and not scene.original_rifle.visible,"V2 selection restores independent model and sockets")
 var out:="res://.validation/rifle_v2_integration";DirAccess.make_dir_recursive_absolute(out)
 FileAccess.open(out+"/runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"))
 print("RIFLE_V2_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)

