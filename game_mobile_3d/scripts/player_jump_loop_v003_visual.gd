extends "res://scripts/player_combat_strafe_r15.gd"
## Final layer of the existing pose writer. V003 legs are sampled at full weight.
var jump_active := false
var jump_time := 0.0
var jump_pose: RefCounted
var jump_arm_weight := 1.0
var jump_duration := 26.0/30.0
var jump_blend := 0.0
var _transition_pose:RefCounted
var _transition_time:=0.0
var _transition_elapsed:=1.0
const TRANSITION_DURATION:=4.0/30.0

func _is_additional_authored_bone(rig: Skeleton3D, bone: int) -> bool:
	var name:=rig.get_bone_name(bone)
	if name not in ["ForeArm.L","ForeArm.R"]:return false
	assert(rig.get_bone_name(rig.get_bone_parent(bone))=="Arm."+name.right(1))
	assert(rig.get_bone_rest(bone).is_equal_approx(Transform3D(Basis.IDENTITY,Vector3(0,.3375,0))),"Authored elbow rest mismatch")
	return true

func _ready() -> void:
	super._ready()
	jump_pose=samples["Jump_Stationary_v002"]

func select_jump(action: String, duration: float) -> void:
	if jump_pose!=null and jump_pose!=samples[action] and jump_blend>0.0:
		_transition_pose=jump_pose;_transition_time=jump_time;_transition_elapsed=0.0
	jump_pose=samples[action];jump_duration=duration

func set_jump_state(active: bool, time: float, immediate: bool=false) -> void:
	jump_active=active;jump_time=time
	if immediate:
		jump_blend=1.0 if active else 0.0
		_transition_pose=null

func _preserve_grip() -> bool:
	return weapon_equipped and (socket.current_attachment in [&"hand",&"carrier"] or r13_mode!=&"" or r13_exit_time>=0.0)

func _process(delta: float) -> void:
	if not frozen:
		_transition_elapsed+=delta
		if _transition_elapsed>=TRANSITION_DURATION:_transition_pose=null
		jump_blend=move_toward(jump_blend,1.0 if jump_active else 0.0,delta/(2.0/30.0 if jump_active else 4.0/30.0))
		if socket!=null:jump_arm_weight=move_toward(jump_arm_weight,0.0 if _preserve_grip() else 1.0,delta/.08)
	super._process(delta)

func _evaluate(delta: float) -> void:
	super._evaluate(delta)
	if jump_blend<=0.0 or jump_pose==null or frozen:return
	var weight:=smoothstep(0.0,1.0,jump_blend)
	var preserve_grip:=_preserve_grip()
	var upper_heading:=_combat_bone_yaw(chest)
	for name in ["Hips","Leg.L","Leg.R","Spine","Chest","Neck","Head","Arm.L","Arm.R","ForeArm.L","ForeArm.R"]:
		var bone_weight:=weight
		if name in ["Arm.L","Arm.R","ForeArm.L","ForeArm.R"]:bone_weight*=jump_arm_weight
		if bone_weight<=0.0:continue
		var bone:=skeleton.find_bone(name)
		var p:Vector3=jump_pose.position(bone,jump_time)
		var q:Quaternion=jump_pose.rotation(bone,jump_time)
		if preserve_grip and name in ["Spine","Chest","Neck","Head"]:
			p=skeleton.get_bone_pose_position(bone)+p-jump_pose.position(bone,0.0)
			q=(skeleton.get_bone_pose_rotation(bone)*jump_pose.rotation(bone,0.0).inverse()*q).normalized()
		if _transition_pose!=null:
			var old_p:Vector3=_transition_pose.position(bone,_transition_time)
			var old_q:Quaternion=_transition_pose.rotation(bone,_transition_time)
			if preserve_grip and name in ["Spine","Chest","Neck","Head"]:
				old_p=skeleton.get_bone_pose_position(bone)+old_p-_transition_pose.position(bone,0.0)
				old_q=(skeleton.get_bone_pose_rotation(bone)*_transition_pose.rotation(bone,0.0).inverse()*old_q).normalized()
			var u:=smoothstep(0.0,TRANSITION_DURATION,_transition_elapsed)
			p=old_p.lerp(p,u);q=old_q.slerp(q,u).normalized()
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(p,bone_weight))
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(q,bone_weight).normalized())
	# Support must correspond to the final blended pose, including armed torso.
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
		if socket.carrier_socket!=null:socket.sync_transport_sockets()
