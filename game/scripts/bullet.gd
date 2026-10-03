extends Node2D
## Sweep each physics step so fast bullets cannot tunnel through a zombie.

@export var speed: float = 700.0
@export var damage: int = 1
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 1.5

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var next_position := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next_position, 2)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var zombie := hit.collider as SurvivorZombie
		if zombie != null and not zombie.dead:
			zombie.take_damage(damage)
			Sound.play(&"bullet_impact")
		queue_free()
		return
	global_position = next_position
	rotation = direction.angle()

func _draw() -> void:
	draw_line(Vector2(-8, 0), Vector2(3, 0), Color("ffe0a0"), 3.0)
