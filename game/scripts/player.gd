class_name SurvivorPlayer
extends CharacterBody2D

signal stats_changed
signal died

@export var speed: float = 220.0
@export var max_health: int = 100
var health: int = 100
var level: int = 1
var experience: int = 0
var experience_required: int = 5
var invulnerability: float = 0.0
var dead: bool = false

func _ready() -> void:
	health = max_health

func _physics_process(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	if dead:
		velocity = Vector2.ZERO
		return
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * speed
	move_and_slide()
	queue_redraw()

func take_damage(amount: int) -> void:
	if dead or invulnerability > 0.0:
		return
	health = maxi(0, health - amount)
	invulnerability = 0.75
	stats_changed.emit()
	if health == 0:
		dead = true
		died.emit()
	queue_redraw()

func add_experience(amount: int) -> void:
	if dead or amount <= 0:
		return
	experience += amount
	while experience >= experience_required:
		experience -= experience_required
		level += 1
		experience_required = 5 + (level - 1) * 3
		Sound.play(&"level_up")
	stats_changed.emit()

func _draw() -> void:
	draw_circle(Vector2(0, 5), 18, Color(0, 0, 0, 0.3))
	var color := Color("62c9ef") if invulnerability <= 0.0 else Color("ffffff")
	if dead:
		color = Color("6d7881")
	draw_circle(Vector2.ZERO, 14, color)
	draw_arc(Vector2.ZERO, 17, 0, TAU, 32, Color("bceeff"), 2.0)
	draw_circle(Vector2(0, -4), 5, Color("173442"))
