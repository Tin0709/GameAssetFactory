extends Area2D

@export var amount: int = 1
var collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var player := body as SurvivorPlayer
	if collected or player == null or player.dead:
		return
	collected = true
	player.add_experience(amount)
	Sound.play(&"exp_pickup")
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12, Color(0.25, 0.95, 0.7, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(6, 0), Vector2(0, 8), Vector2(-6, 0)]), Color("63efba"))
