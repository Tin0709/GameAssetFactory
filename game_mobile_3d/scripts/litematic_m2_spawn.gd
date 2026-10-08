extends "res://scripts/spawn_director.gd"
## Same production acquisition/combat; exact scene elevation, manual-only lifecycle.
func _ready() -> void:
	super._ready()
	set_physics_process(false)

func find_spawn_position(_near_point: Vector3 = Vector3(NAN,NAN,NAN)) -> Vector3:
	var map = get_parent()
	for i in range(candidate_attempts):
		var angle := rng.randf()*TAU
		var point: Vector3 = combat.player.global_position+Vector3(cos(angle),0,sin(angle))*rng.randf_range(5,9)
		point.x = clampf(point.x,0.5,49.5)
		point.z = clampf(point.z,0.5,49.5)
		var height: float = map.surface_height(point.x,point.z)
		if not is_finite(height): continue
		point.y = height+0.02
		var clear: bool = point.distance_to(combat.player.global_position) >= player_clearance
		for enemy in combat.living_zombies:
			if point.distance_to(enemy.global_position) < enemy_clearance: clear = false
		if clear: return point
	return Vector3(NAN,NAN,NAN)

