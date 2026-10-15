extends "res://scenes/dev/expressive_locomotion_actor.gd"
## Scene-only physical jump. Source animation observes actual capsule events.
@export var research_jump_height := 1.2
var requested_jump := false
var last_jump_query: Dictionary = {}
var _scripted_jump_held := false
var _floor_initialized := false

func _physics_process(delta: float) -> void:
	var stick := requested_direction if scripted_input else Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var sprint := requested_run if scripted_input else Input.is_action_pressed("sprint")
	var joy := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") if not scripted_input else Vector2.ZERO
	if joy.length() > stick.length():
		stick = joy
	fast_sprinting = sprint and stick.length_squared() > .001
	visual.review_pace = review_pace
	var speed := (run_speed if fast_sprinting else walk_speed) * review_pace
	var desired := stick.limit_length() * speed * analog_strength
	# Identical ground/air planar response to this scene's existing controller.
	var planar := Vector2(velocity.x, velocity.z).move_toward(desired, (deceleration if stick.is_zero_approx() else acceleration) * review_pace * review_pace * delta)
	var jump_pressed := requested_jump and not _scripted_jump_held if scripted_input else Input.is_action_just_pressed("jump")
	_scripted_jump_held = requested_jump if scripted_input else false
	var was_grounded := is_on_floor()
	var takeoff := was_grounded and jump_pressed
	var vertical := -.2 if was_grounded else velocity.y - gravity * delta
	if takeoff:
		vertical = sqrt(2. * gravity * research_jump_height)
	velocity = Vector3(planar.x, vertical, planar.y)
	# move_and_slide clears downward velocity on collision; retain it for impact.
	var incoming_vertical := velocity.y
	move_and_slide()
	var grounded := is_on_floor()
	var landed := _floor_initialized and not was_grounded and grounded
	_floor_initialized = _floor_initialized or grounded
	var actual_velocity := get_real_velocity()
	current_speed = Vector2(actual_velocity.x, actual_velocity.z).length()
	last_jump_query = {
		"grounded": grounded,
		"was_grounded": was_grounded,
		"vertical_speed": 0. if grounded else velocity.y,
		"impact_velocity": incoming_vertical if landed else 0.,
		"takeoff": takeoff,
		"landed": landed,
		"jump_pressed": jump_pressed,
		"sprinting": fast_sprinting,
		"body_position": global_position,
	}
	if visual.has_method("drive_jump_motion"):
		visual.drive_jump_motion(actual_velocity, not stick.is_zero_approx(), last_jump_query, delta)
	else:
		visual.drive_locomotion(actual_velocity, not stick.is_zero_approx(), delta)

func reset_jump_motion() -> void:
	requested_jump = false
	_scripted_jump_held = false
	_floor_initialized = false
	last_jump_query.clear()
