extends "res://scripts/cuboid_player.gd"
## Authored periodic pose; capsule physics owns the 1.2m jump and actual contact.
const PROFILES := {
	&"stationary": {"action":"Jump_Stationary_v002","takeoff":4.0/30.0,"contact":20.0/30.0,"end":26.0/30.0,"height":1.2},
	&"walk": {"action":"Jump_Walk_Loop_v003","takeoff":6.0/30.0,"contact":22.0/30.0,"end":28.0/30.0,"height":1.2},
	&"run": {"action":"Jump_Run_Loop_v003","takeoff":4.0/30.0,"contact":20.0/30.0,"end":26.0/30.0,"height":1.2},
}
var jump_active := false
var jump_time := 0.0
var jump_kind: StringName = &"stationary"
var jump_profile: Dictionary = PROFILES[&"stationary"]
var _airborne := false
var _landed := false
var _vertical_speed := 0.0
var _jump_gravity := 0.0
var _pose_time := 0.0
var _contact_pose_time := 0.0

func _running_repeat() -> bool:
	return Input.is_action_pressed("jump") and Input.is_action_pressed("sprint") and not Input.get_vector("move_left","move_right","move_forward","move_backward").is_zero_approx()

func request_jump() -> bool:
	if is_dead or jump_active or not is_on_floor() or smooth_step_active:return false
	_begin_jump()
	return true

func _begin_jump() -> void:
	var moving:=not Input.get_vector("move_left","move_right","move_forward","move_backward").is_zero_approx()
	jump_kind=(&"run" if Input.is_action_pressed("sprint") else &"walk") if moving else &"stationary"
	jump_profile=PROFILES[jump_kind]
	var flight:float=jump_profile.contact-jump_profile.takeoff
	_vertical_speed=4.0*jump_profile.height/flight
	_jump_gravity=8.0*jump_profile.height/(flight*flight)
	jump_active=true;jump_time=0.0;_pose_time=0.0;_airborne=false;_landed=false
	_smooth_step_up.reset()
	visual.select_jump(jump_profile.action,jump_profile.end)
	visual.set_jump_state(true,0.0)

func cancel_jump() -> void:
	jump_active=false;jump_time=0.0;_pose_time=0.0;_airborne=false;_landed=false
	_smooth_step_up.reset();visual.set_jump_state(false,0.0,true)

func _finish_jump() -> void:
	jump_active=false;_airborne=false;_landed=false
	visual.set_jump_state(false,_pose_time)

func _physics_process(delta: float) -> void:
	if is_dead and jump_active:cancel_jump()
	if Input.is_action_just_pressed("jump") or _running_repeat():request_jump()
	super._physics_process(delta)

func _before_vertical_move(direction: Vector3, delta: float) -> bool:
	if not jump_active:return super._before_vertical_move(direction,delta)
	jump_time+=delta
	if _landed:
		var u:float=clampf((jump_time-jump_profile.contact)/(jump_profile.end-jump_profile.contact),0.0,1.0)
		# A raised block may contact early. Advance from the current pose smoothly
		# into recovery instead of snapping directly to the authored contact key.
		_pose_time=lerpf(_contact_pose_time,jump_profile.end,u)
		if jump_time>=jump_profile.end-.000001:
			if is_on_floor() and _running_repeat():
				# End/start match in V003. Keep the visual blend active at this wrap.
				_begin_jump()
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
		# Over a drop, defer recovery until actual collision; no second air jump.
		_pose_time=minf(jump_time,jump_profile.contact-1.0/120.0)
	visual.set_jump_state(true,_pose_time)
	return false

func _after_vertical_move(was_grounded: bool, stepping: bool) -> void:
	if not jump_active:
		super._after_vertical_move(was_grounded,stepping);return
	if _airborne and not _landed:
		if is_on_ceiling():_vertical_speed=minf(_vertical_speed,0.0)
		if is_on_floor():
			_landed=true;_contact_pose_time=_pose_time
			jump_time=jump_profile.contact;velocity.y=0.0
