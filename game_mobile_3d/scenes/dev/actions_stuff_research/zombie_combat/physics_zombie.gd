extends "res://scripts/cuboid_zombie.gd"
## Reuse living zombie AI/model/feedback; replace ONLY its old scripted death
## with the existing Lab native skeletal adapter and unchanged Rifle preset.
const Ragdoll = preload("res://scenes/dev/zombie_death_physics/ragdoll.gd")
const RIFLE = preload("res://scenes/dev/zombie_death_physics/presets/rifle.tres")
signal corpse_finished(zombie: CharacterBody3D, lifetime: float)
var ragdoll: Node
var corpse_age := 0.0
var corpse_lifetime := 1.2
var death_triggers := 0
var pending_direction := Vector3.ZERO
var combat_audio: Node

func _ready() -> void:
	super._ready()
	# One physics clock owns living pose sampling and death handoff. The existing
	# manual AnimationPlayer/secondary motion is evaluated unchanged below.
	visual.set_process(false)
	ragdoll = Ragdoll.new()
	add_child(ragdoll)
	ragdoll.setup(visual.skeleton)
	# Lab actors have no living capsule. Here the dormant physical bones must not
	# collide with their own CharacterBody (or with the player) before handoff.
	for body in ragdoll.bodies.values():
		body.collision_layer = 0
		body.collision_mask = 0
	ragdoll.sample(1.0 / Engine.physics_ticks_per_second)

func take_damage(amount: int,direction: Vector3=Vector3.ZERO) -> bool:
	var accepted := super.take_damage(amount,direction)
	if accepted and is_dead and is_instance_valid(combat_audio):
		combat_audio.play_event(&"zombie_death")
	return accepted

func _physics_process(delta: float) -> void:
	if not is_dead:
		super._physics_process(delta)
		visual._process(delta)
		ragdoll.sample(delta)
		return
	if not ragdoll.running:
		# Immediate debug damage may precede two warmed pose samples.
		ragdoll.sample(delta)
		_start_physics()
		return
	corpse_age += delta
	if corpse_age + .000001 >= corpse_lifetime:
		# Free the graph, not just hide/sleep it. No living transform writer resumes.
		ragdoll.release()
		corpse_finished.emit(self, corpse_age)
		queue_free()

func _begin_death(direction: Vector3) -> void:
	if is_dead: return
	is_dead = true
	death_triggers += 1
	chasing = false
	pending_attack = -1.0
	attack_visual_remaining = 0.0
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	set_deferred("collision_layer",0)
	set_deferred("collision_mask",0)
	# Pause without RESET/model-offset rewinding, exactly as the Lab handoff.
	visual.animation_player.pause()
	visual.secondary_frozen = true
	if visual.lunge_tween and visual.lunge_tween.is_valid():visual.lunge_tween.kill()
	if visual.recoil_tween and visual.recoil_tween.is_valid():visual.recoil_tween.kill()
	for mesh in visual.meshes:mesh.material_overlay = null
	damage_feedback.hide()
	pending_direction = direction.normalized()
	_start_physics()

func _start_physics() -> void:
	if ragdoll.running or ragdoll.sample_count < 2:return
	for body in ragdoll.bodies.values():
		body.collision_layer = 2
		body.collision_mask = 1
	# Same 360N·s directional +180N·s upward impulse, weighted once across60kg;
	# seven rigid parts, six limited joints, inherited velocity, ground-only CCD.
	ragdoll.begin(RIFLE,pending_direction,"Chest",0.0,9.8)

func _exit_tree() -> void:
	if is_instance_valid(ragdoll):ragdoll.release()
