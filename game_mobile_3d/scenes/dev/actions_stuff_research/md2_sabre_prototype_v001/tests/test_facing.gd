extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();a.prefer_private_skin=false;root.add_child(a);a.set_physics_process(false)
	var rig:Skeleton3D=a.skeleton
	var left:=rig.find_bone("Leg.L");var right:=rig.find_bone("Leg.R")
	var rest:Transform3D=rig.get_bone_global_rest(left)
	check(rest.origin.x>rig.get_bone_global_rest(right).origin.x,"Authored anatomical left is positive local X")
	for key:String in ["CombatStrafeLeft","CombatStrafeRight"]:
		a.review(key);a.animation_player.play(a.clips[key].action,0.);a.animation_player.advance(0.);a.animation_player.seek(float(a.clips[key].duration)*.25,true);rig.force_update_all_bone_transforms()
		var rest_head:Vector3=rig.global_transform*rest.origin
		var foot_rest:=Vector3(rest_head.x,0,rest_head.z)
		var foot:Vector3=rig.global_transform*rig.get_bone_global_pose(left)*rest.affine_inverse()*rig.global_transform.affine_inverse()*foot_rest
		check(foot.x>foot_rest.x+.15 if key.ends_with("Left") else foot.x<foot_rest.x-.15,"Authored "+key+" actually moves the left foot toward its declared side")
	a.resume_gameplay();a._move_requested=true;a.combat_requested=true;a.visual.rotation.y=0.;a.velocity=Vector3(1,0,0)
	check(a._select_clip()=="CombatStrafeLeft","Positive X travel selects anatomical left when facing +Z")
	a.velocity=Vector3(-1,0,0)
	check(a._select_clip()=="CombatStrafeRight","Negative X travel selects anatomical right when facing +Z")
	a.visual.rotation.y=PI;a.velocity=Vector3(1,0,0)
	check(a._select_clip()=="CombatStrafeRight","Rotated actor chooses side relative to its own facing")
	var mode=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/mode.gd").new();root.add_child(mode);mode.actor=a;mode.set_physics_process(false)
	var event:=InputEventKey.new();event.physical_keycode=KEY_Q;event.pressed=true;mode.unhandled_input(event);mode._physics_process(0.)
	check((Basis(Vector3.UP,a.turn_axis*.1)*Vector3(0,0,1)).x>0.,"Q rotates actual +Z front toward anatomical +X left")
	event.pressed=false;mode.input(event);event.physical_keycode=KEY_C;event.pressed=true;mode.unhandled_input(event);mode._physics_process(0.)
	check((Basis(Vector3.UP,a.turn_axis*.1)*Vector3(0,0,1)).x<0.,"C rotates actual +Z front toward anatomical right")
	mode.free();a.free();print("SABRE_FACING ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
