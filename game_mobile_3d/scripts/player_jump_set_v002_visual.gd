extends "res://scripts/player_combat_strafe_r15.gd"
## Last layer in the existing sole pose writer; no AnimationTree competition.
var jump_active := false
var jump_time := 0.0
var jump_pose: RefCounted
var jump_arm_weight := 1.0
var jump_duration := 26.0/30.0
var jump_moving := false

func _is_additional_authored_bone(rig: Skeleton3D, bone: int) -> bool:
	var name:=rig.get_bone_name(bone)
	if name not in ["ForeArm.L","ForeArm.R"]: return false
	var parent:=rig.get_bone_name(rig.get_bone_parent(bone))
	assert(parent=="Arm."+name.right(1))
	var expected:=Transform3D(Basis.IDENTITY,Vector3(0,.3375,0))
	assert(rig.get_bone_rest(bone).is_equal_approx(expected),"Authored elbow rest mismatch")
	return true

func _ready() -> void:
	super._ready()
	jump_pose=samples["Jump_Stationary_v002"]
	jump_pose.clip.loop_mode=Animation.LOOP_NONE

func select_jump(action: String, duration: float) -> void:
	jump_pose=samples[action]
	jump_moving=action!="Jump_Stationary_v002"
	jump_pose.clip.loop_mode=Animation.LOOP_NONE
	jump_duration=duration

func set_jump_state(active: bool, time: float) -> void:
	jump_active=active; jump_time=time

func _preserve_grip() -> bool:
	return weapon_equipped and (socket.current_attachment in [&"hand",&"carrier"] or r13_mode!=&"" or r13_exit_time>=0.0)

func _process(delta: float) -> void:
	if socket!=null and not frozen:
		jump_arm_weight=move_toward(jump_arm_weight,0.0 if _preserve_grip() else 1.0,delta/.08)
	super._process(delta)

func _evaluate(delta: float) -> void:
	super._evaluate(delta)
	if not jump_active or jump_pose==null or frozen: return
	var weight:=smoothstep(0.0,2.0/30.0,jump_time)*(1.0-smoothstep(jump_duration-4.0/30.0,jump_duration,jump_time))
	# The unarmed Action does not contain gun grips. Preserve the current arms,
	# recoil, WeaponCarrier and stow/draw layer while a gun is equipped.
	var preserve_grip:=_preserve_grip()
	var upper_heading:=_combat_bone_yaw(chest)
	for name in ["Hips","Leg.L","Leg.R","Spine","Chest","Neck","Head","Arm.L","Arm.R","ForeArm.L","ForeArm.R"]:
		# Moving reference clips keep alternating steps through the aerial arc.
		# The authored V002 held stride must not replace the continuous R15 gait.
		if jump_moving and name=="Hips":continue
		var moving_mask:=.10 if name in ["Leg.L","Leg.R"] else (.30 if name in ["Arm.L","Arm.R","ForeArm.L","ForeArm.R"] else .60)
		var bone_weight:=weight*(moving_mask if jump_moving else 1.0)
		if name in ["Arm.L","Arm.R","ForeArm.L","ForeArm.R"]:bone_weight*=jump_arm_weight
		if bone_weight<=0.0: continue
		var bone:=skeleton.find_bone(name)
		var p: Vector3=jump_pose.position(bone,jump_time)
		var q: Quaternion=jump_pose.rotation(bone,jump_time)
		if preserve_grip and name in ["Spine","Chest","Neck","Head"]:
			p=skeleton.get_bone_pose_position(bone)+p-jump_pose.position(bone,0.0)
			q=(skeleton.get_bone_pose_rotation(bone)*jump_pose.rotation(bone,0.0).inverse()*q).normalized()
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(p,bone_weight))
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(q,bone_weight).normalized())
	if jump_moving:
		# The source carrier correction belongs to its held leg pose. Recompute
		# support for the composed gait instead, using the actual rigid sole corners.
		skeleton.force_update_all_bone_transforms()
		var sole_y:=INF
		for leg in [leg_left,leg_right]:
			var pose:=skeleton.get_bone_global_pose(leg)
			for x in [-.1125,.1125]:
				for z in [-.1125,.1125]:sole_y=minf(sole_y,(pose*Vector3(x,.675,z)).y)
		var hip_position:=skeleton.get_bone_pose_position(hips)
		hip_position.y-=sole_y*weight
		skeleton.set_bone_pose_position(hips,hip_position)
	if combat_facing_active:
		_rotate_global(chest,Quaternion(Vector3.UP,wrapf(upper_heading-_combat_bone_yaw(chest),-PI,PI)))
		_limit_combat_twist()
	skeleton.force_update_all_bone_transforms()
	if socket!=null:
		socket.on_skeleton_update()
		if socket.carrier_socket!=null: socket.sync_transport_sockets()
