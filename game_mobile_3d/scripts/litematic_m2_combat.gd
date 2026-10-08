extends "res://scripts/combat_director.gd"
func spawn_exp(position: Vector3) -> void:
	super.spawn_exp(position)
	var pickup := pickups.get_child(pickups.get_child_count()-1) as Node3D
	pickup.global_position.y = get_parent().surface_height(position.x,position.z)+0.24
