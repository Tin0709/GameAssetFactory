extends "res://scenes/dev/expressive_locomotion_visual.gd"
## Pending Jump V2 poses, selected by actual physics events rather than a timer arc.
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

func _ready() -> void:
	super._ready()
	jump_clip=Sampler.new(JUMP_LIBRARY.get_animation("Full_Jump_Expressive_v2_Test"),skeleton)

func jump_transition(value: String) -> void:
	var previous_state:=jump_state
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

func drive_locomotion(world_velocity: Vector3, requested: bool, delta: float) -> void:
	var old_phase:=gait_phase;var old_move:=move_requested
	super.drive_locomotion(world_velocity,requested,delta)
	if jump_state!="GROUND":
		if move_requested and not old_move:
			# An input change in flight must not choose a new idle-start stride.
			gait_phase=fposmod(old_phase+gait_frequency*delta,1.0)
		if not landing_replant:settling=false

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
