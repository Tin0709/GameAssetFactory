extends "res://scenes/dev/expressive_locomotion_visual.gd"
## Private gameplay research. Immutable source studies plus a separate unarmed gameplay profile.
const SOURCE_LIBRARY=preload("res://scenes/dev/actions_stuff_research/source_library.res")
const ClipSampler=preload("res://scenes/dev/actions_stuff_research/source_clip_sampler.gd")
const RunSampler=preload("res://scenes/dev/actions_stuff_research/source_run_sampler.gd")
const DirectionController=preload("res://scenes/dev/actions_stuff_research/source_direction_controller.gd")
const DirectionSampler=preload("res://scenes/dev/actions_stuff_research/source_direction_sampler.gd")
const UNARMED_PROFILE_PATH:="res://scenes/dev/actions_stuff_research/unarmed_gameplay_v001.json"
const WALK_SPEED:=1.8
const RUN_SPEED:=5.031
const WALK_PERIOD:=.8
const RUN_PERIOD:=.625
const WALK_RECEIVE:=.22
const RUN_RECEIVE:=.44
const SOLE_POINTS: Array[Vector3]=[Vector3(-.1125,.675,-.1125),Vector3(-.1125,.675,.1125),Vector3(.1125,.675,-.1125),Vector3(.1125,.675,.1125)]
var active_walk_action:="Walk_ActionsStuff_Source_Test_v001"
var active_run_action:="Run_ActionsStuff_Source_Test_v001"
var gameplay_walk_version: String
var gameplay_run_version: String
var source_walk: RefCounted
var source_run: RefCounted
var direction_controller: RefCounted
var direction_sampler: RefCounted
var direction_future_sampler: RefCounted
var direction_snapshot: Dictionary={}
var direction_poses: Array=[]
var direction_future_poses: Array=[]
# Engine query adapter: face travel like the original controller; the source
# directional clips handle the temporary mismatch while the character turns.
var look_yaw:=PI
var _previous_look_yaw:=PI
var _previous_body_yaw:=PI
var _virtual_query_position:=Vector3.ZERO
var _source_support: Array[bool]=[false,false]
var _support_rearmed: Array[bool]=[true,true]
var _source_sole_previous: Array[float]=[0.,0.]
var _support_elapsed: Array[float]=[0.,0.]
var _release_phase: Array[float]=[-1.,-1.]
var _source_clearance: Array[float]=[0.,0.]
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
	direction_controller=DirectionController.new(12.)
	direction_controller.seed_heading(-rad_to_deg(look_yaw))
	direction_sampler=DirectionSampler.new(skeleton)
	direction_future_sampler=DirectionSampler.new(skeleton)
	var gameplay_profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(UNARMED_PROFILE_PATH))
	gameplay_walk_version=gameplay_profile.walk.name
	gameplay_run_version=gameplay_profile.run.name
	for sampler in [direction_sampler,direction_future_sampler]:
		sampler.set_item_holding(float(gameplay_profile.holding.right),float(gameplay_profile.holding.left))
	rotation.y=look_yaw
	direction_snapshot=direction_controller.step({"position":Vector3.ZERO,"movement_direction":Vector3.ZERO,"head_y_rotation":-rad_to_deg(look_yaw),"body_y_rotation":-rad_to_deg(look_yaw)},1./60.)
	entity_lifetime=direction_snapshot.life
	_cache_direction_poses()
	_initialize_source_contacts()

func _initialize_source_contacts() -> void:
	# The inherited setup predates the source engine yaw/pose. Rebase before the
	# first visible frame, so old Idle world anchors cannot pull feet across 180°.
	position.y=direction_sampler.height_offset(direction_snapshot)
	for i in skeleton.get_bone_count():
		var pose: Transform3D=direction_poses[i]
		var q:=pose.basis.orthonormalized().get_rotation_quaternion().normalized()
		skeleton.set_bone_pose_position(i,pose.origin);skeleton.set_bone_pose_rotation(i,q);skeleton.set_bone_pose_scale(i,pose.basis.get_scale())
		_p[i]=pose.origin;_q[i]=q;_final_p[i]=pose.origin;_final_q[i]=q
		_vp[i]=Vector3.ZERO;_vq[i]=Vector3.ZERO;_final_vp[i]=Vector3.ZERO;_final_vq[i]=Vector3.ZERO
		_offset_p[i]=Vector3.ZERO;_offset_q[i]=Vector3.ZERO;_offset_vp[i]=Vector3.ZERO;_offset_vq[i]=Vector3.ZERO
	skeleton.force_update_all_bone_transforms()
	for side in 2:
		var bone: int=[leg_left,leg_right][side];var sole:=_sole_world(bone);var q:=_leg_world_rotation(bone)
		foot_anchors[side]=Vector3(sole.x,0,sole.z);foot_rotations[side]=q
		replant_from[side]=sole;replant_q[side]=q;last_sole[side]=sole
		_source_sole_previous[side]=sole.y
	foot_support=[false,false];_source_support=[true,true];pose_dirty=false;_scale_dirty=false
	transition_age=10.;contact_drift=0.;maximum_correction=0.;correction_clamps=0
