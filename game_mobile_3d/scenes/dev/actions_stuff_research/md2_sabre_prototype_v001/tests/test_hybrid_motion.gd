extends SceneTree
var failures:Array[String]=[]
var checks:=0
var measurements:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	lab.md2_sabre_prototype_enabled=true;lab.grass_field_blocks=80;root.add_child(lab)
	await physics_frame;await process_frame
	var a=lab.player
	check(a.get("hybrid_motion")!=null,"Selected private hybrid motion is installed on existing Valorie actor")
	if not failures.is_empty():lab.free();quit(1);return
	check(a.using_original_source and a.skeleton.get_bone_count()==32,"Original Valorie32-bone skin preserved")
	check(absf(a.run_speed-7.)<.00001,"Existing7m/s physics preserved")
	for key in ["Attack1","Attack2","Attack3","AirAttack"]:check(not a.clips[key].action.begins_with("hybrid/"),"MD2 combat source remains "+key)
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();a.scripted_input=true
		await ticks(3)
		a.requested_direction=Vector2.UP;a.requested_run=true
		await ticks(hz)
		check(a.current_speed>6.99,"Physical running speed at "+str(hz))
		check(a.hybrid_motion.last_kind=="Run","A&S Run supplies final base pose at "+str(hz))
		check(a.hybrid_motion.phase>0. and a.hybrid_motion.phase<1.,"Continuous hybrid gait phase at "+str(hz))
		a.reset_movement_measurements();await ticks(hz)
		var meter:Dictionary=a.movement_measurements()
		check(absf(float(meter.distance)-7.)<.025,"Measured7m travel in one steady second at "+str(hz))
		check(absf(float(meter.gait_cycles)-7./(5.59*.625))<.025,"Every animation substep contributes to distance-calibrated Run cadence at "+str(hz))
		check(a.hybrid_motion.maximum_attachment_gap<.0001,"Target skin shoulders stay connected at "+str(hz))
		var head:int=a.skeleton.find_bone("J_Head");var eye:int=a.skeleton.find_bone("J_L_EyeIris")
		var expected:Transform3D=a.skeleton.get_bone_global_rest(head).affine_inverse()*a.skeleton.get_bone_global_rest(eye)
		var shown:Transform3D=a.skeleton.get_bone_global_pose(head).affine_inverse()*a.skeleton.get_bone_global_pose(eye)
		check(shown.origin.distance_to(expected.origin)<.0001,"Iris stays attached to moving head at "+str(hz))
		a.requested_run=false;await ticks(hz)
		check(a.hybrid_motion.last_kind=="Walk","A&S Walk supplies final base pose at "+str(hz))
		a.requested_jump=true;await ticks(1);a.requested_jump=false
		var peak:float=a.global_position.y;var saw_landing:=false;var native_arms_checked:=false;var continuous_apex:=false
		for i in hz*2:
			await ticks(1);peak=maxf(peak,a.global_position.y)
			if a._jump_stage=="JumpLanding":saw_landing=true
			if a._jump_stage=="JumpTakeoff" and a._jump_time>.15 and not native_arms_checked:
				var native:Array=a.hybrid_motion._native_worlds(a,"JumpTakeoff");var chest:int=a.skeleton.find_bone("J_Shoulders");var worst:=0.
				for bone_name in ["J_L_Arm","J_R_Arm"]:
					var bone:int=a.skeleton.find_bone(bone_name)
					var truth:Transform3D=native[chest].affine_inverse()*native[bone];var visible:Transform3D=a.skeleton.get_bone_global_pose(chest).affine_inverse()*a.skeleton.get_bone_global_pose(bone)
					worst=maxf(worst,truth.basis.get_rotation_quaternion().angle_to(visible.basis.get_rotation_quaternion()))
				check(worst<.002,"Both flight arms follow actual MD2 source orientation at "+str(hz));native_arms_checked=true
			if a._jump_stage=="JumpAirborne" and a._jump_time>.1:continuous_apex=a.source_transition.elapsed>.25
		check(peak>.9 and saw_landing and a.is_on_floor(),"Collision-owned hybrid jump/landing at "+str(hz))
		check(a.hybrid_motion.landing_samples>int(.5*hz),"Moving bounce is not cut off by old50ms landing release at "+str(hz))
		check(native_arms_checked and continuous_apex,"Apex keeps the continuous hybrid body handoff at "+str(hz))
		a.attack(true);await ticks(hz*2);a.attack(false);await ticks(hz)
		check(a.accepted_count>=3,"Native MD2 combo still chains at "+str(hz))
		check(a.skeleton.get_bone_global_pose(a.skeleton.find_bone("J_Head")).is_finite(),"Composed head remains finite at "+str(hz))
		a.requested_direction=Vector2.ZERO;await ticks(hz)
		check(a.current_speed<.001 and a.combo.phase==&"ready","Stops and recovers at "+str(hz))
		measurements.append({"hz":hz,"run_distance_one_second":meter.distance,"run_cycles_one_second":meter.gait_cycles,"attachment_error_m":a.hybrid_motion.maximum_attachment_gap,"peak_height_m":peak,"foot_ground":a.foot_placement.snapshot()})
	var report:={"checks":checks,"failures":failures,"measurements":measurements}
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	FileAccess.open(research.path_join("blender/hybrid_godot_v001/gameplay_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HYBRID_MOTION ",JSON.stringify(report));lab.free();quit(0 if failures.is_empty()else 1)
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
