extends RefCounted
## Isolated three-actor fixture for earlier suites, never used by runtime scenes.
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
static func prepare(level: Node) -> void:
	level.get_node("SpawnDirector").enabled = false
	for point in [Vector3(4, 0.02, -3), Vector3(-4, 0.02, -1), Vector3(-6.5, 0.02, 4.5)]:
		var enemy := ZOMBIE.instantiate()
		enemy.position = point
		level.get_node("Actors").add_child(enemy)
static func after_reset(level: Node) -> void:
	var combat: Node = level.get_node("Combat")
	level.get_node("SpawnDirector").enabled = false
	for enemy in combat.living_zombies.duplicate():
		combat.living_zombies.erase(enemy)
		enemy.set_physics_process(false)
		enemy.get_parent().remove_child(enemy)
		enemy.queue_free()
	prepare(level)
	for enemy in level.get_node("Actors").get_children():
		if enemy.is_in_group("zombies") and not enemy.is_queued_for_deletion(): combat.register_zombie(enemy)
