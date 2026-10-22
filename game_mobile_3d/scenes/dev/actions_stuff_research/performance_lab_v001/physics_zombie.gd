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

func _start_physics()->void:
	super._start_physics()
	if not ragdoll.running:return
	for part:PhysicalBone3D in ragdoll.bodies.values():
		# A living zombie's mask includes layer2 (player), the original corpse
		# layer. Stop advertising the corpse on that layer as well as ignoring
		# live actors in our own mask. Native ground collision remains via mask1.
		part.collision_layer=0
		part.collision_mask=1

# Fully blocked chasers retry native motion at30Hz, distributed across ticks.
# Free movement, source animation, damage and native ragdolls retain60Hz.
var ai_steps:=0
var _ai_blocked:=false
var _pending_ai_delta:=0.
func _advance_living_ai(delta:float)->void:
	_pending_ai_delta+=delta
	var stride:=clampi(roundi(float(Engine.physics_ticks_per_second)/30.),1,4)
	var retry_later:=_ai_blocked and is_on_floor() and knockback.length_squared()<.0001 and chasing and not holding_distance and pending_attack<0.
	if retry_later and Engine.get_physics_frames()%stride!=get_instance_id()%stride:return
	var elapsed:=_pending_ai_delta;_pending_ai_delta=0.
	ai_steps+=1
	super._advance_living_ai(elapsed)
	# move_and_slide may zero velocity at a wall. Use the retained chase intent,
	# not its post-collision velocity, to recognize a blocked approach.
	_ai_blocked=(is_on_floor() and chasing and not holding_distance
		and pending_attack<0. and attack_visual_remaining<=0.
		and knockback.length_squared()<.0001
		and Vector2(get_real_velocity().x,get_real_velocity().z).length_squared()<.01)

func take_damage(amount:int,direction:Vector3=Vector3.ZERO)->bool:
	# A new impact must never wait for the crowd retry phase.
	_ai_blocked=false
	return super.take_damage(amount,direction)
