extends "res://scripts/player_weapon_r13_integration.gd"
## Authored combat gait in the existing sole writer. Target supplied by controller.
const STRAFE_LEFT: StringName=&"Combat_StrafeLeft_V1"
const STRAFE_RIGHT: StringName=&"Combat_StrafeRight_V1"
const COMBAT_TWIST_LIMIT: float=deg_to_rad(20.0)
@export var combat_strafe_blend_seconds: float=0.14
var combat_facing_active:=false
var combat_strafe_direction:=0 # +1 character RIGHT, -1 character LEFT (+Z model).
var combat_strafe_weight:=0.0
var combat_strafe_phase:=0.0
var combat_strafe_request:=0
var combat_strafe_clips: Dictionary={}
var combat_strafe_switch_weight:=1.0
var combat_strafe_entry: Dictionary={}

func _ready() -> void:
	super._ready()
	for name in [STRAFE_LEFT,STRAFE_RIGHT]:
		assert(samples.has(name),"Missing authored combat strafe "+String(name))
		var sampler: RefCounted=samples[name]
		sampler.clip.loop_mode=Animation.LOOP_LINEAR
		combat_strafe_clips[name]=sampler
	_evaluate(0)

func update_motion(velocity_world: Vector3, target: Node3D, delta: float) -> void:
	if frozen:return
	var sprint: bool=get_parent().fast_sprinting
	var ready: bool=weapon_behavior!=null and weapon_behavior.is_ready() and weapon_equipped
	combat_facing_active=is_instance_valid(target) and ready and not sprint
	combat_strafe_request=0
	if combat_facing_active:
		var forward: Vector3=target.global_position-global_position;forward.y=0
		if forward.length_squared()>.0001:
			forward=forward.normalized()
			var horizontal:=Vector3(velocity_world.x,0,velocity_world.z)
			# The imported character faces +Z: its RIGHT is -X, not viewer-right.
			var lateral:=horizontal.dot(forward.cross(Vector3.UP))
			var fraction:=absf(lateral)/maxf(horizontal.length(),.001)
			var threshold:=.55 if combat_strafe_weight>.01 else .65
			if horizontal.length()>=LOCOMOTION_DEAD_ZONE and fraction>=threshold:
				combat_strafe_request=1 if lateral>0 else -1
	super.update_motion(velocity_world,null if sprint else target,delta)

func _process(delta: float) -> void:
	if not frozen and not combat_strafe_clips.is_empty():
		if combat_strafe_request!=0 and (combat_strafe_direction!=combat_strafe_request or combat_strafe_weight<=.0001):
			combat_strafe_entry.clear()
			for bone in [hips,leg_left,leg_right]:
				combat_strafe_entry[bone]=Transform3D(Basis(skeleton.get_bone_pose_rotation(bone)),skeleton.get_bone_pose_position(bone))
			combat_strafe_direction=combat_strafe_request
			combat_strafe_phase=0.0;combat_strafe_switch_weight=0.0
		combat_strafe_weight=move_toward(combat_strafe_weight,1.0 if combat_strafe_request!=0 else 0.0,delta/maxf(combat_strafe_blend_seconds,.001))
		combat_strafe_switch_weight=minf(1.0,combat_strafe_switch_weight+delta/maxf(combat_strafe_blend_seconds,.001))
		if combat_strafe_weight>0:
			var cadence:=minf(1.0,movement_speed/maxf(get_parent().combat_move_speed,.001))
			combat_strafe_phase=fposmod(combat_strafe_phase+delta*cadence/combat_strafe_clips[STRAFE_RIGHT].clip.length,1.0)
	super._process(delta) # Existing Walk/Sprint/R13 clocks and behavior keep running.

func _evaluate_locomotion_pose(delta: float) -> bool:
	var gait_lower:=lower_rotation
	# Fade out the old travel-facing hip twist as the sideways gait enters.
	lower_rotation=Quaternion.IDENTITY.slerp(gait_lower,1.0-combat_strafe_weight)
	var evaluated:=super._evaluate_locomotion_pose(delta)
	lower_rotation=gait_lower
	if not evaluated or combat_strafe_weight<=0 or combat_strafe_clips.is_empty():return evaluated
	var sampler: RefCounted=combat_strafe_clips[STRAFE_RIGHT if combat_strafe_direction>0 else STRAFE_LEFT]
	var time: float=combat_strafe_phase*sampler.clip.length
	var upper_heading:=_combat_bone_yaw(chest)
	for bone in [hips,leg_left,leg_right]:
		var pose:=Transform3D(Basis(sampler.rotation(bone,time)),sampler.position(bone,time))
		if combat_strafe_switch_weight<1 and combat_strafe_entry.has(bone):
			pose=combat_strafe_entry[bone].interpolate_with(pose,combat_strafe_switch_weight)
		skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(pose.origin,combat_strafe_weight))
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(pose.basis.get_rotation_quaternion(),combat_strafe_weight).normalized())
	# R6 already counterrotated Chest against its old Hips pose. Recompose that
	# counterrotation after replacing Hips, retaining upper aim through every blend.
	_rotate_global(chest,Quaternion(Vector3.UP,wrapf(upper_heading-_combat_bone_yaw(chest),-PI,PI)))
	# Rotation-only balance Action: retain the latest breathing/body sway translation.
	var spine:=skeleton.find_bone("Spine")
	var balance: Quaternion=skeleton.get_bone_rest(spine).basis.get_rotation_quaternion().inverse()*sampler.rotation(spine,time)
	skeleton.set_bone_pose_rotation(spine,(skeleton.get_bone_pose_rotation(spine)*Quaternion.IDENTITY.slerp(balance,combat_strafe_weight)).normalized())
	return true

func _combat_bone_yaw(bone: int) -> float:
	var direction: Vector3=skeleton.get_bone_global_pose(bone).basis*skeleton.get_bone_global_rest(bone).basis.inverse()*Vector3.BACK
	return atan2(direction.x,direction.z)
func combat_torso_twist() -> float:
	return wrapf(_combat_bone_yaw(chest)-_combat_bone_yaw(hips),-PI,PI)
func _evaluate(delta: float) -> void:
	super._evaluate(delta)
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
	if combat_strafe_request!=0:return "R15 | Combat Strafe "+("Right" if combat_strafe_direction>0 else "Left")
	return super.ready_context_text()
