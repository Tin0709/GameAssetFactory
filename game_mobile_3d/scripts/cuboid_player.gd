extends CharacterBody3D
## Responsive world-space acceleration with rigid visual rotation.

@export var walk_speed: float = 4.25
@export var run_speed: float = 6.25
@export var acceleration: float = 42.0
@export var deceleration: float = 60.0
@export var walk_cycle_speed: float = 1.55
@export var run_cycle_speed: float = 2.8
@export var turn_speed: float = 16.0
@export var gravity: float = 18.0
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

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: int) -> bool:
	if is_dead or amount <= 0 or hurt_remaining > 0.0:
		return false
	current_hp = maxi(0, current_hp - amount)
	hurt_remaining = hurt_grace_period
	visual.flash_hit()
	if is_instance_valid(combat): combat.play_sound(&"player_hurt")
	health_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		is_dead = true
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
	if is_dead: return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input.x, 0.0, input.y)
	var running := Input.is_action_pressed("sprint") and not input.is_zero_approx()
	var speed := run_speed if running else walk_speed
	var horizontal := Vector2(velocity.x, velocity.z)
	var desired := Vector2(direction.x, direction.z) * speed
	horizontal = horizontal.move_toward(desired, (deceleration if direction.is_zero_approx() else acceleration) * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	var actual_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	current_speed = actual_speed
	var target: Node3D = $Pistol.nearest_target() if $Pistol.enabled else null
	visual.update_motion(get_real_velocity(), target, delta)
