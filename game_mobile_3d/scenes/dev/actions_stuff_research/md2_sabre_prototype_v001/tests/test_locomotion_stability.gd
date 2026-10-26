extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func ticks(n:int)->void:
	for i in n:await tick()
func angles(rig:Skeleton3D,name:String)->Vector3:
	var bone:=rig.find_bone(name);var skin:Basis=(rig.get_bone_global_pose(bone)*rig.get_bone_global_rest(bone).affine_inverse()).basis
	var up:=skin.y.normalized();var forward:=skin.z.normalized()
	return Vector3(rad_to_deg(atan2(up.x,up.y)),rad_to_deg(atan2(-up.z,up.y)),rad_to_deg(atan2(forward.x,forward.z)))
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.grass_field_blocks=30;root.add_child(lab);await ticks(5)
	var a=lab.player;var rig:Skeleton3D=a.skeleton;var trials:Array[Dictionary]=[]
	check(a.get("body_stability_enabled")==true,"Source locomotion has an explicit reversible body stability adapter")
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz
		for yaw:float in [.66,1.3]:
			lab.sabre_mode.reset();lab.azimuth=yaw;await ticks(5);Input.action_press("move_forward");await ticks(hz/2)
			var min_body:=Vector3(INF,INF,INF);var max_body:=-min_body;var min_head:=min_body;var max_head:=max_body;var screen_drift:=0.;var heading_error:=0.
			for i in hz:
				var body:=angles(rig,"J_Spine");var head:=angles(rig,"J_Head");min_body=min_body.min(body);max_body=max_body.max(body);min_head=min_head.min(head);max_head=max_head.max(head)
				var p:Vector3=a.position+Vector3.UP;var screen:Vector2=lab.camera.unproject_position(p+a.velocity)-lab.camera.unproject_position(p);screen_drift=maxf(screen_drift,absf(screen.x))
				heading_error=maxf(heading_error,acos(clampf(a.visual.global_basis.z.dot(Vector3(a.velocity.x,0,a.velocity.z).normalized()),-1.,1.)))
				await tick()
			Input.action_release("move_forward")
			check(screen_drift<.001 and heading_error<.001,"W travel/facing stays straight in the actual camera at%dHz yaw%.2f"%[hz,yaw])
			check((max_body-min_body).x<1.8 and (max_body-min_body).y<2.,"Gameplay body roll/pitch no longer uses full raw sway at%dHz"%hz)
			check((max_head-min_head).y<1.6,"Head stabilization compensates spine change rather than doubling nod at%dHz"%hz)
			trials.append({"hz":hz,"camera_yaw":yaw,"body_angle_range":str(max_body-min_body),"head_angle_range":str(max_head-min_head),"screen_lateral_velocity":screen_drift,"actor_heading_error":heading_error})
	# Raw source review must bypass corrections, with no modified resource keys.
	a.set_physics_process(false);a.review("Run");a.animation_player.play(a.clips.Run.action,0.);a.animation_player.advance(0.);a._animate(.15);var reference:Array[Transform3D]=[]
	for bone in rig.get_bone_count():reference.append(rig.get_bone_pose(bone))
	a.animation_player.seek(.15,true);var unchanged:=true
	for bone in rig.get_bone_count():unchanged=unchanged and rig.get_bone_pose(bone).is_equal_approx(reference[bone])
	check(unchanged,"Raw Run review matches direct original sampling for all32bones")
	if a.get("body_stability")!=null:
		var helper=a.body_stability;var spine:=rig.find_bone("J_Spine");var head:=rig.find_bone("J_Head");var neck:=rig.get_bone_parent(head)
		a.review_clip="";helper.deactivate();a.animation_player.play(a.clips.Run.action,0.);a.animation_player.seek(.12,true);rig.force_update_all_bone_transforms()
		var raw:Array[Transform3D]=[];var legs:Array[Transform3D]=[]
		for bone in rig.get_bone_count():raw.append(rig.get_bone_pose(bone))
		for name:String in ["J_L_Leg","J_R_Leg"]:legs.append(rig.get_bone_global_pose(rig.find_bone(name)))
		var head_before:Transform3D=rig.get_bone_global_pose(head);var face_relative:Dictionary={}
		for name:String in ["J_L_EyeIris","J_R_EyeIris","J_L_EyePupil","J_R_EyePupil","J_L_Eyebrow","J_R_Eyebrow","J_Mouth"]:
			var bone:=rig.find_bone(name);face_relative[bone]=head_before.affine_inverse()*rig.get_bone_global_pose(bone)
		helper.apply("Run",.1,true);var allowed:=true
		for bone:int in face_relative:
			check((rig.get_bone_global_pose(head).affine_inverse()*rig.get_bone_global_pose(bone)).is_equal_approx(face_relative[bone]),"Face region retains original head-relative transform after head stabilization: "+str(rig.get_bone_name(bone)))
		for bone in rig.get_bone_count():
			if bone not in [spine,head]:allowed=allowed and rig.get_bone_pose(bone).is_equal_approx(raw[bone])
		check(allowed,"Stability changes only spine/head local poses; arms/weapon/root/hip/legs stay original")
		check(rig.get_bone_global_pose(rig.find_bone("J_L_Leg")).is_equal_approx(legs[0]) and rig.get_bone_global_pose(rig.find_bone("J_R_Leg")).is_equal_approx(legs[1]),"All lower-body global trajectories remain identical")
		check(rig.get_bone_global_pose(head).origin.distance_to(rig.get_bone_global_pose(neck)*raw[head].origin)<.00001,"Head rotation stabilization keeps the original neck attachment position")
		var stable:Transform3D=rig.get_bone_global_pose(head)
		for i in 20:
			helper.restore();a.animation_player.seek(.12,true);rig.force_update_all_bone_transforms();helper.apply("Run",1./60.,true)
		check(rig.get_bone_global_pose(head).is_equal_approx(stable),"Repeated source evaluation has no accumulated stabilization drift")
		helper.deactivate();var restored:=true
		for bone in rig.get_bone_count():restored=restored and rig.get_bone_pose(bone).is_equal_approx(raw[bone])
		check(restored,"Disabling stability restores every original local pose")
	var out:={"checks":checks,"failures":failures,"trials":trials,"native_md2_blend_weights_verified":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_movement"));FileAccess.open("res://.validation/md2_sabre_movement/locomotion-stability.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("SABRE_LOCOMOTION_STABILITY ",JSON.stringify(out));lab.free();quit(0 if failures.is_empty() else 1)
