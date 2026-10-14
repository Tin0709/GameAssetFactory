extends "res://scenes/dev/expressive_locomotion_visual.gd"
## Private gameplay research. Both moving motions are the immutable source studies.
const SOURCE_LIBRARY=preload("res://scenes/dev/actions_stuff_research/source_library.res")
const ClipSampler=preload("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd")
const RunSampler=preload("res://scenes/dev/actions_stuff_research/source_run_sampler.gd")
const WALK_SPEED:=1.8
const RUN_SPEED:=5.031
const WALK_PERIOD:=.8
const RUN_PERIOD:=.625
const WALK_RECEIVE:=.22
const RUN_RECEIVE:=.44
const SOLE_POINTS: Array[Vector3]=[Vector3(-.1125,.675,-.1125),Vector3(-.1125,.675,.1125),Vector3(.1125,.675,-.1125),Vector3(.1125,.675,.1125)]
var active_walk_action:="Walk_ActionsStuff_Source_Test_v001"
var active_run_action:="Run_ActionsStuff_Source_Test_v001"
var source_walk: RefCounted
var source_run: RefCounted
var entity_lifetime:=0.0
var released: Array[bool]=[false,false]
var rolling_corner: Array[int]=[-1,-1]
var rolling_anchor: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var rolling_offset: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var rolling_raw: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var rolling_used: Array[bool]=[false,false]
var release_offset: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var _scale_dirty:=true
var _scale_age:=10.0
var _scale_offset: Array[float]=[0.,0.]
var _scale_velocity_offset: Array[float]=[0.,0.]
var _scale_previous: Array[float]=[1.,1.]
var _scale_velocity: Array[float]=[0.,0.]
func _ready() -> void:
	super._ready()
	review_pace=1.
	source_walk=ClipSampler.new(SOURCE_LIBRARY.get_animation(active_walk_action),skeleton)
	source_run=RunSampler.new(skeleton)
	# Delete inherited moving sampler slots: no Expressive/Snappy moving fallback.
	expressive_clips.erase(EXPRESSIVE_NAMES[1]);expressive_clips.erase(EXPRESSIVE_NAMES[2])
	gait_phase=0.;gait_run_weight=0.;pose_dirty=true
	stance_duty=[.10,.10]
func drive_locomotion(world_velocity: Vector3,requested: bool,delta: float) -> void:
	_pending_physics_delta+=delta;entity_lifetime+=delta
	var planar:=Vector3(world_velocity.x,0,world_velocity.z)
	movement_speed=planar.length();var old_yaw:=rotation.y
	if movement_speed>.015:_advance_facing(atan2(planar.x,planar.z),delta)
	turn_rate=wrapf(rotation.y-old_yaw,-PI,PI)/maxf(delta,.001)
	var desired_run:=smoothstep(WALK_SPEED,RUN_SPEED,movement_speed)
	gait_run_weight=move_toward(gait_run_weight,desired_run,delta/.22)
	var old_move:=move_requested;move_requested=requested or movement_speed>.025
	if old_move!=move_requested:_scale_dirty=true;pose_dirty=true;transition_count+=1
	if move_requested and not old_move:
		settling=false;gait_phase=.5 if next_left else 0.;next_left=not next_left
		foot_support=[false,false];released=[false,false];rolling_corner=[-1,-1]
		stance_duty=[lerpf(.10,.26,gait_run_weight),lerpf(.10,.26,gait_run_weight)]
		support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
	if not move_requested and old_move:
		settling=true;settle_time=0.;attention_time=0.
		replant_first=0 if last_sole[0].y>last_sole[1].y else 1
		for side in 2:replant_from[side]=last_sole[side];replant_q[side]=_leg_world_rotation([leg_left,leg_right][side])
	var previous:=gait_phase
	# Original periods at nominal travel, distance-locked only below nominal speed.
	gait_frequency=movement_speed/lerpf(WALK_SPEED*WALK_PERIOD,RUN_SPEED*RUN_PERIOD,gait_run_weight)
	if move_requested:gait_phase=fposmod(gait_phase+delta*gait_frequency,1.)
	for side in 2:
		var local_phase:=fposmod(gait_phase-side*.5,1.)
		var duty:=lerpf(.10,.26,gait_run_weight)
		if local_phase<fposmod(previous-side*.5,1.):released[side]=false;stance_duty[side]=duty
		else:stance_duty[side]=minf(stance_duty[side],duty)
		if local_phase>=stance_duty[side]:released[side]=true
	if settling:settle_time=minf(settle_time+delta,REPLANT_SECONDS)
	elif not move_requested:attention_time=fposmod(attention_time+delta,8.)
	reference_phase=gait_phase;reference_sprint_weight=gait_run_weight
	support_left=_support(0);support_right=_support(1)
func _support(side: int) -> bool:
	if not move_requested:return true
	return not released[side] and fposmod(gait_phase-side*.5,1.)<stance_duty[side]
func _target_pose(bone: int,ahead: float=0.) -> Transform3D:
	if source_run==null or not move_requested:return super._target_pose(bone,ahead)
	var phase:=fposmod(gait_phase+ahead*gait_frequency,1.)
	source_run.set_clocks(phase+RUN_RECEIVE,entity_lifetime+ahead)
	var time:=fposmod(phase+WALK_RECEIVE,1.)*WALK_PERIOD
	var q: Quaternion=source_walk.rotation(bone,time).slerp(source_run.rotation(bone),gait_run_weight).normalized()
	var p: Vector3=source_walk.position(bone,time).lerp(source_run.position(bone),gait_run_weight)
	if bone==hips:
		# Constant preview-floor alignment only. Raw imported clips stay unchanged.
		var parent:=skeleton.get_bone_parent(bone)
		var parent_basis:=skeleton.global_basis
		if parent>=0:parent_basis*=skeleton.get_bone_global_pose(parent).basis
		p+=parent_basis.inverse()*Vector3.UP*lerpf(.038,.03367406875,gait_run_weight)
	return Transform3D(Basis(q),p)
