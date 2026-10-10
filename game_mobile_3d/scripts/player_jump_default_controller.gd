extends "res://scripts/cuboid_player.gd"
## WorldMap review only. Physics owns travel; the source Action owns the pose.
const TAKEOFF := 4.0/30.0
const CONTACT := 18.0/30.0
const DURATION := 0.8
const FLIGHT := CONTACT-TAKEOFF
const JUMP_HEIGHT := 0.63
const JUMP_GRAVITY := 8.0*JUMP_HEIGHT/(FLIGHT*FLIGHT)
const JUMP_SPEED := 4.0*JUMP_HEIGHT/FLIGHT
var jump_active := false
var jump_time := 0.0
var _airborne := false
var _landed := false
var _vertical_speed := 0.0

func request_jump() -> bool:
	if is_dead or jump_active or not is_on_floor() or smooth_step_active: return false
	jump_active=true; jump_time=0.0; _airborne=false; _landed=false
	_smooth_step_up.reset()
	visual.set_jump_state(true,0.0)
	return true

func cancel_jump() -> void:
	jump_active=false; jump_time=0.0; _airborne=false; _landed=false
	_smooth_step_up.reset()
	visual.set_jump_state(false,0.0)

func _physics_process(delta: float) -> void:
	if is_dead and jump_active: cancel_jump()
	if Input.is_action_just_pressed("jump"): request_jump()
	super._physics_process(delta)

func _before_vertical_move(direction: Vector3, delta: float) -> bool:
	if not jump_active: return super._before_vertical_move(direction,delta)
	jump_time+=delta
	if _landed:
		if jump_time>=DURATION:
			cancel_jump()
			return super._before_vertical_move(direction,delta)
		velocity.y=0.0 if is_on_floor() else velocity.y-gravity*delta
	elif not _airborne and jump_time<=TAKEOFF+0.000001:
		if not is_on_floor():
			cancel_jump()
			return super._before_vertical_move(direction,delta)
		velocity.y=0.0
	else:
		if not _airborne:
			_airborne=true; _vertical_speed=JUMP_SPEED
		# Midpoint integration preserves the authored 0.63m ballistic flight at
		# both 30/60Hz. move_and_slide still resolves ceilings, walls and floors.
		velocity.y=_vertical_speed-JUMP_GRAVITY*delta*.5
		_vertical_speed-=JUMP_GRAVITY*delta
	visual.set_jump_state(true,minf(jump_time,CONTACT-1.0/30.0) if not _landed else jump_time)
	return false

func _after_vertical_move(was_grounded: bool, stepping: bool) -> void:
	if not jump_active:
		super._after_vertical_move(was_grounded,stepping)
		return
	if _airborne and not _landed:
		if is_on_ceiling(): _vertical_speed=minf(_vertical_speed,0.0)
		if is_on_floor():
			_landed=true; jump_time=CONTACT; velocity.y=0.0
			visual.set_jump_state(true,jump_time)
