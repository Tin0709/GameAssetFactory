extends SceneTree

const Lab := preload("res://scenes/dev/MechanicLab.tscn")
const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
const STYLED_IDLE := &"Zombie_AS_Idle"
const STYLED_WALK := &"Zombie_AS_Move"
const STYLED_ATTACK := &"Zombie_AS_Attack"
const STYLED_SPAWN := &"Zombie_AS_Spawn"
const STYLED_STAGGER := &"Zombie_AS_Stagger"

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
	var menu := mode.get_popup()
	var key := KEY_F7 + index
	menu.set_item_accelerator(index, key)
	var input := InputEventKey.new()
	input.keycode = key
	input.pressed = true
	check(menu.activate_item_by_event(input) and mode.selected == index,
		"The zombie style can be activated through the menu")

func idle_audio_ticks(mode: OptionButton, actors: Array[Zombie], style: int,
		switch_mid_idle := false) -> Array[Array]:
	var ticks: Array[Array] = [[], []]
	select(mode, style)
	for actor in actors:
		actor.set_physics_process(false)
		actor._play_gait()
		actor._advance_animation(1.0 / 60.0, Vector3.ZERO)
		actor._play_loop(Zombie.IDLE)
	for tick in 450:
		if switch_mid_idle and tick in [23, 260]:
			select(mode, 1 - mode.selected)
			for actor in actors:
				actor._play_loop(Zombie.IDLE)
		for i in actors.size():
			var actor := actors[i]
			var before := actor._idle_audio_index
			actor._advance_animation(1.0 / 60.0, Vector3.ZERO)
			if actor._idle_audio_index != before:
				ticks[i].append(tick + 1)
	return ticks

func check_stationary_run(actor: Zombie) -> void:
	var samples := [0]
	var count_sample := func(): samples[0] += 1
	actor._skipped_blocked_step = true
	actor._play_gait()
	actor.animation.seek(0.16)
	actor.animation.mixer_applied.connect(count_sample)
	actor._advance_animation(1.0 / 60.0, Vector3.ZERO)
	var after_first := samples[0]
	for tick in 4:
		actor._advance_animation(1.0 / 60.0, Vector3.ZERO)
	check(actor.animation.current_animation == STYLED_WALK and after_first > 0 and samples[0] == after_first,
		"A blocked A&S stride publishes its pose once and reuses it while the phase holds")
	actor.animation.seek(0.24)
	actor._advance_animation(1.0 / 60.0, Vector3.ZERO)
	check(samples[0] == after_first + 1, "Seeking the held clip publishes the newly requested pose")
	actor.animation.stop(true)
	actor._play_gait()
	actor.animation.seek(0.24)
	var after_restart := samples[0]
	actor._advance_animation(1.0 / 60.0, Vector3.ZERO)
	check(samples[0] > after_restart, "Replaying the held clip refreshes its pose even at the same phase")
	actor.animation.mixer_applied.disconnect(count_sample)

