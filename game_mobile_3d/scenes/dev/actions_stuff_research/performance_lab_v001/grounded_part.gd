extends "res://scenes/dev/zombie_death_physics/physical_part.gd"
## Native contacts own landing; never freeze transforms or damp an airborne throw.
var corpse:Node
var core_part:=false
func _integrate_forces(state:PhysicsDirectBodyState3D)->void:
	super._integrate_forces(state)
	if not is_instance_valid(corpse):return
	if core_part and not corpse.ground_arrested:
		for i in state.get_contact_count():
			# Godot Physics supplies world contact positions/normals. This dev floor
			# is Y=0; reject arena walls and initially planted feet/hand contacts.
			if state.get_contact_local_normal(i).y>.5 and state.get_contact_local_position(i).y<.06:
				corpse.ground_arrested=true
				corpse.ground_contact_age=corpse.corpse_age
				break
	if corpse.ground_arrested:
		# Coherent planar arrest stops joints dragging the other parts like ice.
		# Vertical fall, angular motion, constraints and CCD remain native physics.
		var velocity:=state.linear_velocity
		var retain:=exp(-80.*state.step)
		velocity.x*=retain;velocity.z*=retain
		state.linear_velocity=velocity
