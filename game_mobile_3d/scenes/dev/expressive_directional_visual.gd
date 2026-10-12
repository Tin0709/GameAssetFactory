extends "res://scenes/dev/expressive_jump_visual.gd"
## Test-only support and swing adaptation; movement physics and gait clocks unchanged.
var directional_enabled:=true
var travel_bias:=0.0
var turn_lean:=0.0
var turn_twist:=0.0
var fall_wave_enabled:=true
var fall_wave_weight:=0.0
var swing_active: Array[bool]=[false,false]
var swing_world_q: Array[Quaternion]=[Quaternion.IDENTITY,Quaternion.IDENTITY]
var run_stride_scale:=1.2
var polish_enabled:=true
var release_trace: Array=[]
var pivot_load:=Vector3.ZERO
var run_body_mean: Dictionary={}
var collect_contact_diagnostics:=false
var pivot_contact_ids: Array[int]=[-1,-1]
var layer_was_equipped:=false
var layer_release_age:=.30
var layer_release_q: Array[Vector3]=[]
var layer_release_p: Array[Vector3]=[]

func _process(delta: float) -> void:
	if polish_enabled and layer_was_equipped and not weapon_equipped and not _q.is_empty():
		# Capture the displayed partial/full layer, not its stale unwrapped
		# target. A shortest relative rotation avoids a long-way exit spin.
		layer_release_age=0;layer_release_q.clear();layer_release_p.clear()
		for bone in r13_mask:
			layer_release_q.append(_rotvec(skeleton.get_bone_pose_rotation(bone)*_q[bone].inverse()))
			layer_release_p.append(skeleton.get_bone_pose_position(bone)-_p[bone])
	layer_was_equipped=weapon_equipped
	layer_release_age=minf(.30,layer_release_age+delta)
	super._process(delta)

func _weapon_release_active() -> bool:
	return polish_enabled and not weapon_equipped and layer_release_age<.30 and layer_release_q.size()==r13_mask.size()

func _apply_weapon_carry() -> void:
	if _weapon_release_active():
		var weight:=1-_smooth5(layer_release_age/.30)
		for index in r13_mask.size():
			var bone:=r13_mask[index]
			skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone)+layer_release_p[index]*weight)
			skeleton.set_bone_pose_rotation(bone,(_from_rotvec(layer_release_q[index]*weight)*skeleton.get_bone_pose_rotation(bone)).normalized())
	elif polish_enabled and not weapon_equipped:
		return
	else:super._apply_weapon_carry()

func _pose_damping() -> float:
	# A moving ledge fall interrupts the fast Run arm swing. Keep that
	# unprepared entry on its own clock; authored takeoff/impact stay intact.
	if polish_enabled and jump_state=="AIR" and fall_entry and move_requested:return 36.0
	return super._pose_damping()

func _ready() -> void:
	super._ready()
	var clip: RefCounted=expressive_clips[EXPRESSIVE_NAMES[2]]
	for name in ["Hips","Spine","Chest"]:
		var bone:=skeleton.find_bone(name);var angles:=Vector3.ZERO;var p:=Vector3.ZERO
		for sample in 24:
			var time: float=sample/24.0*clip.clip.length
			angles+=Basis(clip.rotation(bone,time)).get_euler()/24.0
			p+=clip.position(bone,time)/24.0
		run_body_mean[bone]={"angles":angles,"position":p}

func _weapon_blend_rate() -> float:
	# Equip/release belongs to the upper-body clock, not locomotion cadence.
	return 1.0/.30 if polish_enabled else super._weapon_blend_rate()

func _evaluate_locomotion_pose(delta: float) -> bool:
	var evaluated:=super._evaluate_locomotion_pose(delta)
	if expressive_clips.is_empty() or foot_anchors.size()!=2:return evaluated
	var desired:=Vector3.ZERO
	if polish_enabled and jump_state=="GROUND" and move_requested:
		skeleton.force_update_all_bone_transforms()
		for side in 2:
			if not foot_support[side] or not _support(side):continue
			if absf(turn_rate)>.5 or absf(travel_bias)>.2:pivot_contact_ids[side]=contact_ids[side]
			if pivot_contact_ids[side]!=contact_ids[side]:continue
			var bone: int=[leg_left,leg_right][side]
			var origin: Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(bone)).origin
			var target: Vector3=foot_anchors[side]+Vector3(0,contact_floor_y,0)
			var receiving:=foot_rotations[side];var q:=receiving
			for iteration in 2:
				var basis:=Basis(q)
				var destination:=target+Vector3(0,.1125*(absf(basis.x.y)+absf(basis.z.y)),0)
				q=(Quaternion(Basis(receiving).y.normalized(),(destination-origin).normalized())*receiving).normalized()
			var destination:=target+Vector3(0,.1125*(absf(Basis(q).x.y)+absf(Basis(q).z.y)),0)
			var reach_error: float=origin.distance_to(destination)-.675
			var excess: float=maxf(0,absf(reach_error)-.055)*signf(reach_error)
			var demand: Vector3=(destination-origin).normalized()*clampf(excess,-.090,.090)
			if demand.length()>desired.length():desired=demand
	pivot_load=pivot_load.move_toward(desired,(.9 if desired.length()>pivot_load.length() else .35)*delta)
	if hips>=0:
		var parent:=skeleton.get_bone_parent(hips)
		var basis:=skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
		skeleton.set_bone_pose_position(hips,skeleton.get_bone_pose_position(hips)+basis.inverse()*pivot_load)
	return evaluated

