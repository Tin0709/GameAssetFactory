extends CharacterBody3D
## Immediate world-space movement; rotate only the visual so physics stays simple.

@export var walk_speed: float = 1.3
@export var run_speed: float = 2.8
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
var is_dead: bool = false
var hurt_remaining: float = 0.0
var combat: Node

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
	experience += value
	exp_changed.emit(experience)

func _physics_process(delta: float) -> void:
	hurt_remaining = maxf(0.0, hurt_remaining - delta)
	if is_dead: return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input.x, 0.0, input.y)
	var running := Input.is_action_pressed("sprint") and not input.is_zero_approx()
	var speed := run_speed if running else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	visual.face_direction(direction, delta, turn_speed)
	var actual_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if actual_speed < 0.04:
		visual.play_state(&"Idle")
	elif running:
		visual.play_state(&"Run", clampf(actual_speed / 1.65, 0.65, 1.8))
	else:
		visual.play_state(&"Walk", clampf(actual_speed / 0.82, 0.65, 1.8))
