extends "res://scripts/player_combat_strafe_r15.gd"
## One pose writer, approved full-body clips below unchanged R13/R15 upper layers.
const APPROVED=preload("res://assets/characters/expressive_locomotion_v1/approved_library.res")
const EXPRESSIVE_NAMES=["Idle_Expressive_Test_v3","Walk_Expressive_Test","Run_Expressive_v3_Test"]
const WALK_STRIDE:=1.08
const RUN_STRIDE:=1.54
const REPLANT_SECONDS:=.44
var review_pace:=1.5
var expressive_clips: Dictionary={}
var gait_phase:=.28
var gait_run_weight:=0.0
var gait_frequency:=0.0
var attention_time:=0.0
var move_requested:=false
var settling:=false
var settle_time:=0.0
var replant_first:=0
var next_left:=true
var pose_dirty:=false
var transition_age:=10.0
var _p: Array[Vector3]=[]
var _q: Array[Quaternion]=[]
var _vp: Array[Vector3]=[]
var _vq: Array[Vector3]=[]
var _offset_p: Array[Vector3]=[]
var _offset_q: Array[Vector3]=[]
var _offset_vp: Array[Vector3]=[]
var _offset_vq: Array[Vector3]=[]
var foot_anchors: Array[Vector3]=[]
var foot_rotations: Array[Quaternion]=[]
var support_aim: Array[Quaternion]=[Quaternion.IDENTITY,Quaternion.IDENTITY]
var foot_support: Array[bool]=[true,true]
var contact_ids: Array[int]=[0,0]
var stance_duty: Array[float]=[.60,.62]
var weapon_rotation_offsets: Array[Vector3]=[]
var weapon_base_p: Array[Vector3]=[]
var weapon_base_q: Array[Quaternion]=[]
var weapon_position_offsets: Array[Vector3]=[]
var _final_p: Array[Vector3]=[]
var _final_q: Array[Quaternion]=[]
var _final_vp: Array[Vector3]=[]
var _final_vq: Array[Vector3]=[]
var replant_from: Array[Vector3]=[]
var replant_q: Array[Quaternion]=[]
var last_sole: Array[Vector3]=[]
var contact_drift:=0.0
var maximum_correction:=0.0
var correction_clamps:=0
var transition_count:=0
var _pending_physics_delta:=0.0
var pose_sequence:=0
var pose_delta:=1.0/60.0
var review_weapon_weight:=0.0
var support_left:=true
var support_right:=true

func _is_additional_authored_bone(rig: Skeleton3D, bone: int) -> bool:
	return rig.get_bone_name(bone) in ["ForeArm.L","ForeArm.R"]
