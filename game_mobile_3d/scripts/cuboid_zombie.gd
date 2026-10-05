extends CharacterBody3D
## Rigid whole-limb shamble, timed melee windup, and a tweened whole-body death.

@export var move_speed: float = 0.6
@export var detection_range: float = 6.5
@export var lose_target_range: float = 8.0
@export var stop_distance: float = 1.05
@export var turn_speed: float = 5.0
@export var gravity: float = 18.0
@export var max_hp: int = 60
@export var attack_damage: int = 10
@export var attack_range: float = 1.15
@export var attack_interval: float = 1.10
@export var attack_windup: float = 0.12
@export var knockback_speed: float = 1.1
@export var knockback_decay: float = 13.0
@export var death_duration: float = 0.55
@onready var visual: Node3D = $Visual
var target: Node3D
var combat: Node
var current_hp: int = 60
var is_dead: bool = false
var chasing: bool = false
var holding_distance: bool = false
var attack_cooldown: float = 0.0
var pending_attack: float = -1.0
var attack_visual_remaining: float = 0.0
var knockback: Vector3 = Vector3.ZERO

func _ready() -> void:
	current_hp = max_hp
	target = get_tree().get_first_node_in_group("player") as Node3D

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO) -> bool:
	if is_dead or amount <= 0: return false
	current_hp = maxi(0, current_hp - amount)
	visual.flash_hit()
	if is_instance_valid(combat): combat.play_sound(&"zombie_hit")
	if current_hp == 0:
		_begin_death(direction)
	else:
		direction.y = 0.0
		knockback += direction.normalized() * knockback_speed
	return true

func _begin_death(direction: Vector3) -> void:
	is_dead = true
	chasing = false
	pending_attack = -1.0
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	visual.freeze_animation()
	if is_instance_valid(combat): combat.enemy_death_started(self)
	# Rotate the entire visual; individual cuboids never bend, squash or scale.
	var fall_side := -1.0 if direction.x < 0.0 else 1.0
	var fallen := Vector3(-0.22, visual.rotation.y, fall_side * 1.48)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation", fallen, death_duration * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "position:y", 0.12, death_duration * 0.75)
	tween.chain().tween_interval(death_duration * 0.25)
	tween.chain().tween_callback(_finish_death)

func _finish_death() -> void:
	if is_instance_valid(combat): combat.spawn_exp(global_position)
	queue_free()

func _physics_process(delta: float) -> void:
	if is_dead or (is_instance_valid(combat) and not combat.active): return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	attack_visual_remaining = maxf(0.0, attack_visual_remaining - delta)
	var direction := Vector3.ZERO
	if is_instance_valid(target) and not target.is_dead:
		var offset := target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if chasing and distance > lose_target_range:
			chasing = false
		elif not chasing and distance <= detection_range:
			chasing = true
		if distance <= stop_distance:
			holding_distance = true
		elif distance > stop_distance + 0.20:
			holding_distance = false
		var fighting: bool = is_instance_valid(combat) and combat.can_fight()
		if fighting and distance > attack_range: holding_distance = false
		if pending_attack >= 0.0:
			pending_attack -= delta
			if pending_attack <= 0.0:
				pending_attack = -1.0
				if fighting and distance <= attack_range: target.take_damage(attack_damage)
		if fighting and distance <= attack_range and attack_cooldown == 0.0:
			attack_cooldown = attack_interval
			pending_attack = attack_windup
			attack_visual_remaining = 0.28
			holding_distance = true
			visual.attack_lunge()
			combat.play_sound(&"zombie_attack")
		if chasing and not holding_distance: direction = offset.normalized()
		visual.face_direction(offset, delta, turn_speed)
	else:
		chasing = false
		pending_attack = -1.0
	velocity.x = direction.x * move_speed + knockback.x
	velocity.z = direction.z * move_speed + knockback.z
	knockback *= exp(-knockback_decay * delta)
	if is_on_floor(): velocity.y = 0.0
	else: velocity.y -= gravity * delta
	move_and_slide()
	if is_instance_valid(combat) and not combat.active: return
	var actual_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if attack_visual_remaining > 0.0:
		return
	if direction.is_zero_approx() or actual_speed < 0.025:
		visual.play_state(&"Idle")
	else:
		visual.play_state(&"Walk", clampf(actual_speed / 0.60, 0.65, 1.4))
