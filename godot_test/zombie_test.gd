extends Node2D

const MOVE_SPEED: float = 120.0

@onready var zombie: AnimatedSprite2D = $Zombie


func _ready() -> void:
	zombie.position = get_viewport_rect().size * 0.5
	zombie.play(&"idle")


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if direction == Vector2.ZERO:
		zombie.play(&"idle")
	else:
		zombie.position += direction * MOVE_SPEED * delta
		if direction.x != 0.0:
			zombie.flip_h = direction.x < 0.0
		zombie.play(&"walk")
