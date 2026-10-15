extends "res://scenes/dev/actions_stuff_research/walk_run_visual.gd"
## Research-only event bridge. Ground locomotion stays on its approved path;
## authored Jump PRS/controller clocks run against the real capsule queries.
const JumpRuntime=preload("res://scenes/dev/actions_stuff_research/source_jump_runtime.gd")
const JumpSampler=preload("res://scenes/dev/actions_stuff_research/source_jump_sampler.gd")
const PHASE_KEYS=["v.eqhdel","v.ifcvde","v.gadjrq","v.njrdop"]
var jump_runtime: RefCounted
var jump_sampler: RefCounted
var jump_future_sampler: RefCounted
var jump_snapshot: Dictionary={}
var jump_active:=false
var jump_grounded:=true
var _physical_height:=0.0
var _jump_scale_offsets: Array[Vector3]=[]
var _jump_scale_previous: Array[Vector3]=[]
var _jump_scale_age:=10.0
var _jump_scale_dirty:=false
var _scale_handoff:=false

func _ready() -> void:
	super._ready()
	_initialize_jump_runtime()
	for bone in skeleton.get_bone_count():
		_jump_scale_offsets.append(Vector3.ZERO)
		_jump_scale_previous.append(skeleton.get_bone_pose_scale(bone))

func _initialize_jump_runtime() -> void:
	jump_runtime=JumpRuntime.new(12.)
	jump_runtime.seed_heading(-rad_to_deg(look_yaw));jump_runtime.seed_context(false)
	jump_runtime.set_item_holding(0.,0.)
	jump_sampler=JumpSampler.new(skeleton);jump_future_sampler=JumpSampler.new(skeleton)
	jump_snapshot=jump_runtime.step({"position":Vector3.ZERO,"movement_direction":Vector3.ZERO,"head_y_rotation":-rad_to_deg(look_yaw),"body_y_rotation":-rad_to_deg(look_yaw)},1./60.)

func drive_jump_motion(world_velocity: Vector3,requested: bool,physics: Dictionary,delta: float) -> void:
	var previous_position:=_virtual_query_position
	var previous_heading:=look_yaw
	var was_active:=jump_active
	var was_grounded:=jump_grounded
	# Exactly one inherited gait/input/facing update and one eventual pose writer.
	super.drive_locomotion(world_velocity,requested,delta)
	jump_grounded=bool(physics.grounded)
	var count:=maxi(1,ceili(delta*60.-.000001));var step:=delta/count
	var planar:=Vector3(world_velocity.x,0,world_velocity.z)
	var height: float=physics.body_position.y
	var yaw_rate: float=-rad_to_deg(wrapf(look_yaw-previous_heading,-PI,PI))/maxf(delta,.00001)
	for i in count:
		var source_position:=previous_position.lerp(_virtual_query_position,float(i+1)/count)
		source_position.y=lerpf(_physical_height,height,float(i+1)/count)
		jump_snapshot=jump_runtime.step({"position":source_position,"movement_direction":planar.normalized(),"head_y_rotation":wrapf(-rad_to_deg(look_yaw),-180.,180.),"body_y_rotation":-rad_to_deg(look_yaw),"yaw_speed":yaw_rate,"target_x_rotation":0.,"is_on_ground":float(jump_grounded),"vertical_speed":physics.vertical_speed,"is_jumping":float(physics.takeoff),"is_sprinting":float(physics.sprinting)},step)
	_physical_height=height
	jump_active=not jump_grounded or bool(physics.takeoff) or _has_jump_layers()
	if jump_active or was_active:
		# Only source gait phase is shared, never airborne/profile flags or Y history.
		# In particular, retain source sprint exits' .05/.55 phase overrides.
		for key in PHASE_KEYS:direction_controller.env[key]=jump_snapshot.vars[key]
	if jump_active:
		jump_sampler.set_snapshot(jump_snapshot)
		jump_future_sampler.set_snapshot(jump_sampler.future_snapshot(jump_snapshot,.004))
		direction_poses=jump_sampler.poses.duplicate();direction_future_poses=jump_future_sampler.poses.duplicate()
		gait_phase=fposmod(jump_snapshot.phase,1.);reference_phase=gait_phase
		settling=false
		if not jump_grounded or not was_grounded:
			_clear_jump_contacts()
		if jump_grounded:_update_direction_support(delta)
	elif was_active:
		_cache_direction_poses()
	if was_active!=jump_active:
		pose_dirty=true;_jump_scale_dirty=true;_scale_handoff=true;_scale_dirty=true
		transition_count+=1
		if jump_grounded:_clear_jump_contacts()

