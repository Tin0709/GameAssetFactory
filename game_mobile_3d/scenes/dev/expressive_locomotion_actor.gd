extends "res://scripts/cuboid_player.gd"
## Test-only capsule. Production controller, weapon and step-up scripts stay intact.
var scripted_input := false
var requested_direction := Vector2.ZERO
var requested_run := false
var analog_strength := 1.0
@export_range(1.0,2.0,.1) var review_pace := 2.0
func _ready() -> void:
	super._ready()
	$Pistol.enabled=false
	$WeaponBehavior.enabled=false
	# The production disabled-behavior mode automatically equips on its first
	# tick. This lab's explicit upper-layer toggle owns that decision instead.
	$WeaponBehavior.set_physics_process(false)
	visual.weapon_equipped=false
	visual.socket.set_equipped_visible(false)
	smooth_step_up_enabled=false
	visual.review_pace=review_pace
func _physics_process(delta: float) -> void:
	var stick:=requested_direction if scripted_input else Input.get_vector("move_left","move_right","move_forward","move_backward")
	var sprint:=requested_run if scripted_input else Input.is_action_pressed("sprint")
	var joy:=Input.get_vector("ui_left","ui_right","ui_up","ui_down") if not scripted_input else Vector2.ZERO
	if joy.length()>stick.length():stick=joy
	fast_sprinting=sprint and stick.length_squared()>.001
	visual.review_pace=review_pace
	var speed:=(run_speed if fast_sprinting else walk_speed)*review_pace
	var desired:=stick.limit_length()*speed*analog_strength
	# Double speed in half the ramp time, without changing global physics time.
	var planar:=Vector2(velocity.x,velocity.z).move_toward(desired,(deceleration if stick.is_zero_approx() else acceleration)*review_pace*review_pace*delta)
	velocity=Vector3(planar.x,-.2 if is_on_floor() else velocity.y-gravity*delta,planar.y)
	move_and_slide()
	current_speed=Vector2(get_real_velocity().x,get_real_velocity().z).length()
	visual.drive_locomotion(get_real_velocity(),not stick.is_zero_approx(),delta)
func set_review_weapon(enabled: bool) -> void:
	if enabled:
		var behavior: Node=visual.weapon_behavior
		visual.weapon_behavior=null
		visual.equip_weapon(1)
		# This layer preview already has its own continuous log-space blend.
		# Do not also blend against the old captured weapon-switch arm pose.
		visual.switch_weight=1.0
		visual.weapon_behavior=behavior
		visual.socket.attach_equipped(&"hand")
	visual.weapon_equipped=enabled
	visual.socket.visible=enabled
	visual.socket.set_equipped_visible(enabled)
	$Pistol.enabled=false