func _ready() -> void:
	super._ready()
	# The reused runtime atlas is VRAM-compressed and damages 64px face colors.
	# Use an exact, lossless test-only atlas on instance-local material copies.
	var atlas:=load("res://assets/characters/expressive_locomotion_v1/approved_atlas_64.png") as Texture2D
	for instance in meshes:
		for surface in instance.mesh.get_surface_count():
			var material: BaseMaterial3D=instance.mesh.surface_get_material(surface).duplicate()
			material.albedo_texture=atlas;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
			instance.set_surface_override_material(surface,material)
	for name in EXPRESSIVE_NAMES:
		expressive_clips[name]=Sampler.new(APPROVED.get_animation(name),skeleton)
	for i in skeleton.get_bone_count():
		_p.append(skeleton.get_bone_rest(i).origin);_q.append(skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
		_vp.append(Vector3.ZERO);_vq.append(Vector3.ZERO)
		_offset_p.append(Vector3.ZERO);_offset_q.append(Vector3.ZERO);_offset_vp.append(Vector3.ZERO);_offset_vq.append(Vector3.ZERO)
		_final_p.append(_p[i]);_final_q.append(_q[i]);_final_vp.append(Vector3.ZERO);_final_vq.append(Vector3.ZERO)
	bounce_enabled=false
	for bone in r13_mask:
		weapon_rotation_offsets.append(Vector3.ZERO);weapon_position_offsets.append(Vector3.ZERO);weapon_base_p.append(Vector3.ZERO);weapon_base_q.append(Quaternion.IDENTITY)
	_evaluate(0.0)
	for bone in [leg_left,leg_right]:
		foot_anchors.append(_sole_world(bone));foot_rotations.append(_leg_world_rotation(bone))
		replant_from.append(_sole_world(bone));replant_q.append(_leg_world_rotation(bone));last_sole.append(_sole_world(bone))
		_final_p[bone]=skeleton.get_bone_pose_position(bone);_final_q[bone]=skeleton.get_bone_pose_rotation(bone)

func drive_locomotion(world_velocity: Vector3, requested: bool, delta: float) -> void:
	_pending_physics_delta+=delta
	var planar:=Vector3(world_velocity.x,0,world_velocity.z)
	movement_speed=planar.length()
	var old_yaw:=rotation.y
	if movement_speed>.015:
		var target_yaw:=atan2(planar.x,planar.z)
		rotation.y+=clampf(wrapf(target_yaw-rotation.y,-PI,PI),-4.5*review_pace*delta,4.5*review_pace*delta)
	turn_rate=wrapf(rotation.y-old_yaw,-PI,PI)/maxf(delta,.001)
	# Pose blend is speed based, not a button-state crossfade. Both clocks share phase.
	var desired_run:=smoothstep(.9,2.31,movement_speed/review_pace)
	gait_run_weight=move_toward(gait_run_weight,desired_run,delta*review_pace/0.12)
	var was_moving:=move_requested
	move_requested=requested or movement_speed>.025
	if move_requested and not was_moving:
		settling=false;pose_dirty=true;transition_count+=1
		support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
		# Pick a swing foot only at a planted idle start. Never reset a moving gait.
		gait_phase=.80 if next_left else .28;next_left=not next_left
		if last_sole[0].y>.006:gait_phase=.80
		elif last_sole[1].y>.006:gait_phase=.28
		stance_duty=[lerpf(.60,.42,gait_run_weight),lerpf(.62,.43,gait_run_weight)]
		foot_support=[false,false]
		contact_ids[0]+=1;contact_ids[1]+=1
	if not move_requested and was_moving:
		settling=true;settle_time=0.0;attention_time=0.0;pose_dirty=true;transition_count+=1
		support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
		replant_first=0 if last_sole[0].y>last_sole[1].y else 1
		for i in 2:
			replant_from[i]=last_sole[i];replant_q[i]=_leg_world_rotation([leg_left,leg_right][i])
	# Distance locking scales cadence below either nominal speed, including decel.
	gait_frequency=movement_speed/_stride_distance()
	if move_requested:
		var previous_phase:=gait_phase
		gait_phase=fposmod(gait_phase+delta*gait_frequency,1.0)
		for side in 2:
			if fposmod(gait_phase-side*.5,1.0)<fposmod(previous_phase-side*.5,1.0):
				# Latch duty at receiving contact. Deceleration must not turn a
				# foot already in flight back into support halfway through swing.
				stance_duty[side]=lerpf(.60 if side==0 else .62,.42 if side==0 else .43,gait_run_weight)
			else:
				# Accelerating may release support earlier as Run gains weight.
				# Never prolong a contact into the airborne Run pose; decelerating
				# still cannot re-ground a foot that has already left support.
				stance_duty[side]=minf(stance_duty[side],lerpf(.60 if side==0 else .62,.42 if side==0 else .43,gait_run_weight))
	reference_phase=gait_phase;reference_sprint_weight=gait_run_weight
	if settling:
		settle_time+=delta*review_pace
		if settle_time>=REPLANT_SECONDS:settling=false;foot_support=[true,true]
	elif not move_requested:attention_time=fposmod(attention_time+delta,8.0)
	support_left=_support(0);support_right=_support(1)

func _stride_distance() -> float:
	return lerpf(WALK_STRIDE,RUN_STRIDE,gait_run_weight)

func _support(side: int) -> bool:
	if not move_requested:return true
	var phase:=fposmod(gait_phase-side*.5,1.0)
	return phase<stance_duty[side]

func _target_pose(bone: int, ahead: float=0.0) -> Transform3D:
	if not move_requested:
		var clip: RefCounted=expressive_clips[EXPRESSIVE_NAMES[0]]
		return Transform3D(Basis(clip.rotation(bone,fposmod(attention_time+ahead,8.0))),clip.position(bone,fposmod(attention_time+ahead,8.0)))
	var wp: RefCounted=expressive_clips[EXPRESSIVE_NAMES[1]]
	var rp: RefCounted=expressive_clips[EXPRESSIVE_NAMES[2]]
	var phase:=fposmod(gait_phase+ahead*gait_frequency,1.0)
	return Transform3D(Basis(wp.rotation(bone,phase*wp.clip.length).slerp(rp.rotation(bone,phase*rp.clip.length),gait_run_weight).normalized()),wp.position(bone,phase*wp.clip.length).lerp(rp.position(bone,phase*rp.clip.length),gait_run_weight))

func _r13_reference_pose(bone: int) -> Transform3D:
	if expressive_clips.is_empty():return super._r13_reference_pose(bone)
	return Transform3D(Basis(_q[bone]),_p[bone])

func _r13_pose(kind: String, bone: int) -> Transform3D:
	var old_phase:=reference_phase;var old_run:=reference_sprint_weight
	reference_phase=gait_phase;reference_sprint_weight=gait_run_weight
	var result:=super._r13_pose(kind,bone)
	reference_phase=old_phase;reference_sprint_weight=old_run
	return result

func _process(delta: float) -> void:
	review_weapon_weight=move_toward(review_weapon_weight,1.0 if weapon_equipped else 0.0,delta*review_pace/.30)
	super._process(delta)

func _apply_weapon_carry() -> void:
	if expressive_clips.is_empty():super._apply_weapon_carry();return
	for i in r13_mask.size():
		weapon_base_p[i]=skeleton.get_bone_pose_position(r13_mask[i]);weapon_base_q[i]=skeleton.get_bone_pose_rotation(r13_mask[i])
	if not weapon_equipped:
		var exit_weight:=smoothstep(0,1,review_weapon_weight)
		for i in r13_mask.size():
			var bone:=r13_mask[i]
			skeleton.set_bone_pose_position(bone,weapon_base_p[i]+weapon_position_offsets[i]*exit_weight)
			skeleton.set_bone_pose_rotation(bone,(_from_rotvec(weapon_rotation_offsets[i]*exit_weight)*weapon_base_q[i]).normalized())
		return
	var equipped:=weapon_equipped;weapon_equipped=true
	super._apply_weapon_carry();weapon_equipped=equipped
	var weight:=smoothstep(0,1,review_weapon_weight)
	for i in r13_mask.size():
		var bone:=r13_mask[i]
		var offset:=_rotvec(skeleton.get_bone_pose_rotation(bone)*weapon_base_q[i].inverse())
		if offset.length()>.0001:
			var alternate:=offset-offset.normalized()*TAU
			if alternate.distance_squared_to(weapon_rotation_offsets[i])<offset.distance_squared_to(weapon_rotation_offsets[i]):offset=alternate
		weapon_rotation_offsets[i]=offset
		weapon_position_offsets[i]=skeleton.get_bone_pose_position(bone)-weapon_base_p[i]
		skeleton.set_bone_pose_position(bone,weapon_base_p[i].lerp(skeleton.get_bone_pose_position(bone),weight))
		skeleton.set_bone_pose_rotation(bone,(_from_rotvec(offset*weight)*weapon_base_q[i]).normalized())

func _rotvec(q: Quaternion) -> Vector3:
	var value:=q.normalized()
	if value.w<0:value=-value
	return value.get_axis()*value.get_angle() if value.get_angle()>.000001 else Vector3.ZERO
func _from_rotvec(v: Vector3) -> Quaternion:
	return Quaternion(v.normalized(),v.length()) if v.length()>.000001 else Quaternion.IDENTITY

func _evaluate_locomotion_pose(delta: float) -> bool:
	if expressive_clips.is_empty():return super._evaluate_locomotion_pose(delta)
	if pose_dirty:
		transition_age=0.0
		for i in skeleton.get_bone_count():
			var target:=_target_pose(i);var future:=_target_pose(i,.004)
			var planted:=i==leg_left or i==leg_right
			var current_p:=skeleton.get_bone_pose_position(i) if planted else _p[i]
			var current_q:=skeleton.get_bone_pose_rotation(i) if planted else _q[i]
			_offset_p[i]=current_p-target.origin
			_offset_q[i]=_rotvec(current_q*target.basis.get_rotation_quaternion().inverse())
			_offset_vp[i]=(_final_vp[i] if planted else _vp[i])-(future.origin-target.origin)/.004
			_offset_vq[i]=(_final_vq[i] if planted else _vq[i])-_rotvec(future.basis.get_rotation_quaternion()*target.basis.get_rotation_quaternion().inverse())/.004
		pose_dirty=false
	transition_age+=delta
	var damping:=(24.0 if move_requested else 18.0)*review_pace
	var falloff:=exp(-damping*transition_age)
	for i in skeleton.get_bone_count():
		var target:=_target_pose(i)
		var p:=target.origin+(_offset_p[i]+(_offset_vp[i]+damping*_offset_p[i])*transition_age)*falloff
		var r:=(_offset_q[i]+(_offset_vq[i]+damping*_offset_q[i])*transition_age)*falloff
		var q:=(_from_rotvec(r)*target.basis.get_rotation_quaternion()).normalized()
		if delta>.00001:
			_vp[i]=(p-_p[i])/delta;_vq[i]=_rotvec(q*_q[i].inverse())/delta
		_p[i]=p;_q[i]=q
		skeleton.set_bone_pose_position(i,p);skeleton.set_bone_pose_rotation(i,q)
	if review_weapon_weight>0:_apply_firing_recoil();_apply_weapon_carry()
	return true

func _sole_world(bone: int) -> Vector3:
	var transform:=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
	var center:=transform*Vector3(0,.675,0)
	var lowest:=INF
	for x in [-.1125,.1125]:
		for z in [-.1125,.1125]:lowest=minf(lowest,(transform*Vector3(x,.675,z)).y)
	return Vector3(center.x,lowest,center.z)
func _leg_world_rotation(bone: int) -> Quaternion:
	return (skeleton.global_basis*skeleton.get_bone_global_pose(bone).basis).get_rotation_quaternion().normalized()

func _evaluate(delta: float) -> void:
	if not expressive_clips.is_empty() and foot_anchors.size()==2:
		# A free-running render loop may evaluate many times per physics step.
		# Derivatives must use the time advanced by the gait, not a tiny render dt.
		if _pending_physics_delta<=0:return
		delta=_pending_physics_delta;_pending_physics_delta=0.0
		pose_sequence+=1;pose_delta=delta
	super._evaluate(delta)
	if expressive_clips.is_empty() or foot_anchors.size()!=2:return
	skeleton.force_update_all_bone_transforms()
	for side in 2:
		var bone: int=[leg_left,leg_right][side]
		var support:=_support(side)
		var sole:=_sole_world(bone)
		var target:=sole
		if settling:
			# Sequential lift/replant: never translate two planted feet into Idle.
			var order:=0 if side==replant_first else 1
			var u:=clampf((settle_time-order*REPLANT_SECONDS*.5)/(REPLANT_SECONDS*.5),0,1)
			var eased:=u*u*u*(10+u*(-15+6*u))
			# Current uncorrected destination tends to the exact approved Idle pose.
			target=replant_from[side].lerp(Vector3(sole.x,0,sole.z),eased)
			target.y=lerpf(replant_from[side].y,0,eased)+sin(PI*u)*.035
			var global_q:=replant_q[side].slerp(_leg_world_rotation(bone),eased).normalized()
			_set_world_leg_rotation(bone,global_q)
			sole=_sole_world(bone)
			foot_anchors[side]=target;foot_rotations[side]=global_q
		elif support:
			if not foot_support[side]:
				foot_anchors[side]=Vector3(sole.x,0,sole.z);foot_rotations[side]=_leg_world_rotation(bone)
				contact_ids[side]+=1
			target=foot_anchors[side]
			# During stance changes/pivots, articulate the existing single rigid
			# leg toward support before applying the small remaining translation.
			# This is a one-link adjustment, with no invented knee/ankle or scale.
			var original_q:=_leg_world_rotation(bone)
			_set_world_leg_rotation(bone,_contact_leg_rotation(side,bone,target,original_q,delta))
			target=foot_anchors[side]
			sole=_sole_world(bone)
		else:
			_set_world_leg_rotation(bone,_swing_leg_rotation(side,bone,delta))
			sole=_sole_world(bone);target=sole
			target.y=maxf(sole.y,0.0)
		foot_support[side]=support
		var correction:=target-sole
		maximum_correction=maxf(maximum_correction,correction.length())
		# Rigid leg translations only. Large pivot/micro-tap corrections release
		# safely instead of pulling the hip joint apart; exposed in test metrics.
		if correction.length()>.14:
			correction=_limit_contact_correction(correction);correction_clamps+=1
			foot_anchors[side]=sole+correction
		var parent:=skeleton.get_bone_parent(bone)
		var parent_basis:=skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone)+parent_basis.inverse()*correction)
		skeleton.force_update_all_bone_transforms()
		var corrected:=_sole_world(bone)
		contact_drift=maxf(contact_drift,(corrected-target).length() if support and not settling else 0.0)
		last_sole[side]=corrected
		var p:=skeleton.get_bone_pose_position(bone);var q:=skeleton.get_bone_pose_rotation(bone)
		if delta>0:
			_final_vp[bone]=(p-_final_p[bone])/delta;_final_vq[bone]=_rotvec(q*_final_q[bone].inverse())/delta
		_final_p[bone]=p;_final_q[bone]=q
	if socket!=null:socket.on_skeleton_update();socket.sync_transport_sockets()