func _has_jump_layers() -> bool:
	for alias in ["ngeixo","pyhwuc","muiqdc"]:
		var c: Dictionary=jump_snapshot.controllers[alias]
		if c.state not in ["default","zhbjho"] or c.outgoing!=null:return true
	return false

func _clear_jump_contacts() -> void:
	foot_support=[false,false];_source_support=[false,false];_support_rearmed=[true,true]
	released=[false,false];rolling_corner=[-1,-1];rolling_used=[false,false]
	rolling_offset=[Vector3.ZERO,Vector3.ZERO];release_offset=[Vector3.ZERO,Vector3.ZERO]
	support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
	settling=false

func _support(side: int) -> bool:
	if not jump_grounded:return false
	return super._support(side)

func _apply_source_scales(delta: float) -> void:
	if not jump_active and not _scale_handoff:
		super._apply_source_scales(delta)
		return
	if _jump_scale_dirty:
		_jump_scale_age=0.;_jump_scale_dirty=false
		for bone in skeleton.get_bone_count():
			_jump_scale_offsets[bone]=skeleton.get_bone_pose_scale(bone)-Transform3D(direction_poses[bone]).basis.get_scale()
	_jump_scale_age+=delta
	var residual: float=(1.+24.*_jump_scale_age)*exp(-24.*_jump_scale_age)
	for bone in skeleton.get_bone_count():
		var target:=Transform3D(direction_poses[bone]).basis.get_scale()
		skeleton.set_bone_pose_scale(bone,target+_jump_scale_offsets[bone]*residual)
	if not jump_active and residual<.0001:
		_scale_handoff=false;_scale_dirty=true

func _evaluate(delta: float) -> void:
	if jump_grounded:
		super._evaluate(delta)
		return
	# Ground solver also clamps free feet to y=0. Bypass it entirely in flight:
	# no IK/contact anchors, no preview trajectory, full authored local PRS.
	if _pending_physics_delta<=0:return
	delta=_pending_physics_delta;_pending_physics_delta=0.
	pose_sequence+=1;pose_delta=delta
	_evaluate_locomotion_pose(delta)
	skeleton.force_update_all_bone_transforms()
	for side in 2:
		var bone: int=[leg_left,leg_right][side]
		var sole:=_sole_world(bone)
		# A descending rigid source foot can meet this character's flat floor a
		# frame before its capsule. Only prevent penetration; do not plant it or
		# fire the landing controller until move_and_slide reports actual contact.
		if sole.y<0.:
			var parent:=skeleton.get_bone_parent(bone)
			var parent_basis:=skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
			skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone)+parent_basis.inverse()*Vector3(0.,minf(-sole.y,.14),0.))
			skeleton.force_update_all_bone_transforms()
		last_sole[side]=_sole_world(bone)
		var p:=skeleton.get_bone_pose_position(bone);var q:=skeleton.get_bone_pose_rotation(bone)
		_final_vp[bone]=(p-_final_p[bone])/delta;_final_vq[bone]=_rotvec(q*_final_q[bone].inverse())/delta
		_final_p[bone]=p;_final_q[bone]=q
	if socket!=null:socket.on_skeleton_update();socket.sync_transport_sockets()

func reset_contacts() -> void:
	super.reset_contacts()
	jump_active=false;jump_grounded=true;_physical_height=0.
	# Teleport cancels air/landing state but keeps approved gait/lifetime history.
	var old_life: float=jump_runtime.life
	var history: Dictionary=jump_runtime.env.duplicate()
	_initialize_jump_runtime()
	jump_runtime.life=old_life
	for key in history:
		if key.begins_with("v."):jump_runtime.env[key]=history[key]
	jump_runtime.env["v.hirjne"]=0.
	_jump_scale_dirty=true;_scale_handoff=true