func drive_locomotion(world_velocity: Vector3,requested: bool,delta: float) -> void:
	if direction_controller==null:return
	_pending_physics_delta+=delta
	var planar:=Vector3(world_velocity.x,0,world_velocity.z)
	movement_speed=planar.length()
	var was_moving:=move_requested
	move_requested=requested or movement_speed>.025
	if was_moving!=move_requested:
		pose_dirty=true;_scale_dirty=true;transition_count+=1
	if move_requested and not was_moving:
		settling=false;foot_support=[false,false];_source_support=[false,false]
		_support_rearmed=[true,true];released=[false,false];rolling_corner=[-1,-1]
		support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
	if not move_requested and was_moving:
		settling=true;settle_time=0.;attention_time=0.
		replant_first=0 if last_sole[0].y>last_sole[1].y else 1
		for side in 2:replant_from[side]=last_sole[side];replant_q[side]=_leg_world_rotation([leg_left,leg_right][side])
	# Actual movement supplies direction. Unit calibration retains the established
	# Walk/Run travel speeds while feeding the source's own esnrkj speed filter.
	var query_speed:=movement_speed/WALK_SPEED*(4.3*.6103515625)
	if movement_speed>WALK_SPEED:query_speed=lerpf(4.3*.6103515625,5.59,clampf((movement_speed-WALK_SPEED)/(RUN_SPEED-WALK_SPEED),0,1))
	var direction:=planar.normalized() if movement_speed>.00001 else Vector3.ZERO
	if movement_speed>.015:
		_advance_facing(atan2(planar.x,planar.z),delta)
		look_yaw=rotation.y
	var yaw_rate: float=-rad_to_deg(wrapf(look_yaw-_previous_look_yaw,-PI,PI))/maxf(delta,.00001)
	_previous_look_yaw=look_yaw;rotation.y=look_yaw
	# Match approved study's 60Hz authored Euler updates at either render rate.
	var count:=maxi(1,ceili(delta*60.-.000001));var step:=delta/count
	for i in count:
		_virtual_query_position+=direction*query_speed*step
		direction_snapshot=direction_controller.step({"position":_virtual_query_position,"movement_direction":direction,"head_y_rotation":wrapf(-rad_to_deg(look_yaw),-180.,180.),"body_y_rotation":-rad_to_deg(look_yaw),"yaw_speed":yaw_rate,"target_x_rotation":0.},step)
	entity_lifetime=direction_snapshot.life
	gait_phase=fposmod(direction_snapshot.phase,1.);gait_frequency=direction_snapshot.cadence;gait_run_weight=direction_snapshot.run_weight
	var body_yaw: float=-deg_to_rad(direction_snapshot.vars["v.nthjcy"])
	turn_rate=wrapf(body_yaw-_previous_body_yaw,-PI,PI)/maxf(delta,.00001);_previous_body_yaw=body_yaw
	_cache_direction_poses()
	# Keep the source height field through release; its activation already decays.
	position.y=direction_sampler.height_offset(direction_snapshot)
	_update_direction_support(delta)
	if settling:settle_time=minf(settle_time+delta,REPLANT_SECONDS)
	elif not move_requested:attention_time=fposmod(attention_time+delta,8.)
	reference_phase=gait_phase;reference_sprint_weight=gait_run_weight
	support_left=_support(0);support_right=_support(1)

func _cache_direction_poses() -> void:
	direction_sampler.set_snapshot(direction_snapshot)
	direction_poses=direction_sampler.poses.duplicate()
	if pose_dirty or _scale_dirty or direction_future_poses.is_empty():
		var future:=direction_snapshot.duplicate(true)
		future.phase+=.004*float(future.cadence);future.life+=.004
		direction_future_sampler.set_snapshot(future)
		direction_future_poses=direction_future_sampler.poses.duplicate()

