extends "res://scenes/dev/snappy_locomotion_visual.gd"
## Reuse the existing Expressive jump adapter inside the Snappy sole writer.
const JUMP_LIBRARY=preload("res://assets/characters/expressive_jump_v1/jump_library.res")
var jump_clip: RefCounted
var jump_state:="GROUND"
var jump_age:=0.0
var jump_frame:=1.0
var jump_frame_rate:=0.0
var contact_floor_y:=0.0
var falling_time:=0.0
var landing_replant:=false
var last_jump_frame:=1.0
var fall_entry:=false
var heavier_landing:=true
var landing_run_weight:=0.0
var landing_clearance_lift:=0.0
var landing_released: Array[bool]=[false,false]

func _ready() -> void:
	super._ready()
	jump_clip=Sampler.new(JUMP_LIBRARY.get_animation("Full_Jump_Expressive_v2_Test"),skeleton)
	walk_anchor=3.0375;run_anchor=5.977875

func jump_transition(value: String) -> void:
	landing_released=[false,false]
	var previous_state:=jump_state
	var preserve_replant:=value=="GROUND" and landing_replant and settling
	var previous_settle:=settle_time
	release_active=[false,false];early_release=[false,false]
	if value in ["AIR","PREP"]:pivot_load=Vector3.ZERO
	jump_state=value;jump_age=0;pose_dirty=true
	settling=false;landing_replant=false;support_aim=[Quaternion.IDENTITY,Quaternion.IDENTITY]
	if value=="PREP":jump_frame=7.0;falling_time=0
	if value=="AIR":
		fall_entry=previous_state!="PREP";falling_time=0
		# No launch impulse on a ledge fall: enter the lowered-arm approach,
		# rather than raising settled arms back into the main airborne peak.
		jump_frame=43.0 if fall_entry else 19.0
	if value=="LAND":
		jump_frame=46.0;foot_support=[false,false]
		landing_run_weight=gait_run_weight
	if value=="GROUND":foot_support=[false,false];attention_time=0.0
	if preserve_replant:landing_replant=true;settling=true;settle_time=previous_settle

func drive_locomotion(world_velocity: Vector3, requested: bool, delta: float) -> void:
	var old_phase:=gait_phase;var old_move:=move_requested
	super.drive_locomotion(world_velocity,requested,delta)
	if jump_state!="GROUND":
		if move_requested and not old_move:
			# An input change in flight must not choose a new idle-start stride.
			gait_phase=fposmod(old_phase+gait_frequency*delta,1.0)
		if not landing_replant:settling=false
	for side in 2:
		if fposmod(gait_phase-side*.5,1)<fposmod(old_phase-side*.5,1):landing_released[side]=false

func _smooth5(u: float) -> float:
	u=clampf(u,0,1);return u*u*u*(10+u*(-15+6*u))

func advance_jump(state: String, age: float, vy: float, launch: float, to_floor: float, delta: float) -> void:
	jump_state=state;jump_age=age
	var previous:=jump_frame
	match state:
		# Omit the source's quiet ready hold. Its authored curves already ease
		# the force gathering; a second quintic warp over-compresses the arm
		# reversal into one render sample at gameplay speed.
		"PREP":jump_frame=7+12*clampf(age/.20,0,1)
		"AIR":
			var target:=33.0
			if vy>0:
				target=19+14*_smooth5(1-vy/maxf(launch,.01))
			else:
				falling_time+=delta
				target=lerpf(33.0,41.5,1-exp(-falling_time*5))
				if fall_entry:target=lerpf(43.0,44.0,1-exp(-falling_time*2))
				target=lerpf(target,45.0,_smooth5(1-to_floor/.20))
			# A short/early flight may omit part of the large air gesture. Do not
			# cram the entire silhouette change into a few30FPS samples.
			jump_frame=move_toward(jump_frame,target,45*delta)
		"LAND":
			if age<.10:jump_frame=lerpf(46,51,_smooth5(age/.10))
			elif age<.22:jump_frame=lerpf(51,55,_smooth5((age-.10)/.12))
			elif age<.42:jump_frame=lerpf(55,67,_smooth5((age-.22)/.20))
			else:jump_frame=lerpf(67,93,_smooth5((age-.42)/.43))
	jump_frame_rate=(jump_frame-previous)/maxf(delta,.00001)
	last_jump_frame=jump_frame
	support_left=_support(0);support_right=_support(1)

