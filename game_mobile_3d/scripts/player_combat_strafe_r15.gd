extends "res://scripts/player_weapon_r13_integration.gd"
## Combat lower-body blend in the existing sole writer; upper R13 layers stay live.
const STRAFE_LEFT: StringName=&"Combat_StrafeLeft_V2"
const STRAFE_RIGHT: StringName=&"Combat_StrafeRight_V2"
const COMBAT_CLIPS=[STRAFE_LEFT,STRAFE_RIGHT,&"Combat_StrafeForwardLeft_V1",&"Combat_StrafeForwardRight_V1",&"Combat_StrafeBackwardLeft_V1",&"Combat_StrafeBackwardRight_V1"]
# Circular model-relative directions; character +Z front has right at -X.
const COMBAT_SECTORS=[&"Forward",&"Combat_StrafeForwardRight_V1",STRAFE_RIGHT,&"Combat_StrafeBackwardRight_V1",&"Backward",&"Combat_StrafeBackwardLeft_V1",STRAFE_LEFT,&"Combat_StrafeForwardLeft_V1"]
const COMBAT_TWIST_LIMIT: float=deg_to_rad(20.0)
@export var combat_strafe_blend_seconds: float=0.14
var combat_facing_active:=false
var combat_strafe_direction:=0
var combat_strafe_weight:=0.0
var combat_strafe_phase:=0.0
var combat_strafe_request:=0
var combat_strafe_clips: Dictionary={}
var combat_direction_weights: Dictionary={}
var combat_direction_targets: Dictionary={}
var combat_direction: StringName=&"Forward"

func _ready() -> void:
	super._ready()
	for name in COMBAT_CLIPS:
		assert(samples.has(name),"Missing authored combat gait "+String(name))
		var sampler: RefCounted=samples[name]
		sampler.clip.loop_mode=Animation.LOOP_LINEAR
		combat_strafe_clips[name]=sampler
	for name in COMBAT_SECTORS: combat_direction_weights[name]=1.0 if name==&"Forward" else 0.0
	_evaluate(0)

func update_motion(velocity_world: Vector3, target: Node3D, delta: float) -> void:
	if frozen:return
	var sprint: bool=get_parent().fast_sprinting
	var ready: bool=weapon_behavior!=null and weapon_behavior.is_ready() and weapon_equipped
	combat_facing_active=is_instance_valid(target) and ready and not sprint
	combat_strafe_request=0
	combat_direction_targets.clear()
	var horizontal:=Vector3(velocity_world.x,0,velocity_world.z)
	if combat_facing_active and horizontal.length()>=LOCOMOTION_DEAD_ZONE:
		var forward: Vector3=target.global_position-global_position;forward.y=0
		if forward.length_squared()>.0001:
			forward=forward.normalized()
			var lateral:=horizontal.dot(forward.cross(Vector3.UP))
			var angle:=fposmod(atan2(lateral,horizontal.dot(forward)),TAU)
			var sector:=angle/(PI/4.0)
			var index:=int(floor(sector))%8
			var fraction: float=sector-floor(sector)
			combat_direction_targets[COMBAT_SECTORS[index]]=1.0-fraction
			combat_direction_targets[COMBAT_SECTORS[(index+1)%8]]=fraction
			combat_direction=COMBAT_SECTORS[int(round(sector))%8]
			combat_strafe_direction=1 if lateral>0 else -1
			combat_strafe_request=combat_strafe_direction
	# Controller already owns eligibility; sprint always faces travel.
	super.update_motion(velocity_world,null if sprint else target,delta)

func _process(delta: float) -> void:
	if not frozen and not combat_strafe_clips.is_empty():
		combat_strafe_weight=move_toward(combat_strafe_weight,1.0 if not combat_direction_targets.is_empty() else 0.0,delta/maxf(combat_strafe_blend_seconds,.001))
		if not combat_direction_targets.is_empty():
			var alpha:=1.0-exp(-delta/maxf(combat_strafe_blend_seconds/3.0,.001))
			for name in COMBAT_SECTORS:
				combat_direction_weights[name]=lerpf(combat_direction_weights[name],combat_direction_targets.get(name,0.0),alpha)
		# This additional authored-gait clock never resets on direction/state changes.
		# Existing reference, legacy and R13 clocks continue untouched in super.
		if movement_speed>=LOCOMOTION_DEAD_ZONE:
			var cadence:=minf(1.0,movement_speed/maxf(get_parent().combat_move_speed,.001))
			combat_strafe_phase=fposmod(combat_strafe_phase+delta*cadence/combat_strafe_clips[STRAFE_RIGHT].clip.length,1.0)
	super._process(delta)

