extends "res://scenes/dev/expressive_locomotion_visual.gd"
## Test-only adapter inside the existing sole pose writer and contact solver.
const SNAPPY=preload("res://assets/characters/snappy_locomotion_v1/snappy_library.res")
const SNAPPY_NAMES=["Walk_Snappy_V027_Refined_Test_v003","Run_Snappy_Test_v001"]
const SNAPPY_WALK_STRIDE:=1.59936*.7
const SNAPPY_RUN_STRIDE:=2.5*17.0/30.0
var walk_anchor:=1.59936
var run_anchor:=2.5
var snappy_clips: Dictionary={}
var source_profiles: Dictionary={}
var snappy_enabled:=true
var style_weight:=1.0
var style_toggles:=0
var run_transition_active:=false
var facing_velocity:=0.0
var travel_bias:=0.0
var pivot_load:=Vector3.ZERO
var pivot_contact_ids: Array[int]=[-1,-1]
var early_release: Array[bool]=[false,false]
var turn_release_count:=0
var release_active: Array[bool]=[false,false]
var release_age: Array[float]=[0.0,0.0]
var release_offset: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var release_velocity: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var previous_raw: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var run_blend_wait:=0.0
var maximum_run_blend_wait:=0.0

func _ready() -> void:
	review_pace=1.0
	super._ready()
	for name in SNAPPY_NAMES:snappy_clips[name]=Sampler.new(SNAPPY.get_animation(name),skeleton)
	source_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/snappy_locomotion_v1/snappy_samples.json"))
	walk_speed_scale=1.59936/.9;run_speed_scale=2.5/2.31
	pose_dirty=true

func set_snappy(enabled: bool) -> void:
	if snappy_enabled==enabled:return
	snappy_enabled=enabled;style_toggles+=1;pose_dirty=true;transition_count+=1
	# Preserve capsule, gait phase, receiving IDs and existing contact anchors.

func reset_review() -> void:
	# Reset is an explicit teleport. Cancel every world-space contact/replant
	# cache and seed the approved Idle before the same writer evaluates again.
	move_requested=false;settling=false;settle_time=0;attention_time=0
	gait_phase=.28;gait_run_weight=0;gait_frequency=0;run_transition_active=false
	style_weight=1.0 if snappy_enabled else 0.0
	pivot_load=Vector3.ZERO;travel_bias=0;facing_velocity=0;rotation=Vector3.ZERO
	support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
	early_release=[false,false];release_active=[false,false]
	for side in 2:
		contact_ids[side]+=1;pivot_contact_ids[side]=-1
		foot_support[side]=false;foot_anchors[side]=Vector3.ZERO
		replant_from[side]=Vector3.ZERO;replant_q[side]=Quaternion.IDENTITY
		last_sole[side]=Vector3.ZERO;previous_raw[side]=Vector3.ZERO
	for i in skeleton.get_bone_count():
		var target:=_target_pose(i)
		_p[i]=target.origin;_q[i]=target.basis.get_rotation_quaternion()
		_vp[i]=Vector3.ZERO;_vq[i]=Vector3.ZERO
		_offset_p[i]=Vector3.ZERO;_offset_q[i]=Vector3.ZERO
		_offset_vp[i]=Vector3.ZERO;_offset_vq[i]=Vector3.ZERO
		_final_p[i]=_p[i];_final_q[i]=_q[i]
		_final_vp[i]=Vector3.ZERO;_final_vq[i]=Vector3.ZERO
		skeleton.set_bone_pose_position(i,_p[i]);skeleton.set_bone_pose_rotation(i,_q[i])
	pose_dirty=false;transition_age=10;_pending_physics_delta=1.0/60
	_evaluate(1.0/60)

func _stride_distance() -> float:
	return lerpf(lerpf(WALK_STRIDE,RUN_STRIDE,gait_run_weight),lerpf(SNAPPY_WALK_STRIDE,SNAPPY_RUN_STRIDE,gait_run_weight),style_weight)

