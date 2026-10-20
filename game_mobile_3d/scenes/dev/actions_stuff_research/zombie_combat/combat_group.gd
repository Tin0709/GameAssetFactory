extends Node3D
## Fixed-size dev encounter. R resets it; no waves, per-frame spawning or
## production CombatDirector/player-death replacement.
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
const PHYSICS_ZOMBIE = preload("res://scenes/dev/actions_stuff_research/zombie_combat/physics_zombie.gd")
const SOURCE_VISUAL = preload("res://scenes/dev/actions_stuff_research/zombie_combat/source_visual.gd")
const SPAWNS := [Vector3(.1,0,-3.4),Vector3(1.5,0,-3.8),Vector3(3.1,0,1.6),Vector3(-3.2,0,1.5)]
const MAX_RAGDOLLS := 4
var zombies: Array[CharacterBody3D] = []
var player: CharacterBody3D
var audio: Node
var kills := 0
var last_corpse_lifetime := 0.0
var active := true
var effects: Node3D
static var _spaces: Dictionary = {}
var _space: RID

func setup(target: CharacterBody3D,existing_audio: Node) -> void:
	player = target
	audio = existing_audio
	# Same native Lab solver at gameplay's60Hz clock. The heavier18m/s² falls
	# need96 local iterations to retain the existing ground/joint error bounds;
	# the fixed encounter still admits at most28 physical parts. No timing change.
	# Reference count also supports regression fixtures sharing one World3D.
	_space=get_world_3d().space
	if not _spaces.has(_space):
		_spaces[_space]={"users":0,"original":PhysicsServer3D.space_get_param(_space,PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS)}
	_spaces[_space].users += 1
	PhysicsServer3D.space_set_param(_space,PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS,96)
	reset_encounter()

func can_fight() -> bool:return active
func play_sound(event: StringName) -> void:
	if is_instance_valid(audio):audio.play_event(event)

func reset_encounter() -> void:
	# All old native graphs are freed synchronously before a new group is admitted.
	for zombie in zombies:
		if is_instance_valid(zombie):zombie.free()
	zombies.clear()
	kills = 0
	for i in SPAWNS.size():
		var zombie: CharacterBody3D = ZOMBIE.instantiate()
		zombie.set_script(PHYSICS_ZOMBIE)
		zombie.get_node("Visual").set_script(SOURCE_VISUAL)
		zombie.name = "ResearchZombie_%d" % (i+1)
		zombie.position = SPAWNS[i]
		zombie.target = player
		zombie.combat_audio = audio
		zombie.combat = self
		# The source strike reaches about0.9m forward; the remaining distance is
		# the player's visible torso/hand thickness. Starting at1.7m stopped the
		# chase before either fist could touch. Keep the capsules/model unchanged.
		zombie.stop_distance = .85
		zombie.attack_range = .90
		# Show the requested Attack clip using existing AI timing without introducing
		# player-death/health gameplay into this approved locomotion research scene.
		zombie.attack_damage = 0
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

func _exit_tree() -> void:
	if not _spaces.has(_space):return
	_spaces[_space].users -= 1
	if _spaces[_space].users == 0:
		PhysicsServer3D.space_set_param(_space,PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS,_spaces[_space].original)
		_spaces.erase(_space)
