extends SceneTree
var failures: Array[String] = []
var trials: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func tick(count: int) -> void:
	for i in roundi(count * Engine.physics_ticks_per_second / 60.0):
		await physics_frame
	await process_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var lab = load("res://scenes/dev/ZombieDeathPhysicsLab.tscn").instantiate()
	root.add_child(lab)
	for state in ["Walk", "Attack"]:
		for phase in [3, 13, 36, 65]:
			for weapon in 3:
				lab.animation_choice.select(1 if state == "Walk" else 2)
				lab.weapon_choice.select(weapon)
				lab._load_profile(weapon)
				lab.reset_zombie()
				await tick(phase)
				lab.trigger_death()
				await tick(1)
				var z = lab.actor
				check(z.dead and z.ragdoll.handoff_error < 0.0001, "Phase pose/world handoff")
				if state == "Walk":
					check(absf(z.ragdoll.inherited.Hips.linear.z - z.walk_speed) < 0.08, "World travel not lost or double-counted")
				var probe := Node.new()
				probe.set_script(preload("res://scenes/dev/zombie_death_physics/tests/step_probe.gd"))
				probe.target = z
				lab.add_child(probe)
				await tick(240)
				var peak_anchor: float = probe.peak_anchor
				var minimum_y: float = probe.minimum_y
				check(probe.samples >= 450, "Every fixed physics state sampled")
				probe.queue_free()
				check(peak_anchor < 0.05, "%s/%d/%d joint attachment: %.3f" % [state, phase, weapon, peak_anchor])
				check(minimum_y > -0.05, "%s/%d/%d floor contact: %.3f" % [state, phase, weapon, minimum_y])
				check(z.ragdoll.max_anchor_error() < 0.025, "Settled joint attachment")
				check(z.ragdoll.minimum_corner_y() > -0.025, "Settled ground support")
				check(z.maximum_skin_position_error < 0.0002 and z.visible_physics_samples > 10, "Evaluated skin/physics mapping")
				trials.append({"state": state, "phase_tick": phase, "weapon": weapon, "peak_anchor_m": peak_anchor, "minimum_corner_y": minimum_y})
	# Pausing must leave corpse frozen in time; reset must still work while paused.
	lab.toggle_pause()
	var frozen: Transform3D = lab.actor.ragdoll.bodies.Hips.global_transform
	for i in 5: await process_frame
	check(lab.actor.ragdoll.bodies.Hips.global_transform.is_equal_approx(frozen), "Pause holds physics")
	lab.reset_zombie()
	check(not lab.actor.dead, "Reset while paused")
	lab.toggle_pause()
	lab.controls.speed.value = 0.2
	await tick(10)
	check(lab.actor.elapsed > 0 and lab.actor.elapsed < 0.1, "Slow motion affects animation clock")
	lab.controls.speed.value = 1.0
	# Eight body graphs cannot over-admit, repeat trigger does not stack hits.
	lab.maximum_active_ragdolls = 8
	lab.stress_test()
	await tick(40)
	lab.trigger_death()
	await tick(2)
	lab.trigger_death()
	check(lab.zombies.size() == 8, "Eight-corpse cap")
	await tick(180)
	for z in lab.zombies:
		check(z.dead and z.ragdoll.max_anchor_error() < 0.03, "Stress keeps all six joints attached")
	var output := {"trials": trials, "failures": failures}
	var result_path := OS.get_environment("ZOMBIE_LAB_RESULTS")
	if result_path.is_empty(): result_path = "user://zombie_lab_states_results.json"
	FileAccess.open(result_path, FileAccess.WRITE).store_string(JSON.stringify(output, "  "))
	print("STATE_TESTS ", JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