func _target_pose(bone: int, ahead: float=0.0) -> Transform3D:
	var locomotion:=super._target_pose(bone,ahead)
	if jump_clip==null or jump_state=="GROUND":return locomotion
	var time:=clampf((jump_frame-1+jump_frame_rate*ahead)/30.0,0,jump_clip.clip.length)
	var pose:=Transform3D(Basis(jump_clip.rotation(bone,time)),jump_clip.position(bone,time))
	var leg:=bone==leg_left or bone==leg_right
	var weight:=1.0
	if jump_state=="PREP" and leg and move_requested:weight=.35*_smooth5(jump_age/.18)
	if jump_state=="AIR" and leg and move_requested:weight=.88
	if jump_state=="LAND":
		if move_requested:
			if leg:weight=1-_smooth5((jump_age-.08)/.24)
			elif bone in [hips,chest] or skeleton.get_bone_name(bone)=="Spine":weight=1-_smooth5((jump_age-.14)/.40)
			else:weight=1-_smooth5((jump_age-.18)/.47)
		else:weight=1-_smooth5((jump_age-.40)/.45)
	var result:=Transform3D(Basis(locomotion.basis.get_rotation_quaternion().slerp(pose.basis.get_rotation_quaternion(),weight).normalized()),locomotion.origin.lerp(pose.origin,weight))
	if heavier_landing and jump_state=="LAND":
		# A contact-only pose accent, after the normal gait blend. Legs and
		# horizontal physics keep their original clocks and release schedule.
		var age:=jump_age+ahead
		var load:=_smooth5(age/.10)*(1-_smooth5((age-.16)/.24))
		if bone==hips:result.origin.y-=lerpf(.020,.040,landing_run_weight)*load
		if bone==chest:result.basis=Basis(Vector3.RIGHT,deg_to_rad(lerpf(1.5,3.0,landing_run_weight))*load)*result.basis
	return result

func _support(side: int) -> bool:
	if jump_state=="AIR":return false
	if jump_state=="LAND" and landing_released[side]:return false
	if jump_state=="LAND" and jump_age<.08:return side==0 or jump_age>.025
	return super._support(side)

func _sole_world(bone: int) -> Vector3:
	var result:=super._sole_world(bone)
	# The inherited flat-contact solver works in a floor-relative vertical frame.
	result.y-=contact_floor_y
	return result

func begin_landing_replant() -> void:
	landing_replant=true;settling=true;settle_time=0.0
	replant_first=0 if last_sole[0].y>last_sole[1].y else 1
	for side in 2:
		replant_from[side]=last_sole[side];replant_q[side]=_leg_world_rotation([leg_left,leg_right][side])

func _limit_contact_correction(correction: Vector3) -> Vector3:
	# During impact-to-stride release, horizontal anchor demand may exceed the
	# safety radius. Keep sole clearance first, then release excess horizontal
	# anchoring inside that same radius instead of driving the boot underground.
	var vertical:=clampf(correction.y,-.14,.14)
	var planar:=Vector2(correction.x,correction.z).limit_length(sqrt(maxf(0,.14*.14-vertical*vertical)))
	return Vector3(planar.x,vertical,planar.y)

func _stride_distance() -> float:
	return super._stride_distance()*lerpf(sqrt(1.5),1.2*sqrt(1.15),gait_run_weight)

func _advance_facing(target_yaw: float,delta: float) -> void:
	var maximum:=4.5*review_pace
	var desired:=clampf(wrapf(target_yaw-rotation.y,-PI,PI)*14,-maximum,maximum)
	facing_velocity=move_toward(facing_velocity,desired,maximum/.09*delta)
	rotation.y+=facing_velocity*delta

func _rest_facing(delta: float) -> void:
	facing_velocity=move_toward(facing_velocity,0,4.5*review_pace/.09*delta)
	rotation.y+=facing_velocity*delta

func reset_review() -> void:
	jump_state="GROUND";jump_age=0;jump_frame=1;landing_replant=false;falling_time=0
	landing_clearance_lift=0;super.reset_review()

func _support_adaptation_active() -> bool:
	return move_requested or jump_state=="LAND"

func _use_cached_contact_solve() -> bool:
	return move_requested or jump_state=="LAND"

