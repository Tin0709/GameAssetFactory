extends "res://scenes/dev/actions_stuff_research/source_jump_actor.gd"
## Rifle delegates byte-for-byte to its established actor. Sword has local travel gates.
var melee_controller:Node
var melee_attacker:Node3D
func _physics_process(delta:float)->void:
	if melee_controller==null or not melee_controller.equipped:
		super._physics_process(delta);return
	var step:float=melee_controller.before_motion(delta)
	if step<=0.:return
	var stick:Vector2=requested_direction if scripted_input else Input.get_vector("move_left","move_right","move_forward","move_backward")
	var sprint:bool=requested_run if scripted_input else Input.is_action_pressed("sprint")
	var joy:=Input.get_vector("ui_left","ui_right","ui_up","ui_down") if not scripted_input else Vector2.ZERO
	if joy.length()>stick.length():stick=joy
	fast_sprinting=sprint and stick.length_squared()>.001
	visual.review_pace=review_pace
	var speed:float=(run_speed if fast_sprinting else walk_speed)*review_pace
	var desired:Vector2=melee_controller.motion_velocity(stick.limit_length()*speed*analog_strength)
	var planar:=Vector2(velocity.x,velocity.z).move_toward(desired,(deceleration if desired.is_zero_approx() else acceleration)*review_pace*review_pace*step)
	if melee_controller.state.state==&"roll":planar=desired
	var jump_pressed:bool=(requested_jump and not _scripted_jump_held if scripted_input else Input.is_action_just_pressed("jump")) and not melee_controller.locks_jump()
	_scripted_jump_held=requested_jump if scripted_input else false
	var was_grounded:=is_on_floor() and velocity.y<=0.
	var takeoff:=was_grounded and jump_pressed
	var vertical:float=-.2 if was_grounded else velocity.y-gravity*step
	if takeoff:vertical=sqrt(2.*gravity*research_jump_height)
	velocity=Vector3(planar.x,vertical,planar.y)
	var incoming_vertical:=velocity.y
	move_and_slide()
	var grounded:=is_on_floor() and velocity.y<=0.
	var landed:=_floor_initialized and not was_grounded and grounded
	_floor_initialized=_floor_initialized or grounded
	var actual_velocity:=get_real_velocity();current_speed=Vector2(actual_velocity.x,actual_velocity.z).length()
	last_jump_query={"grounded":grounded,"was_grounded":was_grounded,"vertical_speed":0. if grounded else velocity.y,"impact_velocity":incoming_vertical if landed else 0.,"takeoff":takeoff,"landed":landed,"jump_pressed":jump_pressed,"sprinting":fast_sprinting,"body_position":global_position}
	visual.drive_jump_motion(actual_velocity,not stick.is_zero_approx(),last_jump_query,step)
	melee_controller.after_pose()
func take_damage(amount:int,direction:Vector3=Vector3.ZERO)->bool:
	if melee_controller!=null and melee_controller.equipped:return melee_controller.receive_attack(amount,direction,melee_attacker)
	return super.take_damage(amount,direction)
