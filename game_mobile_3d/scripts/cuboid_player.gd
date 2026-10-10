extends CharacterBody3D
## Responsive world-space acceleration with rigid visual rotation.

@export var walk_speed: float = 4.25
@export var run_speed: float = 6.25
@export var combat_move_speed: float = 2.6
@export var firing_speed_threshold: float = 3.0
@export var acceleration: float = 42.0
@export var deceleration: float = 60.0
@export var walk_cycle_speed: float = 1.55
@export var run_cycle_speed: float = 2.8
@export var turn_speed: float = 16.0
@export var gravity: float = 18.0
@export var smooth_step_up_enabled: bool = true
@export var smooth_step_up_min_height: float = 0.12
@export var smooth_step_up_max_height: float = 1.05
@export var smooth_step_up_duration: float = 0.32
@export var max_hp: int = 100
@export var hurt_grace_period: float = 0.35
@onready var visual: Node3D = $Visual
signal health_changed(hp: int, maximum: int)
signal exp_changed(value: int)
signal defeated
var current_hp: int = 100
var experience: int = 0
var total_experience: int = 0
var level: int = 1
var progression: Node
var is_dead: bool = false
var hurt_remaining: float = 0.0
var combat: Node
var current_speed: float = 0.0
## Published from the same input decision that chooses run_speed, not from
## velocity thresholds. Weapon behavior consumes this after controller physics.
var fast_sprinting: bool = false
const FEEDBACK = preload("res://scripts/character_damage_feedback.gd")
var damage_feedback: Node3D
const SMOOTH_STEP_UP = preload("res://scripts/smooth_step_up.gd")
var _smooth_step_up := SMOOTH_STEP_UP.new()
var smooth_step_active: bool:
	get: return _smooth_step_up.active

func _ready() -> void:
	current_hp = max_hp
	damage_feedback = FEEDBACK.new()
	damage_feedback.name = "DamageFeedback"
	damage_feedback.player_hit = true
	add_child(damage_feedback)

func equip_test_weapon(index: int) -> void:
	# Shared test/debug entry point into the existing animation/socket runtime.
	if is_dead or index < 0 or index > 2: return
	visual.equip_weapon(index)
	visual.recoil_time = 100.0
	visual.recoil_gain = 1.0
	visual.queued_recoil = false
	visual.recoil_amount = 0.0
	visual.is_firing = false
	$Pistol.cooldown = 0.15
	$Pistol.select_weapon(index)

func can_fire_moving() -> bool:
	return not is_dead and current_speed <= firing_speed_threshold

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO) -> bool:
	if is_dead or amount <= 0 or hurt_remaining > 0.0:
		return false
	current_hp = maxi(0, current_hp - amount)
	hurt_remaining = hurt_grace_period
	visual.flash_hit()
	visual.hit_impulse(direction)
	damage_feedback.show_hit(amount, current_hp, max_hp, combat.effects if is_instance_valid(combat) else null)
	if is_instance_valid(combat): combat.play_sound(&"player_hurt")
	health_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		is_dead = true
		_smooth_step_up.reset()
		velocity = Vector3.ZERO
		visual.freeze_animation()
		defeated.emit()
	return true

func collect_exp(value: int) -> void:
	if is_dead or value <= 0: return
	if is_instance_valid(progression):
		progression.gain_exp(value)
	else:
		total_experience += value
		experience += value
		exp_changed.emit(experience)

func _physics_process(delta: float) -> void:
	hurt_remaining = maxf(0.0, hurt_remaining - delta)
	if is_dead:
		fast_sprinting = false
		_smooth_step_up.reset()
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input.x, 0.0, input.y)
	fast_sprinting = Input.is_action_pressed("sprint") and not input.is_zero_approx()
	var target: Node3D = $Pistol.nearest_target() if $Pistol.enabled else null
	var speed := run_speed if fast_sprinting else walk_speed
	if target != null and not fast_sprinting: speed = minf(speed, combat_move_speed)
	var horizontal := Vector2(velocity.x, velocity.z)
	var desired := Vector2(direction.x, direction.z) * speed
	horizontal = horizontal.move_toward(desired, (deceleration if direction.is_zero_approx() else acceleration) * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var was_grounded := is_on_floor()
	var stepping := _before_vertical_move(direction, delta)
	move_and_slide()
	_after_vertical_move(was_grounded, stepping)
	_smooth_step_up.after_move(self)
	var actual_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	current_speed = actual_speed
	var visual_velocity := get_real_velocity()
	if smooth_step_active:
		# Keep the existing walking clip moving while the capsule meets the riser.
		visual_velocity.x = desired.x
		visual_velocity.z = desired.y
	visual.update_motion(visual_velocity, target if can_fire_moving() else null, delta)

func _before_vertical_move(direction: Vector3, delta: float) -> bool:
	var stepping := _smooth_step_up.before_move(self, direction, delta, smooth_step_up_enabled, smooth_step_up_min_height, smooth_step_up_max_height, smooth_step_up_duration)
	if not stepping:
		if is_on_floor(): velocity.y = 0.0
		else: velocity.y -= gravity * delta
	return stepping

func _after_vertical_move(was_grounded: bool, stepping: bool) -> void:
	if not stepping and not was_grounded and is_on_floor(): visual.landing_response()