func _stride_distance() -> float:
	return lerpf(WALK_STRIDE,RUN_STRIDE*run_stride_scale,gait_run_weight)

func jump_transition(value: String) -> void:
	if polish_enabled and value=="GROUND" and jump_state=="LAND" and move_requested:
		# The gait is already fully restored. Preserve its support and velocity
		# instead of starting a second inertialization at an arbitrary stride phase.
		jump_state=value;jump_age=0;attention_time=0
		settling=false;landing_replant=false
		return
	swing_active=[false,false]
	super.jump_transition(value)

func advance_jump(state: String, age: float, vy: float, launch: float, to_floor: float, delta: float) -> void:
	super.advance_jump(state,age,vy,launch,to_floor,delta)
	# Physics descent gates this shoulder gesture; no extra elevation/flight clock.
	fall_wave_weight=_smooth5(falling_time/.20)*_smooth5((to_floor-.05)/.14) if state=="AIR" and vy<0 else 0.0

func drive_locomotion(world_velocity: Vector3, requested: bool, delta: float) -> void:
	var was_moving:=move_requested
	super.drive_locomotion(world_velocity,requested,delta)
	if not directional_enabled or not move_requested or settling or not was_moving:
		swing_active=[false,false]
	var planar:=Vector2(world_velocity.x,world_velocity.z)
	var desired_bias:=0.0
	if planar.length()>.1:desired_bias=clampf(wrapf(atan2(planar.x,planar.y)-rotation.y,-PI,PI),-.9,.9)
	travel_bias=move_toward(travel_bias,desired_bias,6*delta)
	var energy:=clampf(movement_speed/(2.31*review_pace),0,1)
	var turn:=clampf(turn_rate/(4.5*review_pace),-1,1)
	var response:=1-exp(-12*delta)
	turn_lean=lerpf(turn_lean,-turn*deg_to_rad(lerpf(3,6,energy))*clampf(movement_speed/.8,0,1),response)
	turn_twist=lerpf(turn_twist,turn*deg_to_rad(2)*clampf(movement_speed/.8,0,1),response)

func _ground_turn_weight() -> float:
	if not directional_enabled or jump_state in ["AIR","PREP"]:return 0
	if jump_state=="LAND":return _smooth5((jump_age-.35)/.25)
	return 1.0

func _target_pose(bone: int, ahead: float=0.0) -> Transform3D:
	var result:=super._target_pose(bone,ahead)
	var name:=skeleton.get_bone_name(bone)
	if polish_enabled and move_requested and jump_state in ["GROUND","LAND"] and run_body_mean.has(bone):
		# Soften cyclic lateral shake only; retain mean posture, sagittal
		# weight transfer, forward lean and the grounded vertical rhythm.
		var release:=1.0 if jump_state=="GROUND" else _smooth5((jump_age+ahead-.65)/.20)
		var amount: float=.20*gait_run_weight*release
		var angles:=result.basis.get_euler();var mean: Vector3=run_body_mean[bone].angles
		angles.y=lerpf(angles.y,mean.y,amount);angles.z=lerpf(angles.z,mean.z,amount)
		result.basis=Basis.from_euler(angles)
		if bone==hips:result.origin.x=lerpf(result.origin.x,run_body_mean[bone].position.x,amount)
	if move_requested and bone in [leg_left,leg_right] and jump_state in ["GROUND","LAND"]:
		var weight:=1.0 if jump_state=="GROUND" else _smooth5((jump_age-.08)/.24)
		var rest:=skeleton.get_bone_rest(bone).basis
		var pitch: float=(result.basis*rest.inverse()).get_euler().x
		result.basis=Basis(Vector3.RIGHT,pitch*(run_stride_scale-1)*gait_run_weight*weight)*result.basis
	if fall_wave_enabled and fall_wave_weight>0 and bone in [leg_left,leg_right]:
		# Opposing whole-block flutter; no knee/ankle or airborne root bounce.
		var phase: float=(jump_age+ahead)*TAU*1.7+(0.0 if bone==leg_left else PI)
		var opening:=deg_to_rad(10 if polish_enabled else 5)*(1 if bone==leg_left else -1)
		result.basis=Basis.from_euler(Vector3(deg_to_rad(8)*sin(phase),0,opening)*fall_wave_weight)*result.basis
	if fall_wave_enabled and fall_wave_weight>0 and name in ["Arm.L","Arm.R","ForeArm.L","ForeArm.R"]:
		# Reuse the approved above-head airborne articulation. Small staggered
		# shoulder arcs retain height and straight solid arms, rather than elbow flaps.
		var raised:=Basis(jump_clip.rotation(bone,31.5/30.0))
		if name in ["Arm.L","Arm.R"]:
			var phase: float=(jump_age+ahead)*TAU*2.0+(0.0 if name=="Arm.L" else 2.0)
			raised=Basis.from_euler(Vector3(deg_to_rad(3)*sin(phase+.6),deg_to_rad(12)*sin(phase),deg_to_rad(10)*(1 if name=="Arm.L" else -1)))*raised
		result.basis=Basis(result.basis.get_rotation_quaternion().slerp(raised.get_rotation_quaternion(),fall_wave_weight).normalized())
	var weight:=_ground_turn_weight()
	if weight==0 or not move_requested:return result
	if bone in [leg_left,leg_right]:
		# Redirect the gait's lean/reach, not its clock or rigid block rest frame.
		var rest:=skeleton.get_bone_rest(bone)
		var steer:=Basis(Vector3.UP,travel_bias*weight)
		var motion:=result.basis*rest.basis.inverse()
		result.basis=steer*motion*steer.inverse()*rest.basis
		result.origin=rest.origin+steer*(result.origin-rest.origin)
	if bone==hips:
		result.basis=Basis.from_euler(Vector3(0,turn_twist,turn_lean*.45)*weight)*result.basis
		result.origin.y-=.004*clampf(absf(turn_lean)/deg_to_rad(6),0,1)*weight
	elif bone==chest:result.basis=Basis.from_euler(Vector3(0,-turn_twist*1.5,turn_lean*.55)*weight)*result.basis
	elif skeleton.get_bone_name(bone)=="Head":result.basis=Basis.from_euler(Vector3(0,turn_twist*.25,-turn_lean*.35)*weight)*result.basis
	return result

