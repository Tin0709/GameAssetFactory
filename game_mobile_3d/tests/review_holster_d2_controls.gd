extends Node
## Review controls live outside all production gameplay scripts.
var level: Node3D
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_H:
		for enemy in level.combat.living_zombies.duplicate():
			if is_instance_valid(enemy) and not enemy.is_dead: enemy.take_damage(enemy.current_hp)
		var behavior: Node=level.player.get_node("WeaponBehavior")
		behavior.grace_elapsed=behavior.holster_grace_seconds
