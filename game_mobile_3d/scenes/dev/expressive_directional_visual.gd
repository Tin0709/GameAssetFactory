extends "res://scenes/dev/expressive_jump_visual.gd"
## Test-only support and swing adaptation; movement physics and gait clocks unchanged.
var directional_enabled:=true
var travel_bias:=0.0
var turn_lean:=0.0
var turn_twist:=0.0

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
	if not directional_enabled or not move_requested or _ground_turn_weight()<.99:
		return super._contact_leg_rotation(side,bone,target,original_q,delta)
	# Solve the existing single solid leg toward its world support. The cached
	# receiving orientation retains toe heading instead of inheriting body yaw.
	var origin: Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(bone)).origin
	var receiving:=foot_rotations[side]
	var q:=receiving
	for iteration in 2:
		var basis:=Basis(q)
		var corner_drop:=.1125*(absf(basis.x.y)+absf(basis.z.y))
		var destination:=target+Vector3(0,contact_floor_y+corner_drop,0)
		q=(Quaternion(Basis(receiving).y.normalized(),(destination-origin).normalized())*receiving).normalized()
	support_aim[side]=Quaternion.IDENTITY
	return q
