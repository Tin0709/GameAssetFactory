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

func advance_jump(state: String, age: float, vy: float, launch: float, to_floor: float, delta: float) -> void:
	super.advance_jump(state,age,vy,launch,to_floor,delta)
	# Physics descent gates this shoulder gesture; no extra elevation/flight clock.
	fall_wave_weight=_smooth5(falling_time/.20)*_smooth5((to_floor-.05)/.14) if state=="AIR" and vy<0 else 0.0

func drive_locomotion(world_velocity: Vector3, requested: bool, delta: float) -> void:
	super.drive_locomotion(world_velocity,requested,delta)
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
	if fall_wave_enabled and fall_wave_weight>0 and bone in [leg_left,leg_right]:
		# Opposing whole-block flutter; no knee/ankle or airborne root bounce.
		var phase: float=(jump_age+ahead)*TAU*1.7+(0.0 if bone==leg_left else PI)
		result.basis=Basis(Vector3.RIGHT,deg_to_rad(8)*sin(phase)*fall_wave_weight)*result.basis
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
