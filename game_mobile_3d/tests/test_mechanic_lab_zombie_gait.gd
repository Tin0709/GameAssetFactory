extends SceneTree

const Lab := preload("res://scenes/dev/MechanicLab.tscn")
const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
const STYLED_WALK := &"Zombie_ExpressiveWalk"
const STYLED_RUN := &"Zombie_ExpressiveRun"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL ", message)

func await_clip(actor: Zombie, clips: Array, timeout := 300) -> bool:
	for tick in timeout:
		await physics_frame
		if actor.animation.current_animation in clips:
			return true
	return false

func select(mode: OptionButton, index: int) -> void:
	mode.select(index)
	mode.item_selected.emit(index)

func run() -> void:
	var lab := Lab.instantiate()
	root.add_child(lab)
	current_scene = lab
	var mode := lab.get_node_or_null("HUD/ZombieGait") as OptionButton
	check(mode != null and mode.item_count == 2 and mode.selected == 0 and not mode.disabled,
		"The Lab offers the current and expressive zombie gaits, with the current gait selected")
	if failures > 0:
		quit(1)
		return
	var group := lab.get_node("Zombies")
	lab.player.set_physics_process(false)
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	lab.get_node("HUD/SpawnBabyZombie").pressed.emit()
	check(group.get_child_count() == 2, "Adult and baby spawn through their normal buttons")
	if failures > 0:
		quit(1)
		return
	var adult := group.get_child(0) as Zombie
	var baby := group.get_child(1) as Zombie
	adult.position = Vector3.ZERO
	baby.position = Vector3(-32.0, 0.0, 0.0)
	lab.player.position = Vector3(26.0, 0.0, 0.0)
	check(await await_clip(adult, Zombie.WALK_CLIPS), "The default adult patrol uses its previous clip")
	var before := adult.position
	select(mode, 1)
	check(await await_clip(adult, [STYLED_WALK], 5), "An adult already on patrol switches to the expressive walk")
	check(adult.position.distance_to(before) < 0.3 and group.get_child(0) == adult and adult.health == adult.max_health,
		"Changing style keeps the same living actor, position and health")
	check(absf(adult.get_real_velocity().slide(Vector3.UP).length() - Zombie.LAB_ROAM_SPEED) < 0.05,
		"The expressive walk keeps the patrol speed")
	check(not baby.animation.has_animation(STYLED_WALK) and await await_clip(baby, Zombie.WALK_CLIPS, 60),
		"The Baby Zombie keeps its own locomotion")
	lab.player.position = adult.position + Vector3(7.0, 0.0, 0.0)
	var steps: Array[Vector3] = []
	adult.step_audio.connect(func(point: Vector3): steps.append(point))
	check(await await_clip(adult, [STYLED_RUN]), "An adult switches to the expressive run in pursuit")
	check(absf(adult.get_real_velocity().slide(Vector3.UP).length() - Zombie.CHASE_SPEED) < 0.05,
		"The expressive run keeps the pursuit speed")
	for tick in 43:
		await physics_frame
	check(steps.size() >= 2 and steps[steps.size() - 1].distance_to(steps[steps.size() - 2]) > 0.2,
		"Expressive pursuit still emits alternating foot contacts")
	select(mode, 0)
	check(await await_clip(adult, Zombie.WALK_CLIPS, 5), "An adult in pursuit switches back to the previous clip")

	check(await await_clip(adult, [Zombie.ATTACK]), "The adult can still enter its original attack clip")
	var attack_position := adult.animation.current_animation_position
	select(mode, 1)
	for tick in 3:
		await physics_frame
	check(adult.animation.current_animation == Zombie.ATTACK
		and adult.animation.current_animation_position > attack_position,
		"Changing the gait during a swing does not interrupt or restart the attack")

	lab.get_node("HUD/SpawnZombie").pressed.emit()
	check(group.get_child_count() == 3, "A second adult spawns with the new style selected")
	if group.get_child_count() == 3:
		var next_adult := group.get_child(2) as Zombie
		next_adult.position = Vector3(32.0, 0.0, 0.0)
		check(await await_clip(next_adult, [STYLED_WALK]), "New adults inherit the selection")
	print("MECHANIC_LAB_ZOMBIE_GAIT failures=", failures, " footsteps=", steps.size())
	quit(0 if failures == 0 else 1)