func _evaluate_locomotion_pose(delta: float) -> bool:
	if jump_state=="LAND":pivot_contact_ids=contact_ids.duplicate()
	var evaluated:=super._evaluate_locomotion_pose(delta)
	if snappy_clips.is_empty() or foot_anchors.size()!=2:return evaluated
	# Same stride scaling as the existing fast Expressive lab, without
	# increasing vertical foot lift or scaling rigid mesh geometry.
	var weight:=1.0 if move_requested else 0.0
	if jump_state=="PREP":weight*=1-.35*_smooth5(jump_age/.18)
	if jump_state=="AIR":weight*=.12
	if jump_state=="LAND":weight*=_smooth5((jump_age-.08)/.24)
	var factor:=lerpf(sqrt(1.5),1.2*sqrt(1.15),gait_run_weight)
	skeleton.force_update_all_bone_transforms()
	var hip_world: Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(hips)).origin
	var forward:=Vector3(sin(rotation.y),0,cos(rotation.y))
	if weight>0:
		for bone in [leg_left,leg_right]:
			var raw:=_sole_world(bone)
			var target: Vector3=raw+forward*((raw-hip_world).dot(forward)*(factor-1)*weight)
			var origin: Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(bone)).origin
			var reference:=_leg_world_rotation(bone);var q:=reference
			for iteration in 2:
				var basis:=Basis(q)
				var destination:=target+Vector3(0,contact_floor_y+.1125*(absf(basis.x.y)+absf(basis.z.y)),0)
				q=(Quaternion(Basis(reference).y.normalized(),(destination-origin).normalized())*reference).normalized()
			_set_world_leg_rotation(bone,q)
			var correction:=target-_sole_world(bone)
			var parent:=skeleton.get_bone_parent(bone)
			var basis:=skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
			skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone)+basis.inverse()*correction)
			skeleton.force_update_all_bone_transforms()
	# Keep the existing35mm clearance bound during landing and preparation.
	# Combining the hoppy Walk with the jump's force-gathering pose can lower
	# a free leg beyond the140mm contact budget before takeoff. Raise the hips
	# only by that excess rather than clipping the boot through the floor.
	var needed:=0.0
	if jump_state in ["LAND","PREP"]:
		for bone in [leg_left,leg_right]:needed=maxf(needed,-_sole_world(bone).y-.135)
	landing_clearance_lift=maxf(clampf(needed,0,.035),move_toward(landing_clearance_lift,0,.25*delta))
	var parent:=skeleton.get_bone_parent(hips)
	var basis:=skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis
	skeleton.set_bone_pose_position(hips,skeleton.get_bone_pose_position(hips)+basis.inverse()*Vector3.UP*landing_clearance_lift)
	skeleton.force_update_all_bone_transforms()
	if move_requested:
		for side in 2:
			if not foot_support[side] or not _support(side):continue
			var bone: int=[leg_left,leg_right][side]
			var reference:=_leg_world_rotation(bone)
			var candidate:=_contact_leg_rotation(side,bone,foot_anchors[side],reference,delta)
			_set_world_leg_rotation(bone,candidate)
			var parent_basis:=skeleton.global_basis*skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
			var carried:=parent_basis*(skeleton.get_bone_pose_position(bone)-_p[bone])
			var demand:=carried+foot_anchors[side]-_sole_world(bone)
			_set_world_leg_rotation(bone,reference)
			if demand.length()>.12:
				early_release[side]=true;turn_release_count+=1
				if jump_state=="LAND":landing_released[side]=true
	return evaluated

func _swing_leg_rotation(side: int,bone: int,delta: float) -> Quaternion:
	var q:=super._swing_leg_rotation(side,bone,delta)
	# Runtime stride adaptation and release share the same rigid-joint budget;
	# independently capping each offset would exceed the inherited140mm guard.
	var basis:=skeleton.global_basis*skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
	var carried:=basis*(skeleton.get_bone_pose_position(bone)-_p[bone])
	var vertical:=clampf(carried.y,-.13,.13)
	var planar:=Vector2(carried.x,carried.z).limit_length(sqrt(maxf(0,.13*.13-vertical*vertical)))
	var bounded:=Vector3(planar.x,vertical,planar.y)
	skeleton.set_bone_pose_position(bone,_p[bone]+basis.inverse()*bounded)
	return q