func _source_global_pose(bone: int) -> Transform3D:
	var pose: Transform3D=direction_poses[bone]
	var parent:=skeleton.get_bone_parent(bone)
	while parent>=0:
		pose=Transform3D(direction_poses[parent])*pose;parent=skeleton.get_bone_parent(parent)
	return skeleton.global_transform*pose

func _foot_yaw(q: Quaternion) -> float:
	var axis:=Basis(q).z
	return atan2(axis.x,axis.z)

func _update_direction_support(delta: float) -> void:
	# Scene-owned contact eligibility, not a proprietary controller/IK claim.
	# A free leg must approach the floor before it can acquire a world anchor.
	for side in 2:
		if not move_requested:_source_support[side]=true;continue
		var bone: int=[leg_left,leg_right][side];var pose:=_source_global_pose(bone)
		var height:=INF
		for point in SOLE_POINTS:height=minf(height,(pose*point).y)
		var rise:=height-_source_sole_previous[side];_source_sole_previous[side]=height;_source_clearance[side]=height
		_support_elapsed[side]+=delta
		var yaw_gap:=0.
		if foot_support[side]:yaw_gap=absf(wrapf(_foot_yaw(pose.basis.orthonormalized().get_rotation_quaternion())-_foot_yaw(foot_rotations[side]),-PI,PI))
		var raw_center:=pose*Vector3(0,.675,0)
		var reach:=Vector2(raw_center.x-foot_anchors[side].x,raw_center.z-foot_anchors[side].z).length()
		# Release before exhausting the rigid joint's 140mm correction budget.
		# Holding beyond reach would move an allegedly planted foot in a single tick.
		if _source_support[side] and (height>.04 or rise>.008 or yaw_gap>deg_to_rad(35.) or (foot_support[side] and reach>.11) or _support_elapsed[side]>lerpf(.11,.16,gait_run_weight)):
			_source_support[side]=false;_support_rearmed[side]=false;_release_phase[side]=direction_snapshot.phase;released[side]=true
		if not _support_rearmed[side] and (height>.055 or direction_snapshot.phase-_release_phase[side]>.3):_support_rearmed[side]=true
		if not _source_support[side] and _support_rearmed[side] and height<.025 and rise<.004:
			_source_support[side]=true;_support_elapsed[side]=0.;released[side]=false

func _support(side: int) -> bool:
	if not move_requested:return true
	return _source_support[side] and not released[side]

func _target_pose(bone: int,ahead: float=0.) -> Transform3D:
	# Source root compensation must remain active at rest when engine look turns.
	if direction_sampler==null:return super._target_pose(bone,ahead)
	var poses: Array=direction_future_poses if ahead>0. else direction_poses
	var pose: Transform3D=poses[bone]
	return Transform3D(Basis(pose.basis.orthonormalized().get_rotation_quaternion()),pose.origin)

func _target_leg_scale(bone: int,ahead: float=0.) -> float:
	if direction_sampler==null:return 1.
	var poses: Array=direction_future_poses if ahead>0. else direction_poses
	return Transform3D(poses[bone]).basis.get_scale().y
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
		var value:=clampf(_target_leg_scale(bone)+residual,1.,1.106)
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
		return _hold_support_yaw(side,super._contact_leg_rotation(side,bone,target,original_q,delta))
	# Select/anchor the corner from the final held-yaw orientation, not the raw
	# source yaw that will be replaced below. Otherwise the tracked point slides.
	var held_q:=_hold_support_yaw(side,original_q)
	_set_world_leg_rotation(bone,held_q)
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
	return held_q
func _hold_support_yaw(side: int,q: Quaternion) -> Quaternion:
	var gap:=wrapf(_foot_yaw(q)-_foot_yaw(foot_rotations[side]),-PI,PI)
	return (Quaternion(Vector3.UP,-gap)*q).normalized()
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
	_source_support=[false,false];_support_rearmed=[true,true];_source_sole_previous=[0.,0.];_support_elapsed=[0.,0.]
	move_requested=false;settling=false;gait_run_weight=0.;gait_frequency=0.;pose_dirty=true;_scale_dirty=true
	rolling_corner=[-1,-1];rolling_used=[false,false];rolling_offset=[Vector3.ZERO,Vector3.ZERO];release_offset=[Vector3.ZERO,Vector3.ZERO]
	foot_support=[false,false];support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY];released=[false,false]
