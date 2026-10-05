extends Node3D
## One swept ray per physics tick avoids tunneling at 14 m/s; no rigid-body bullet.

@export var speed: float = 14.0
@export var lifetime: float = 0.9
@export var damage: int = 20
var direction: Vector3 = Vector3.FORWARD
var combat: Node
var age: float = 0.0
var spent: bool = false

func _physics_process(delta: float) -> void:
	if spent: return
	if not is_instance_valid(combat) or not combat.active:
		queue_free()
		return
	age += delta
	if age >= lifetime:
		spent = true
		queue_free()
		return
	var destination := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, 5)
	query.exclude = [combat.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spent = true
		var collider: Object = hit.collider
		if collider.has_method("take_damage") and collider.is_in_group("zombies"):
			collider.take_damage(damage, direction)
		combat.play_sound(&"bullet_impact")
		combat.spawn_impact(hit.position)
		queue_free()
	else:
		global_position = destination
