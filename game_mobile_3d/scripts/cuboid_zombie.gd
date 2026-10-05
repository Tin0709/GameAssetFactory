extends CharacterBody3D
## Rigid whole-limb shamble, timed melee windup, and a tweened whole-body death.

@export var move_speed: float = 2.05
@export var detection_range: float = 6.5
@export var lose_target_range: float = 8.0
@export var stop_distance: float = 1.05
@export var turn_speed: float = 10.0
@export var gravity: float = 18.0
@export var max_hp: int = 60
@export var attack_damage: int = 10
@export var attack_range: float = 1.15
@export var attack_interval: float = 1.10
@export var attack_windup: float = 0.18
@export var knockback_speed: float = 2.4
@export var knockback_decay: float = 16.0
@export var speed_variation: float = 0.08
@export var speed_limit: float = 2.75
@export var persistent_chase: bool = false
@export var walk_cycle_speed: float = 1.0
@export var attack_anticipation: float = 0.10
@export var attack_recovery: float = 0.18
@export var death_duration: float = 0.62
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
var speed_multiplier: float = 1.0
var fall_sign: float = 1.0
const FEEDBACK = preload("res://scripts/character_damage_feedback.gd")
var damage_feedback: Node3D

func _ready() -> void:
	current_hp = max_hp
	damage_feedback = FEEDBACK.new()
	damage_feedback.name = "DamageFeedback"
	add_child(damage_feedback)
	# Stable spawn-position variation: no random work each frame.
	var phase := fposmod(position.x * 0.37 + position.z * 0.61, 1.0)
	speed_multiplier = lerpf(1.0 - speed_variation, 1.0 + speed_variation, phase)
	fall_sign = -1.0 if phase < 0.5 else 1.0
	visual.phase_offset = phase
	visual.rate_variation = lerpf(0.95, 1.05, fposmod(phase * 7.31, 1.0))
	visual.animation_player.seek(phase * visual.animation_player.current_animation_length, true)
	if not is_instance_valid(target): target = get_tree().get_first_node_in_group("player") as Node3D

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO) -> bool:
	if is_dead or amount <= 0: return false
	current_hp = maxi(0, current_hp - amount)
	visual.flash_hit()
	damage_feedback.show_hit(amount, current_hp, max_hp, combat.effects if is_instance_valid(combat) else null)
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
	var fall_side := fall_sign if absf(direction.x) < 0.05 else signf(direction.x)
	var base_rotation := visual.rotation
	var tween := create_tween()
	# Brief recoil, then lose balance, fall, and hold before cleanup.
	tween.tween_property(visual, "rotation", base_rotation + Vector3(-0.06, 0, fall_side * 0.10), 0.055)
	tween.tween_property(visual, "rotation", base_rotation + Vector3(-0.30, 0, fall_side * 0.38), 0.10)
	tween.tween_property(visual, "rotation", base_rotation + Vector3(-0.35, 0, fall_side * 1.48), death_duration - 0.285).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual, "position:y", 0.12, death_duration - 0.285)
	tween.tween_interval(0.13)
	tween.tween_callback(_finish_death)

func _finish_death() -> void:
	if is_instance_valid(combat):
		combat.spawn_death_smoke(visual.to_global(Vector3(0, 0.90, 0)))
		combat.spawn_exp(global_position)
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
		if chasing and not persistent_chase and distance > lose_target_range:
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
			attack_visual_remaining = attack_windup + attack_recovery
			holding_distance = true
			visual.attack_lunge(attack_anticipation, maxf(0.01, attack_windup - attack_anticipation), attack_recovery)
			combat.play_sound(&"zombie_attack")
		if chasing and not holding_distance and attack_visual_remaining == 0.0: direction = offset.normalized()
		visual.face_direction(offset, delta, turn_speed)
	else:
		chasing = false
		pending_attack = -1.0
	var effective_speed := minf(speed_limit, move_speed * speed_multiplier)
	velocity.x = direction.x * effective_speed + knockback.x
	velocity.z = direction.z * effective_speed + knockback.z
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
		visual.play_state(&"Walk", clampf(actual_speed / walk_cycle_speed, 0.5, 2.2))