func _target_pose(bone: int, ahead: float=0.0) -> Transform3D:
	var control:=super._target_pose(bone,ahead)
	if not move_requested or snappy_clips.is_empty():return control
	var wp: RefCounted=snappy_clips[SNAPPY_NAMES[0]]
	var rp: RefCounted=snappy_clips[SNAPPY_NAMES[1]]
	var phase:=fposmod(gait_phase+ahead*gait_frequency,1.0)
	var p: Vector3=wp.position(bone,phase*wp.clip.length).lerp(rp.position(bone,phase*rp.clip.length),gait_run_weight)
	var q: Quaternion=wp.rotation(bone,phase*wp.clip.length).slerp(rp.rotation(bone,phase*rp.clip.length),gait_run_weight).normalized()
	var result:=Transform3D(Basis(control.basis.get_rotation_quaternion().slerp(q,style_weight).normalized()),control.origin.lerp(p,style_weight))
	if bone in [leg_left,leg_right] and absf(travel_bias)>.00001:
		var rest:=skeleton.get_bone_rest(bone)
		var steer:=Basis(Vector3.UP,travel_bias)
		result.basis=steer*(result.basis*rest.basis.inverse())*steer.inverse()*rest.basis
		result.origin=rest.origin+steer*(result.origin-rest.origin)
	return result

func _height(name: String, side: int) -> float:
	var record: Dictionary=source_profiles[name]
	var heights: Array=record.sole_height_samples["L" if side==0 else "R"]
	var index:=gait_phase*(heights.size()-1)
	var first:=int(floor(index))
	return lerpf(heights[first],heights[mini(first+1,heights.size()-1)],index-first)

func _support(side: int) -> bool:
	return _authored_support(side) and (not early_release[side] or not move_requested)

func _authored_support(side: int) -> bool:
	if not move_requested:return true
	if source_profiles.is_empty():return super._support(side)
	# The approved Walk contains a shared low hop and secondary floor contacts.
	# Nominal duty alone would pin its lifted feet and erase the authored rhythm.
	var control:=lerpf(_height(EXPRESSIVE_NAMES[1],side),_height(EXPRESSIVE_NAMES[2],side),gait_run_weight)
	var snappy:=lerpf(_height(SNAPPY_NAMES[0],side),_height(SNAPPY_NAMES[1],side),gait_run_weight)
	return lerpf(control,snappy,style_weight)<.002

func drive_locomotion(world_velocity: Vector3, requested: bool, delta: float) -> void:
	_pending_physics_delta+=delta
	style_weight=move_toward(style_weight,1.0 if snappy_enabled else 0.0,delta/.20)
	var planar:=Vector3(world_velocity.x,0,world_velocity.z)
	movement_speed=planar.length()
	var old_yaw:=rotation.y
	if movement_speed>.015:_advance_facing(atan2(planar.x,planar.z),delta)
	else:_rest_facing(delta)
	turn_rate=wrapf(rotation.y-old_yaw,-PI,PI)/maxf(delta,.001)
	var desired_bias:=clampf(wrapf(atan2(planar.x,planar.z)-rotation.y,-PI,PI),-.9,.9) if movement_speed>.1 else 0.0
	travel_bias=move_toward(travel_bias,desired_bias,6*delta)
	var desired_run:=smoothstep(walk_anchor,run_anchor,movement_speed)
	var receiving_distance:=minf(minf(gait_phase,1.0-gait_phase),absf(gait_phase-.5))
	# Begin a gait handoff near a shared receiving event, then complete it on
	# one short clock. Never wait for a pose before moving the capsule.
	if absf(desired_run-gait_run_weight)>.001:
		if not move_requested or receiving_distance<.12:run_transition_active=true
		if not run_transition_active:run_blend_wait+=delta
	else:run_transition_active=false;run_blend_wait=0
	maximum_run_blend_wait=maxf(maximum_run_blend_wait,run_blend_wait)
	if run_transition_active:gait_run_weight=move_toward(gait_run_weight,desired_run,delta/.14)
	var was_moving:=move_requested
	move_requested=requested or movement_speed>.025
	if move_requested and not was_moving:
		settling=false;pose_dirty=true;transition_count+=1
		support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
		gait_phase=.80 if next_left else .28;next_left=not next_left
		if last_sole[0].y>.006:gait_phase=.80
		elif last_sole[1].y>.006:gait_phase=.28
		foot_support=[false,false];contact_ids[0]+=1;contact_ids[1]+=1
	if not move_requested and was_moving:
		settling=true;settle_time=0.0;attention_time=0.0;pose_dirty=true;transition_count+=1
		support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
		replant_first=0 if last_sole[0].y>last_sole[1].y else 1
		for i in 2:
			replant_from[i]=last_sole[i];replant_q[i]=_leg_world_rotation([leg_left,leg_right][i])
	gait_frequency=movement_speed/_stride_distance()
	if move_requested:gait_phase=fposmod(gait_phase+delta*gait_frequency,1.0)
	for side in 2:
		if not _authored_support(side):early_release[side]=false
	reference_phase=gait_phase;reference_sprint_weight=gait_run_weight
	if settling:
		settle_time+=delta
		if settle_time>=REPLANT_SECONDS:settle_time=REPLANT_SECONDS
	elif not move_requested:attention_time=fposmod(attention_time+delta,8.0)
	support_left=_support(0);support_right=_support(1)

