extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var path:="res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/locomotion_direction.gd"
	check(FileAccess.file_exists(path),"Grounded leg direction helper exists independently of source assets")
	if not failures.is_empty():quit(1);return
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	var helper=a.direction_adapter;var rig:Skeleton3D=a.skeleton
	check(helper!=null and helper.point_count()>8,"Rigid source leg/foot vertices cached for sole-height preservation")
	var left:int=rig.find_bone("J_L_Leg");var weapon:int=rig.find_bone("J_R_Weapon");var hip:int=rig.find_bone("J_Hip")
	for angle:float in [PI*.5,-PI*.5,PI,PI*.25,PI*.75]:
		helper.restore();a.animation_player.play(a.clips.Walk.action,0.);a.animation_player.seek(float(a.clips.Walk.duration)*.25,true);rig.force_update_all_bone_transforms()
		var raw:Transform3D=rig.get_bone_global_pose(left);var rest:Transform3D=rig.get_bone_global_rest(left)
		var sole0:float=helper.sole_minimum(0);var sole1:float=helper.sole_minimum(1)
		var weapon_before:Transform3D=rig.get_bone_global_pose(weapon);var hip_before:Transform3D=rig.get_bone_global_pose(hip)
		helper.current_yaw=angle;helper.current_world_yaw=angle;helper.apply(Vector3(sin(angle),0,cos(angle)),1./60.)
		var target:Basis=Basis(Vector3.UP,angle)*(raw.basis*rest.basis.inverse())*Basis(Vector3.UP,-angle)*rest.basis
		check(rig.get_bone_global_pose(left).basis.is_equal_approx(target),"Leg trajectory follows skeleton-space direction "+str(angle))
		check(absf(helper.sole_minimum(0)-sole0)<.0001 and absf(helper.sole_minimum(1)-sole1)<.0001,"Direction adds no sole-height change, including diagonals "+str(angle))
		check(rig.get_bone_global_pose(weapon).is_equal_approx(weapon_before) and rig.get_bone_global_pose(hip).is_equal_approx(hip_before),"Upper body/weapon remain exact source pose "+str(angle))
	for hz in [30,60]:
		var first:=Transform3D.IDENTITY
		for i in 20:
			helper.restore();a.animation_player.play(a.clips.Run.action,0.);a.animation_player.seek(float(a.clips.Run.duration)*.25,true);rig.force_update_all_bone_transforms()
			helper.current_yaw=PI*.5;helper.current_world_yaw=PI*.5;helper.apply(Vector3.RIGHT,1./hz)
			if i==0:first=rig.get_bone_global_pose(left)
		check(rig.get_bone_global_pose(left).is_equal_approx(first),"Repeated source evaluation has no adapter accumulation at "+str(hz))
	helper.restore();a.visual.rotation.y=.5;helper.current_world_yaw=PI*.5;helper.apply(Vector3.RIGHT,1./60.)
	var world_direction:Vector3=rig.global_basis*Vector3(sin(helper.current_yaw),0,cos(helper.current_yaw))
	check(absf(wrapf(atan2(world_direction.x,world_direction.z)-PI*.5,-PI,PI))<.00001,"World travel plane stays fixed while body facing rotates")
	a.review("Walk");a.animation_player.play(a.clips.Walk.action,0.);a.animation_player.seek(.2,true);a._animate(0.);rig.force_update_all_bone_transforms()
	var review:Transform3D=rig.get_bone_global_pose(left)
	helper.restore();a.animation_player.seek(.2,true);rig.force_update_all_bone_transforms()
	check(review.is_equal_approx(rig.get_bone_global_pose(left)),"Raw action review bypasses leg direction adapter")
	a.free();print("SABRE_LOCOMOTION_DIRECTION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
