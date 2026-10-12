extends SceneTree
var checks: Array=[]
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func head_top(v: Node) -> float:
	var highest:=-INF
	for mesh in v.meshes:
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array=mesh.mesh.surface_get_arrays(surface)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				for slot in 4:
					if arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]<.9:continue
					var bind: int=arrays[Mesh.ARRAY_BONES][i*4+slot]
					var name: StringName=mesh.skin.get_bind_name(bind)
					var bone: int=v.skeleton.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(bind)
					if v.skeleton.get_bone_name(bone)!="Head":continue
					var point: Vector3=v.skeleton.global_transform*v.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*arrays[Mesh.ARRAY_VERTEX][i]
					highest=maxf(highest,point.y)
	return highest
func run() -> void:
	var scene=load("res://scenes/dev/ExpressiveLocomotionTest.tscn").instantiate()
	root.add_child(scene);current_scene=scene;await scene.tick(3)
	var v=scene.actor.visual
	check(v.get("fall_wave_enabled")!=null,"Test visual exposes reversible descent arm gesture")
	if v.get("fall_wave_enabled")==null:quit(1);return
	var arms: Array=[v.skeleton.find_bone("Arm.L"),v.skeleton.find_bone("Arm.R")]
	for state in ["GROUND","PREP","AIR","LAND"]:
		for vy in [5.0,-6.0]:
			v.advance_jump(state,.4,vy,6.5,1.0,1.0/60)
			for bone in arms:
				v.fall_wave_enabled=false;var old: Transform3D=v._target_pose(bone)
				v.fall_wave_enabled=true;var revised: Transform3D=v._target_pose(bone)
				if state!="AIR" or vy>0:check(old.is_equal_approx(revised),"Fall wave leaves grounded, preparation, ascent and landing targets unchanged")
	var first: Array=[];var changed:=0.0
	for i in 40:
		v.advance_jump("AIR",.4+i/60.0,-6,6.5,1,1.0/60)
		for side in 2:
			var bone: int=arms[side]
			v.fall_wave_enabled=false;var old: Transform3D=v._target_pose(bone)
			v.fall_wave_enabled=true;var pose: Transform3D=v._target_pose(bone)
			if i==20:first.append(pose.basis.get_rotation_quaternion())
			if i==39:changed=maxf(changed,first[side].angle_to(pose.basis.get_rotation_quaternion()))
			check(old.origin.is_equal_approx(pose.origin),"Falling gesture does not translate shoulder or deform limb")
			check(pose.basis.get_scale().is_equal_approx(Vector3.ONE),"Falling arm remains rigid")
	check(changed>deg_to_rad(3),"Raised falling arms visibly wave rather than freeze")
	var leg_changes: Array=[]
	for bone in [v.leg_left,v.leg_right]:
		v.fall_wave_enabled=false;var old: Transform3D=v._target_pose(bone)
		v.fall_wave_enabled=true;var pose: Transform3D=v._target_pose(bone)
		leg_changes.append(old.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion()))
		check(old.origin.is_equal_approx(pose.origin) and pose.basis.get_scale().is_equal_approx(Vector3.ONE),"Falling leg gesture preserves rigid limb position and scale")
	check(leg_changes[0]>deg_to_rad(3) and leg_changes[1]>deg_to_rad(3),"Both falling legs have a readable whole-leg flutter")
	v.advance_jump("AIR",1,-8,6.5,.04,1.0/60)
	check(v.fall_wave_weight<.001,"Wave releases before contact for the existing heavy landing")
	scene.actor.scripted_input=true;scene.actor.review_drop(6)
	var min_hand_clearance:=INF;var samples:=0;var max_bend:=0.0
	for i in 90:
		await scene.tick(1)
		if v.fall_wave_weight<.99 or scene.actor.jump_state!="AIR":continue
		var top:=head_top(v);samples+=1
		for side in ["L","R"]:
			var fore: Transform3D=v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.skeleton.find_bone("ForeArm."+side))
			var upper: Transform3D=v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.skeleton.find_bone("Arm."+side))
			min_hand_clearance=minf(min_hand_clearance,(fore*Vector3(0,.2975,0)).y-top)
			max_bend=maxf(max_bend,upper.basis.y.normalized().angle_to(fore.basis.y.normalized()))
	check(samples>5,"Physical fall reaches sustained raised waving pose")
	check(min_hand_clearance>.005,"Both falling hand centers stay above the actual skinned head")
	check(max_bend<.001,"Full arms stay straight during fall waving")
	var out:="res://.validation/expressive_directional_v1";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/fall_arms.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"wave_change_degrees":rad_to_deg(changed),"minimum_hand_center_above_head_m":min_hand_clearance,"straight_arm_error_radians":max_bend,"physical_fall_samples":samples},"\t"))
	print("EXPRESSIVE_FALL_ARM_CHECKS ",checks.size()," failures ",failures.size());quit(0 if failures.is_empty() else 1)
