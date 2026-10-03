class_name SurvivorZombie
extends CharacterBody2D

signal died(at: Vector2)

@export var speed: float = 65.0
@export var max_health: int = 3
var health: int = 3
var target: SurvivorPlayer
var dead: bool = false
var hit_time: float = 0.0
@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	health = max_health
	add_to_group("zombies")
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if dead:
		return
	hit_time = maxf(0.0, hit_time - delta)
	sprite.modulate = Color(3, 1.2, 1.2) if hit_time > 0.0 else Color.WHITE
	if not is_instance_valid(target) or target.dead:
		velocity = Vector2.ZERO
		sprite.play("idle")
		return
	var offset := target.global_position - global_position
	velocity = offset.normalized() * speed if offset.length() > 22.0 else Vector2.ZERO
	move_and_slide()
	sprite.play("walk" if velocity.length_squared() > 1.0 else "idle")
	if absf(offset.x) > 1.0:
		sprite.flip_h = offset.x < 0.0
	if offset.length() < 30.0:
		target.take_damage(10)
	queue_redraw()

func take_damage(amount: int) -> void:
	if dead:
		return
	health -= amount
	hit_time = 0.14
	Sound.play(&"zombie_hit")
	if health <= 0:
		dead = true
		remove_from_group("zombies")
		Sound.play(&"zombie_death")
		died.emit(global_position)
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 5), 16, Color(0, 0, 0, 0.25))
	if health < max_health and not dead:
		draw_rect(Rect2(-16, -65, 32, 4), Color("402832"))
		draw_rect(Rect2(-16, -65, 32.0 * health / max_health, 4), Color("ec7580"))
