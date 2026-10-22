extends "res://scenes/dev/actions_stuff_research/zombie_combat/physics_zombie.gd"
## Admission policy only. The existing handoff, impulse and cleanup stay intact.
func _begin_death(direction:Vector3)->void:
	if is_dead:return
	combat.reserve_ragdoll(self)
	super._begin_death(direction)
