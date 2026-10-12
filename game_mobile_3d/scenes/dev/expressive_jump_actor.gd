extends "res://scenes/dev/expressive_locomotion_actor.gd"
## Isolated jump physics. No production controller or authored Action changes.
@export var jump_height:=1.2
@export_range(1.0,2.4,.01) var jump_flight_speed:=1.0
@export_range(1.0,1.3,.01) var running_air_speed_scale:=1.0
var _active_flight_speed:=1.0
var _prepared_flight:=false
const PREP_SECONDS:=.20
const BUFFER_SECONDS:=.14
var jump_state:="GROUND"
var jump_age:=0.0
var jump_buffer:=0.0
var launch_velocity:=0.0
var impact_velocity:=0.0
var floor_y:=0.0
var time_to_contact:=10.0
var jump_events: Array=[]
var jump_count:=0
var simulation_time:=0.0
var _space_down:=false
var _idle_replant_started:=false

func request_jump() -> void:
	jump_buffer=BUFFER_SECONDS

func _state(value: String) -> void:
	if value=="AIR":_prepared_flight=jump_state=="PREP"
	else:_prepared_flight=false
	if value!="AIR" or jump_state!="PREP":_active_flight_speed=1.0
	jump_state=value;jump_age=0.0
	jump_events.append({"event":value,"time":simulation_time,"position":[position.x,position.y,position.z],"vy":velocity.y,"phase":visual.gait_phase,"speed":current_speed,"jump":jump_count})
	visual.jump_transition(value)
	_idle_replant_started=false

func _physics_process(delta: float) -> void:
	simulation_time+=delta;jump_age+=delta
	var space:=Input.is_physical_key_pressed(KEY_SPACE) if not scripted_input else false
	if space and not _space_down:request_jump()
	_space_down=space
	var stick:=requested_direction if scripted_input else Input.get_vector("move_left","move_right","move_forward","move_backward")
	var sprint:=requested_run if scripted_input else Input.is_action_pressed("sprint")
	var joy:=Input.get_vector("ui_left","ui_right","ui_up","ui_down") if not scripted_input else Vector2.ZERO
	if joy.length()>stick.length():stick=joy
	fast_sprinting=sprint and stick.length_squared()>.001
	visual.review_pace=review_pace
	var desired:=stick.limit_length()*(run_speed if fast_sprinting else walk_speed)*review_pace*analog_strength
	if fast_sprinting and jump_state=="AIR" and _prepared_flight:desired*=running_air_speed_scale
	var planar:=Vector2(velocity.x,velocity.z).move_toward(desired,(deceleration if stick.is_zero_approx() else acceleration)*review_pace*review_pace*delta)
	var grounded:=is_on_floor()
	if jump_buffer>0 and grounded and (jump_state=="GROUND" or jump_state=="LAND" and jump_age>=.10):
		jump_buffer=0;_state("PREP")
	jump_buffer=maxf(0,jump_buffer-delta)
	var launched:=false
	if jump_state=="PREP" and jump_age>=PREP_SECONDS and grounded:
		# Scale acceleration and launch together: shorter physics flight at
		# the same height. Latch the candidate so midair comparisons cannot pop.
		_active_flight_speed=jump_flight_speed
		var flight_gravity:=_flight_gravity()
		launch_velocity=sqrt(2*flight_gravity*jump_height)
		# Half-step launch gravity avoids adding an extra physics tick of height.
		velocity.y=launch_velocity-flight_gravity*delta*.5
		jump_count+=1;launched=true;_state("AIR")
	elif grounded:velocity.y=-.2
	else:velocity.y-=_flight_gravity()*delta
	velocity.x=planar.x;velocity.z=planar.y
	var incoming_y:=velocity.y
	move_and_slide()
	if not is_on_floor() and jump_state in ["GROUND","PREP","LAND"]:
		launch_velocity=maxf(velocity.y,1.0);_state("AIR")
	if not grounded and is_on_floor() and not launched and jump_state=="AIR":
		impact_velocity=absf(incoming_y);_state("LAND")
		# An eligible pre-contact press survives the brief impact absorption.
		if jump_buffer>0:jump_buffer=maxf(jump_buffer,.13)
	if jump_state=="LAND" and jump_age>=.85:_state("GROUND")
	current_speed=Vector2(get_real_velocity().x,get_real_velocity().z).length()
	_probe_floor()
	visual.contact_floor_y=floor_y
	visual.drive_locomotion(get_real_velocity(),not stick.is_zero_approx(),delta)
	visual.advance_jump(jump_state,jump_age,velocity.y,launch_velocity,time_to_contact,delta)
	if jump_state=="LAND" and current_speed<.025 and jump_age>.40 and not _idle_replant_started:
		_idle_replant_started=true;visual.begin_landing_replant()

func _probe_floor() -> void:
	var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3(0,.12,0),global_position-Vector3(0,80,0),1,[get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not is_on_floor() and not hit.is_empty():floor_y=hit.position.y
	if is_on_floor():
		# A capsule can still be supported at a ledge while its center ray has
		# crossed the edge. Actual supporting collision owns the contact plane.
		# Keep the last contact plane if this tick reports floor support without
		# a fresh upward collision; a center ray beyond the ledge is not contact.
		for i in get_slide_collision_count():
			var collision:=get_slide_collision(i)
			if collision.get_normal().dot(Vector3.UP)>.65:floor_y=collision.get_position().y;break
	var height:=maxf(0,global_position.y-floor_y)
	var flight_gravity:=_flight_gravity()
	time_to_contact=(velocity.y+sqrt(velocity.y*velocity.y+2*flight_gravity*height))/flight_gravity

func _flight_gravity() -> float:
	return gravity*_active_flight_speed*_active_flight_speed

func review_drop(height: float=6.0) -> void:
	position=Vector3(0,height,0);velocity=Vector3.ZERO
	jump_buffer=0;launch_velocity=1.0;_state("AIR")
	visual.foot_support[0]=false;visual.foot_support[1]=false;visual.settling=false

func reset_jump() -> void:
	_active_flight_speed=1.0
	_prepared_flight=false
	jump_buffer=0;velocity=Vector3.ZERO;floor_y=0;time_to_contact=10
	jump_state="GROUND";jump_age=0;visual.jump_transition("GROUND")
	visual.contact_floor_y=0;visual.settling=false
