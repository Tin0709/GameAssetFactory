extends Node3D
## Fixed-size dev encounter. R resets it; no waves, per-frame spawning or
## production CombatDirector/player-death replacement.
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
const PHYSICS_ZOMBIE = preload("res://scenes/dev/actions_stuff_research/zombie_combat/physics_zombie.gd")
const SPAWNS := [Vector3(-1.6,0,-3.0),Vector3(1.5,0,-3.8),Vector3(3.1,0,1.6),Vector3(-3.2,0,1.5)]
const MAX_RAGDOLLS := 4
var zombies: Array[CharacterBody3D] = []
var player: CharacterBody3D
var audio: Node
var kills := 0
var last_corpse_lifetime := 0.0

func setup(target: CharacterBody3D,existing_audio: Node) -> void:
	player = target
	audio = existing_audio
	reset_encounter()

func reset_encounter() -> void:
	# All old native graphs are freed synchronously before a new group is admitted.
	for zombie in zombies:
		if is_instance_valid(zombie):zombie.free()
	zombies.clear()
	kills = 0
	for i in SPAWNS.size():
		var zombie: CharacterBody3D = ZOMBIE.instantiate()
		zombie.set_script(PHYSICS_ZOMBIE)
		zombie.name = "ResearchZombie_%d" % (i+1)
		zombie.position = SPAWNS[i]
		zombie.target = player
		zombie.combat_audio = audio
		zombie.stop_distance = 1.45
		zombie.detection_range = 12.0
		zombie.persistent_chase = true
		zombie.corpse_finished.connect(_corpse_finished)
		add_child(zombie)
		zombies.append(zombie)

func _corpse_finished(zombie: CharacterBody3D,lifetime: float) -> void:
	last_corpse_lifetime = lifetime
	kills += 1
	zombies.erase(zombie)

func active_ragdolls() -> int:
	var count := 0
	for zombie in zombies:
		if zombie.is_dead and zombie.ragdoll.running:count += 1
	return count

func living_count() -> int:
	var count := 0
	for zombie in zombies:
		if not zombie.is_dead:count += 1
	return count