func _advance_facing(target_yaw: float, delta: float) -> void:
	# Reuse the directional lab's acceleration-limited visible yaw policy.
	# Capsule input remains immediate; this changes only model facing.
	var error:=wrapf(target_yaw-rotation.y,-PI,PI)
	var desired:=clampf(error*14,-4.5,4.5)
	facing_velocity=move_toward(facing_velocity,desired,4.5/.09*delta)
	rotation.y+=facing_velocity*delta

func _rest_facing(delta: float) -> void:
	facing_velocity=move_toward(facing_velocity,0,4.5/.09*delta)
	rotation.y+=facing_velocity*delta

func _support_adaptation_active() -> bool:
	return move_requested

func _use_cached_contact_solve() -> bool:
	return move_requested

func _evaluate_locomotion_pose(delta: float) -> bool:
	var evaluated:=super._evaluate_locomotion_pose(delta)
	if snappy_clips.is_empty() or foot_anchors.size()!=2:return evaluated
	var desired:=Vector3.ZERO
	if _support_adaptation_active():
		skeleton.force_update_all_bone_transforms()
		for side in 2:
			if not foot_support[side] or not _support(side):continue
			if absf(turn_rate)>.5 or absf(travel_bias)>.2:pivot_contact_ids[side]=contact_ids[side]
			if pivot_contact_ids[side]!=contact_ids[side]:continue
			var bone: int=[leg_left,leg_right][side]
			var origin: Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(bone)).origin
			var target: Vector3=foot_anchors[side]
			var receiving:=foot_rotations[side];var q:=receiving
			for iteration in 2:
				var basis:=Basis(q)
				var destination:=target+Vector3(0,.1125*(absf(basis.x.y)+absf(basis.z.y)),0)
				q=(Quaternion(Basis(receiving).y.normalized(),(destination-origin).normalized())*receiving).normalized()
			var destination:=target+Vector3(0,.1125*(absf(Basis(q).x.y)+absf(Basis(q).z.y)),0)
			var reach_error:=origin.distance_to(destination)-.675
			var excess:=maxf(0,absf(reach_error)-.055)*signf(reach_error)
			var demand: Vector3=(destination-origin).normalized()*clampf(excess,-.09,.09)
			if demand.length()>desired.length():desired=demand
	pivot_load=pivot_load.move_toward(desired,(.9 if desired.length()>pivot_load.length() else .35)*delta)
	var parent:=skeleton.get_bone_parent(hips)
	var basis:=skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
	skeleton.set_bone_pose_position(hips,skeleton.get_bone_pose_position(hips)+basis.inverse()*pivot_load)
	skeleton.force_update_all_bone_transforms()
	if move_requested and (absf(turn_rate)>.5 or absf(travel_bias)>.2):
		for side in 2:
			if not foot_support[side] or not _support(side):continue
			var bone: int=[leg_left,leg_right][side]
			var original:=_leg_world_rotation(bone)
			var candidate:=_contact_leg_rotation(side,bone,foot_anchors[side],original,delta)
			_set_world_leg_rotation(bone,candidate)
			var demand:=foot_anchors[side]-_sole_world(bone)
			_set_world_leg_rotation(bone,original)
			if demand.length()>.12:early_release[side]=true;turn_release_count+=1
	return evaluated

