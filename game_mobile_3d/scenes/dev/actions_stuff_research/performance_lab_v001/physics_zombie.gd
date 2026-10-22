extends "res://scenes/dev/actions_stuff_research/zombie_combat/physics_zombie.gd"
## Current dev combat tuning; original Lab physics and legacy encounter stay exact.
const GroundedPart=preload("res://scenes/dev/actions_stuff_research/performance_lab_v001/grounded_part.gd")
var ground_arrested:=false
var ground_contact_age:=-1.
func _ready()->void:
	super._ready()
	corpse_lifetime=2.5
	# Double momentum once: same masses => twice the initial launch velocity.
	combat_rifle.linear_impulse=COMBAT_IMPULSE*2.
	combat_rifle.upward_impulse=COMBAT_LIFT*2.
	for name in ragdoll.bodies:
		var part:PhysicalBone3D=ragdoll.bodies[name]
		part.set_script(GroundedPart)
		part.corpse=self
		part.core_part=name in ["Hips","Chest","Head"]
		part.friction=1.