func _combat_pose(bone: int) -> Transform3D:
	var result:=Transform3D.IDENTITY
	var total:=0.0
	for name in COMBAT_SECTORS:
		var weight: float=combat_direction_weights[name]
		if weight<=.000001:continue
		var sampler: RefCounted=reference_clips.Walk if name in [&"Forward",&"Backward"] else combat_strafe_clips[name]
		# Forward/back retain the approved Walk at its own continuous phase.
		var phase:=fposmod(-reference_phase,1.0) if name==&"Backward" else reference_phase
		if not name in [&"Forward",&"Backward"]:phase=combat_strafe_phase
		var time: float=phase*sampler.clip.length
		var pose:=Transform3D(Basis(sampler.rotation(bone,time)),sampler.position(bone,time))
		if total==0:result=pose
		else:result=result.interpolate_with(pose,weight/(total+weight))
		total+=weight
	return result

func _evaluate_locomotion_pose(delta: float) -> bool:
	var gait_lower:=lower_rotation
	lower_rotation=Quaternion.IDENTITY.slerp(gait_lower,1.0-combat_strafe_weight)
	var evaluated:=super._evaluate_locomotion_pose(delta)
	lower_rotation=gait_lower
	if not evaluated or combat_strafe_weight<=0 or combat_strafe_clips.is_empty():return evaluated
	var upper_heading:=_combat_bone_yaw(chest)
	for bone in [hips,leg_left,leg_right]:
		var pose:=_combat_pose(bone)
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(pose.origin,combat_strafe_weight))
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(pose.basis.get_rotation_quaternion(),combat_strafe_weight).normalized())
	# Native Spine balance is a rotational residual, preserving living upper sway.
	var spine:=skeleton.find_bone("Spine")
	var balance:=Quaternion.IDENTITY
	for name in COMBAT_CLIPS:
		var sampler: RefCounted=combat_strafe_clips[name]
		var offset: Quaternion=skeleton.get_bone_rest(spine).basis.get_rotation_quaternion().inverse()*sampler.rotation(spine,combat_strafe_phase*sampler.clip.length)
		balance=(balance*Quaternion.IDENTITY.slerp(offset,combat_direction_weights.get(name,0.0))).normalized()
	skeleton.set_bone_pose_rotation(spine,(skeleton.get_bone_pose_rotation(spine)*Quaternion.IDENTITY.slerp(balance,combat_strafe_weight)).normalized())
	_rotate_global(chest,Quaternion(Vector3.UP,wrapf(upper_heading-_combat_bone_yaw(chest),-PI,PI)))
	return true

func _combat_bone_yaw(bone: int) -> float:
	var direction: Vector3=skeleton.get_bone_global_pose(bone).basis*skeleton.get_bone_global_rest(bone).basis.inverse()*Vector3.BACK
	return atan2(direction.x,direction.z)
func combat_torso_twist() -> float:
	return wrapf(_combat_bone_yaw(chest)-_combat_bone_yaw(hips),-PI,PI)
func _evaluate(delta: float) -> void:
	super._evaluate(delta)
	_limit_combat_twist()

func _limit_combat_twist() -> void:
	if skeleton==null or (not combat_facing_active and combat_strafe_weight<=0):return
	var twist:=combat_torso_twist()
	# Identity through 12°, then a C1 soft shoulder asymptotically below 20°.
	# Rotate lower toward upper; inverse at Chest preserves target/weapon heading.
	var shoulder:=deg_to_rad(12.0)
	if absf(twist)>shoulder:
		# Reserve half a degree for floating-point/evaluated-basis roundoff.
		var width:=COMBAT_TWIST_LIMIT-deg_to_rad(.5)-shoulder
		var limited:=signf(twist)*(shoulder+width*tanh((absf(twist)-shoulder)/width))
		var correction:=Quaternion(Vector3.UP,twist-limited)
		_rotate_global(hips,correction);_rotate_global(chest,correction.inverse())
		skeleton.force_update_all_bone_transforms()
		if socket!=null and socket.carrier_socket!=null:socket.sync_transport_sockets()
func ready_context_text() -> String:
	if combat_facing_active:return "R15 | Combat "+String(combat_direction)+" | phase %.3f"%combat_strafe_phase
	return super.ready_context_text()