func _limit_contact_correction(correction: Vector3) -> Vector3:
	return correction.limit_length(.14)

func _contact_leg_rotation(side: int, bone: int, target: Vector3, original_q: Quaternion, delta: float) -> Quaternion:
	var aim:=Quaternion.IDENTITY
	if transition_age<.45/review_pace or absf(turn_rate)>.3*review_pace:
		var global_pose:=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
		var sole:=_sole_world(bone)
		var sole_center:=global_pose*Vector3(0,.675,0)
		var destination:=target+Vector3(0,sole_center.y-sole.y,0)
		aim=Quaternion(global_pose.basis.y.normalized(),(destination-global_pose.origin).normalized()).normalized()
	support_aim[side]=support_aim[side].slerp(aim,1.0-exp(-20*review_pace*delta)).normalized()
	return (support_aim[side]*original_q).normalized()

func _swing_leg_rotation(side: int, bone: int, delta: float) -> Quaternion:
	support_aim[side]=support_aim[side].slerp(Quaternion.IDENTITY,1.0-exp(-25*review_pace*delta)).normalized()
	return (support_aim[side]*_leg_world_rotation(bone)).normalized()

func _set_world_leg_rotation(bone: int, q: Quaternion) -> void:
	var parent:=skeleton.get_bone_parent(bone)
	var parent_q: Quaternion=(skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone,(parent_q.inverse()*q).normalized())
	skeleton.force_update_all_bone_transforms()