func _evaluate(delta: float) -> void:
	# Evaluate the final replant endpoint before clearing the state. The base
	# physics clock could otherwise leave the second foot11mm above the floor
	# when a30FPS render skips the last fraction of the replant interval.
	var finished:=settling and settle_time>=REPLANT_SECONDS and _pending_physics_delta>0
	super._evaluate(delta)
	if finished:settling=false;foot_support=[true,true]

func _limit_twist(q: Quaternion, reference: Quaternion) -> Quaternion:
	var axis:=Basis(q).y.normalized()
	var forward:=Basis(reference).z
	forward=(forward-axis*forward.dot(axis)).normalized()
	if forward.length_squared()<.5:return q
	var twist:=forward.signed_angle_to(Basis(q).z,axis)
	return (Quaternion(axis,clampf(twist,-deg_to_rad(35),deg_to_rad(35))-twist)*q).normalized()

func _contact_leg_rotation(side: int, bone: int, target: Vector3, original_q: Quaternion, _delta: float) -> Quaternion:
	release_active[side]=false
	previous_raw[side]=_sole_world(bone)
	if not _use_cached_contact_solve():return super._contact_leg_rotation(side,bone,target,original_q,_delta)
	# Reuse the existing directional lab's one-link support solve. Cached toe
	# heading and two corner-height iterations avoid translating an already
	# planted leg beyond its joint limit while the body turns over that foot.
	var origin: Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(bone)).origin
	var receiving:=foot_rotations[side]
	var q:=receiving
	for iteration in 2:
		var basis:=Basis(q)
		var destination:=target+Vector3(0,.1125*(absf(basis.x.y)+absf(basis.z.y)),0)
		q=(Quaternion(Basis(receiving).y.normalized(),(destination-origin).normalized())*receiving).normalized()
	var clean:=_limit_twist(q,original_q)
	if clean.angle_to(q)>.00001:foot_rotations[side]=clean
	support_aim[side]=(clean*original_q.inverse()).normalized()
	return clean

func _swing_leg_rotation(side: int, bone: int, delta: float) -> Quaternion:
	var angle:=support_aim[side].angle_to(Quaternion.IDENTITY)
	var fraction:=minf(1-exp(-25*delta),8*delta/maxf(angle,.00001))
	support_aim[side]=support_aim[side].slerp(Quaternion.IDENTITY,fraction).normalized()
	var reference:=_leg_world_rotation(bone)
	var q:=_limit_twist((support_aim[side]*reference).normalized(),reference)
	support_aim[side]=(q*reference.inverse()).normalized()
	_set_world_leg_rotation(bone,q)
	var raw:=_sole_world(bone)
	if foot_support[side] and move_requested and last_sole[side].distance_to(raw)>.012:
		release_active[side]=true;release_age[side]=0
		release_offset[side]=(last_sole[side]-raw).limit_length(.13)
		release_velocity[side]=(-(raw-previous_raw[side])/maxf(delta,.00001)).limit_length(4.0)
	if release_active[side]:
		var u:=clampf(release_age[side]/.09,0,1)
		var offset:=release_offset[side]*(2*u*u*u-3*u*u+1)+release_velocity[side]*.09*(u*u*u-2*u*u+u)
		offset.y=maxf(offset.y,-raw.y);offset=offset.limit_length(.13)
		var parent:=skeleton.get_bone_parent(bone)
		var basis:=skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone)+basis.inverse()*offset)
		release_age[side]+=delta
		if u>=1:release_active[side]=false
	previous_raw[side]=raw
	return q