func _target_leg_scale(bone: int,ahead: float=0.) -> float:
	if source_run==null or not move_requested:return 1.
	source_run.set_clocks(gait_phase+ahead*gait_frequency+RUN_RECEIVE,entity_lifetime+ahead)
	return lerpf(1.,source_run.scale(bone).y,gait_run_weight)
func _apply_source_scales(delta: float) -> void:
	if source_run==null:return
	if _scale_dirty:
		_scale_age=0.;_scale_dirty=false
		for side in 2:
			var bone: int=[leg_left,leg_right][side];var target:=_target_leg_scale(bone)
			_scale_offset[side]=skeleton.get_bone_pose_scale(bone).y-target
			_scale_velocity_offset[side]=_scale_velocity[side]-(_target_leg_scale(bone,.004)-target)/.004
	_scale_age+=delta
	for side in 2:
		var bone: int=[leg_left,leg_right][side]
		var residual:=(_scale_offset[side]+(_scale_velocity_offset[side]+22.*_scale_offset[side])*_scale_age)*exp(-22.*_scale_age)
		var value:=clampf(_target_leg_scale(bone)+residual,1.,1.07)
		_scale_velocity[side]=(value-_scale_previous[side])/maxf(delta,.00001);_scale_previous[side]=value
		skeleton.set_bone_pose_scale(bone,Vector3(1,value,1))
func _evaluate_locomotion_pose(delta: float) -> bool:
	_apply_source_scales(delta)
	return super._evaluate_locomotion_pose(delta)
func _leg_world_rotation(bone: int) -> Quaternion:
	return (skeleton.global_basis*skeleton.get_bone_global_pose(bone).basis).orthonormalized().get_rotation_quaternion().normalized()
func _set_world_leg_rotation(bone: int,q: Quaternion) -> void:
	var parent:=skeleton.get_bone_parent(bone)
	var parent_q: Quaternion=(skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis).orthonormalized().get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone,(parent_q.inverse()*q).normalized());skeleton.force_update_all_bone_transforms()
func _contact_leg_rotation(side: int,bone: int,target: Vector3,original_q: Quaternion,delta: float) -> Quaternion:
	if not move_requested or absf(turn_rate)>.5 or transition_age<.18:
		rolling_used[side]=false;rolling_corner[side]=-1
		return super._contact_leg_rotation(side,bone,target,original_q,delta)
	var transform:=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
	var index:=0;var lowest:=INF
	for i in 4:
		var y: float=(transform*SOLE_POINTS[i]).y
		if y<lowest:lowest=y;index=i
	var corner: Vector3=transform*SOLE_POINTS[index];var center: Vector3=transform*Vector3(0,.675,0)
	if not foot_support[side] or rolling_corner[side]<0:rolling_anchor[side]=corner;rolling_offset[side]=Vector3.ZERO
	elif index!=rolling_corner[side]:rolling_anchor[side]=corner+rolling_offset[side]
	rolling_corner[side]=index;rolling_used[side]=true;rolling_raw[side]=_sole_world(bone)
	foot_anchors[side]=Vector3(rolling_anchor[side].x+center.x-corner.x,0.,rolling_anchor[side].z+center.z-corner.z)
	support_aim[side]=Quaternion.IDENTITY
	return original_q
func _swing_leg_rotation(side: int,bone: int,delta: float) -> Quaternion:
	if foot_support[side]:release_offset[side]=rolling_offset[side]
	release_offset[side]*=exp(-30.*delta)
	var parent_basis:=skeleton.global_basis*skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
	skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone)+parent_basis.inverse()*release_offset[side])
	return super._swing_leg_rotation(side,bone,delta)
func _limit_contact_correction(correction: Vector3) -> Vector3:
	# A pivot can exhaust horizontal reach. Preserve floor clearance first,
	# then fit XZ within the same rigid-joint translation budget.
	var y:=clampf(correction.y,-.14,.14)
	var planar:=Vector2(correction.x,correction.z).limit_length(sqrt(maxf(0.,.14*.14-y*y)))
	return Vector3(planar.x,y,planar.y)
func contact_point(side: int) -> Vector3:
	var bone: int=[leg_left,leg_right][side]
	if not rolling_used[side]:return _sole_world(bone)
	return (skeleton.global_transform*skeleton.get_bone_global_pose(bone))*SOLE_POINTS[rolling_corner[side]]
func _evaluate(delta: float) -> void:
	var previous_sequence:=pose_sequence
	super._evaluate(delta)
	if pose_sequence==previous_sequence:return
	for side in 2:
		if rolling_used[side] and foot_support[side]:rolling_offset[side]=last_sole[side]-rolling_raw[side]
		elif not foot_support[side]:rolling_used[side]=false;rolling_corner[side]=-1
	if settling and settle_time>=REPLANT_SECONDS:settling=false;foot_support=[true,true]
func reset_contacts() -> void:
	move_requested=false;settling=false;gait_run_weight=0.;gait_frequency=0.;pose_dirty=true;_scale_dirty=true
	rolling_corner=[-1,-1];rolling_used=[false,false];rolling_offset=[Vector3.ZERO,Vector3.ZERO];release_offset=[Vector3.ZERO,Vector3.ZERO]
	foot_support=[false,false];support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY];released=[false,false]
