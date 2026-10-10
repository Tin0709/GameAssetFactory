extends "res://scripts/player_jump_loop_v003_controller.gd"
## The same complete, nonperiodic Jump + Land for all user-selected travel states.
const V004_PROFILE := {"action":"Jump_DungeonsII_Combined_v004", "takeoff":5.0/30.0,
	"contact":22.0/30.0, "end":35.0/30.0, "height":1.2}

func _ready() -> void:
	super._ready()
	jump_profile=V004_PROFILE

func _begin_jump() -> void:
	var moving:=not Input.get_vector("move_left","move_right","move_forward","move_backward").is_zero_approx()
	jump_kind=(&"run" if Input.is_action_pressed("sprint") else &"walk") if moving else &"stationary"
	jump_profile=V004_PROFILE
	var flight:float=jump_profile.contact-jump_profile.takeoff
	_vertical_speed=4.0*jump_profile.height/flight
	_jump_gravity=8.0*jump_profile.height/(flight*flight)
	jump_active=true;jump_time=0.0;_pose_time=0.0;_airborne=false;_landed=false
	_smooth_step_up.reset()
	visual.select_jump(jump_profile.action,jump_profile.end)
	visual.set_jump_state(true,0.0)

func _before_vertical_move(direction:Vector3,delta:float) -> bool:
	if not jump_active:return super._before_vertical_move(direction,delta)
	jump_time+=delta
	if _landed:
		_recovery_elapsed+=delta
		_pose_time=minf(jump_profile.end,jump_profile.contact+_recovery_elapsed)
		if _recovery_elapsed>=_recovery_duration-.000001:
			if is_on_floor() and _running_repeat():_begin_jump()
			else:
				_finish_jump();return super._before_vertical_move(direction,delta)
		velocity.y=0.0 if is_on_floor() else velocity.y-gravity*delta
	elif not _airborne and jump_time<=jump_profile.takeoff+.000001:
		if not is_on_floor():
			_finish_jump();return super._before_vertical_move(direction,delta)
		velocity.y=0.0;_pose_time=jump_time
	else:
		_airborne=true
		velocity.y=_vertical_speed-_jump_gravity*delta*.5
		_vertical_speed-=_jump_gravity*delta
		# A long drop holds the last aerial pose; never loop through takeoff in air.
		_pose_time=minf(jump_time,jump_profile.contact-1.0/120.0)
	visual.set_jump_state(true,_pose_time)
	return false

func _after_vertical_move(was_grounded:bool,stepping:bool) -> void:
	if not jump_active:
		super._after_vertical_move(was_grounded,stepping);return
	if _airborne and not _landed:
		if is_on_ceiling():_vertical_speed=minf(_vertical_speed,0.0)
		if is_on_floor():
			_landed=true;_contact_pose_time=_pose_time;_recovery_elapsed=0.0
			_recovery_duration=jump_profile.end-jump_profile.contact
			# Enter Jump Land on actual contact, retaining the current pose for blending.
			visual.begin_landing(_contact_pose_time,jump_profile.contact)
			_pose_time=jump_profile.contact;jump_time=jump_profile.contact;velocity.y=0.0