func _contact_leg_rotation(side: int, bone: int, target: Vector3, original_q: Quaternion, delta: float) -> Quaternion:
	var weight:=_ground_turn_weight()
	if weight<=0 or not move_requested:
		swing_active[side]=false
		return super._contact_leg_rotation(side,bone,target,original_q,delta)
	var landing_q:=original_q
	if weight<1:landing_q=super._contact_leg_rotation(side,bone,target,original_q,delta)
	# Solve the existing single solid leg toward its world support. The cached
	# receiving orientation retains toe heading instead of inheriting body yaw.
	var origin: Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(bone)).origin
	var receiving:=foot_rotations[side]
	if not foot_support[side] and swing_active[side]:
		# At faster cadence a reversal offset may survive until receiving.
		# Keep that step's actual outgoing orientation instead of resetting it.
		var gap:=swing_world_q[side].angle_to(receiving)
		var limit:=deg_to_rad(600)*review_pace*delta
		receiving=swing_world_q[side].slerp(receiving,minf(1,limit/maxf(gap,.00001))).normalized()
		if gap>limit:
			_set_world_leg_rotation(bone,receiving)
			var sole:=_sole_world(bone)
			foot_anchors[side]=Vector3(sole.x,0,sole.z);target=foot_anchors[side]
		foot_rotations[side]=receiving;swing_active[side]=false
	var q:=receiving
	for iteration in 2:
		var basis:=Basis(q)
		var corner_drop:=.1125*(absf(basis.x.y)+absf(basis.z.y))
		var destination:=target+Vector3(0,contact_floor_y+corner_drop,0)
		q=(Quaternion(Basis(receiving).y.normalized(),(destination-origin).normalized())*receiving).normalized()
	# Carry the solved offset into the inherited swing release instead of
	# jumping straight back to the body-relative authored leg orientation.
	q=landing_q.slerp(q,weight).normalized()
	support_aim[side]=(q*original_q.inverse()).normalized()
	return q

func _swing_leg_rotation(side: int, bone: int, delta: float) -> Quaternion:
	var weight:=_ground_turn_weight()
	if weight<=0:
		swing_active[side]=false
		return super._swing_leg_rotation(side,bone,delta)
	# A large pivot offset needs the swing interval to unwind. Bound its
	# angular release, without slowing the capsule or restarting the stride.
	var angle:=support_aim[side].angle_to(Quaternion.IDENTITY)
	var original_fraction:=1-exp(-25*review_pace*delta)
	var fraction:=lerpf(original_fraction,minf(original_fraction,8*delta/maxf(angle,.00001)),weight)
	support_aim[side]=support_aim[side].slerp(Quaternion.IDENTITY,fraction).normalized()
	swing_world_q[side]=(support_aim[side]*_leg_world_rotation(bone)).normalized()
	swing_active[side]=true
	return swing_world_q[side]

func _limit_contact_correction(correction: Vector3) -> Vector3:
	if collect_contact_diagnostics and jump_state=="GROUND" and move_requested:
		release_trace.append({"phase":gait_phase,"load":pivot_load,"correction":correction,"turn":turn_rate,"bias":travel_bias,"aim":[rad_to_deg(support_aim[0].angle_to(Quaternion.IDENTITY)),rad_to_deg(support_aim[1].angle_to(Quaternion.IDENTITY))]})
	return super._limit_contact_correction(correction)