func run() -> void:
	var lab := Lab.instantiate()
	root.add_child(lab)
	current_scene = lab
	var mode := lab.get_node_or_null("HUD/ZombieGait") as OptionButton
	check(mode != null and mode.item_count == 2 and mode.selected == 0 and not mode.disabled
		and not mode.is_item_disabled(1),
		"The Lab offers MD2 and Actions & Stuff for both zombie types")
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
	check(await await_clip(adult, [STYLED_WALK], 5), "An adult already on patrol switches to the source move clip")
	check(adult.position.distance_to(before) < 0.3 and group.get_child(0) == adult and adult.health == adult.max_health,
		"Changing style keeps the same living actor, position and health")
	check(absf(adult.get_real_velocity().slide(Vector3.UP).length() - Zombie.LAB_ROAM_SPEED) < 0.05,
		"The expressive walk keeps the patrol speed")
	check(await await_clip(baby, [STYLED_WALK], 90), "The Baby Zombie also switches to the source move clip")
	check(baby.animation.get_animation(STYLED_WALK) != adult.animation.get_animation(STYLED_WALK),
		"Both rigs use their own retargeted poses")
	if "--require-baby-source" in OS.get_cmdline_user_args():
		check(is_equal_approx(baby.animation.get_animation(STYLED_WALK).length, Zombie.ActionsStuff.BABY_STRIDE_SECONDS),
			"The source Baby Zombie uses its own 0.4375-second stride")
	lab.player.position = adult.position + Vector3(7.0, 0.0, 0.0)
	var steps: Array[Vector3] = []
	adult.step_audio.connect(func(point: Vector3):
		if adult.animation.current_animation == STYLED_WALK:
			steps.append(adult.to_local(point)))
	for tick in 40:
		await physics_frame
	check(adult.animation.current_animation == STYLED_WALK, "An adult uses the source stride in pursuit")
	check(absf(adult.get_real_velocity().slide(Vector3.UP).length() - Zombie.CHASE_SPEED) < 0.05,
		"The expressive run keeps the pursuit speed")
	for tick in 43:
		await physics_frame
	check(steps.size() >= 2, "Expressive pursuit emits foot contacts")
	for i in range(1, steps.size()):
		check(steps[i - 1].x * steps[i].x < 0.0, "Run contacts alternate between left and right feet")
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
		next_adult.take_hit(next_adult.health, Vector3.BACK)
		for tick in 3:
			await physics_frame
		check(next_adult.health == 0 and next_adult.ragdoll.running,
			"The A&S walking pose hands off to the same MD2 death rig")
		select(mode, 0)
		for tick in 3:
			await physics_frame
		check(next_adult.health == 0 and next_adult.ragdoll.running,
			"Changing the review style leaves an existing ragdoll in simulation")
	select(mode, 1)
	lab.get_node("HUD/SpawnBabyZombie").pressed.emit()
	check(group.get_child_count() == 4, "A new Baby Zombie spawns with A&S selected")
	if group.get_child_count() == 4:
		var next_baby := group.get_child(3) as Zombie
		check(next_baby.animation.current_animation == STYLED_SPAWN, "Baby spawn uses the A&S idle pose")
		var hits := [0]
		next_baby.melee_hit.connect(func(_damage: int): hits[0] += 1)
		next_baby.position = Vector3(34.0, 0.0, 0.0)
		lab.player.position = Vector3(34.0, 0.0, 5.5)
		check(await await_clip(next_baby, [STYLED_ATTACK]), "The Baby Zombie can attack with the A&S clip")
		for tick in 100:
			await physics_frame
			if next_baby.animation.current_animation != STYLED_ATTACK:
				break
		check(hits[0] == 1, "One A&S Baby Zombie swing applies damage exactly once")
		# End the encounter so the next swing cannot preempt the idle pose.
		lab.player.position = Vector3(5.0, 0.0, 5.5)
		check(await await_clip(next_baby, [STYLED_IDLE]), "The attack returns to the A&S idle")
		next_baby.take_hit(1, Vector3.BACK, Zombie.DEFAULT_DEATH_IMPULSE, Zombie.BABY_MAX_POISE)
		check(next_baby.animation.current_animation == STYLED_STAGGER, "The A&S mode does not play a native living stagger montage")
		next_baby.take_hit(next_baby.health, Vector3.BACK)
		for tick in 3:
			await physics_frame
		check(next_baby.ragdoll.running, "The Baby Zombie still uses its MD2 death ragdoll")
	var actors: Array[Zombie] = [adult, baby]
	var md2_cues := idle_audio_ticks(mode, actors, 0)
	var styled_cues := idle_audio_ticks(mode, actors, 1)
	var switched_cues := idle_audio_ticks(mode, actors, 1, true)
	check(md2_cues == [[5, 205, 405], [5, 49, 93, 137, 181, 225, 269, 313, 357, 401, 445]],
		"The authored-length MD2 idle clips provide the existing audio cadence for both ages")
	check(styled_cues == md2_cues and switched_cues == md2_cues,
		"A&S idle and live style changes retain the MD2 audio cadence for both ages")
	print("MECHANIC_LAB_IDLE_CLOCK md2=", md2_cues, " as=", styled_cues, " switched=", switched_cues)
	check_stationary_run(adult)
	check_stationary_run(baby)
	print("MECHANIC_LAB_ZOMBIE_GAIT failures=", failures, " footsteps=", steps.size())
	quit(0 if failures == 0 else 1)
