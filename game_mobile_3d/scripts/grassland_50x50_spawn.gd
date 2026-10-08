extends "res://scripts/spawn_director.gd"
## The production acquisition/registry pipeline, with scene-local bounded candidates.
func _ready() -> void:
	enabled = false
	initial_active_target = 0
	super._ready()
	set_physics_process(false)

func find_spawn_position(_near_point: Vector3 = Vector3(NAN,NAN,NAN)) -> Vector3:
	for i in range(candidate_attempts):
		var angle := rng.randf_range(0,TAU)
		var p: Vector3 = combat.player.global_position + Vector3(cos(angle),0,sin(angle)) * rng.randf_range(5,9)
		p.y = 1.02
		if absf(p.x) > 23 or absf(p.z) > 23: continue
		if not get_parent().layout.rock_clear(Vector2(p.x,p.z),1.2): continue
		var clear := true
		for enemy in combat.living_zombies:
			if p.distance_squared_to(enemy.global_position) < enemy_clearance * enemy_clearance:
				clear = false
				break
		if clear: return p
	return Vector3(NAN,NAN,NAN)

func _physics_process(_delta: float) -> void:
	# Manual-only even if another scene-local consumer enables processing accidentally.
	pass
