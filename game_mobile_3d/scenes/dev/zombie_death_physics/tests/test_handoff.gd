extends SceneTree
const LAB = preload("res://scenes/dev/ZombieDeathPhysicsLab.tscn")
var failures: Array[String] = []
var results: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func tick(count: int) -> void:
	for i in roundi(count * Engine.physics_ticks_per_second / 60.0):
		await physics_frame
	await process_frame
func run() -> void:
	var lab = LAB.instantiate()
	root.add_child(lab)
	await tick(2)
	check(lab.actor.ragdoll.bodies.size() == 7, "Seven physical bodies")
	for state in ["Idle", "Walk", "Attack"]:
		for weapon in 3:
			lab.animation_choice.select(["Idle", "Walk", "Attack"].find(state))
			lab.weapon_choice.select(weapon)
			lab._load_profile(weapon)
			lab.reset_zombie()
			var zombie = lab.actor
			zombie.position = Vector3(1.7, 0, -1.2)
			zombie.rotation.y = 0.43
			await tick(9 if state == "Attack" else 23)
			lab.trigger_death()
			await tick(1)
			check(zombie.dead, state + " handoff completed")
			check(zombie.ragdoll.handoff_error < 0.0001, state + " full-world body handoff")
			check(zombie.model.position.is_equal_approx(zombie.model_offset_at_handoff), state + " model offset preserved")
			check(zombie.ragdoll.anchors.size() == 6, "Six native joint frames")
			if state == "Walk":
				check(zombie.ragdoll.inherited.Hips.linear.length() > 0.4, "Walk momentum retained")
			if state == "Attack":
				check(absf(zombie.model.position.z) > 0.02, "Attack lunge was not RESET")
			var root_at_death: Transform3D = zombie.global_transform
			var probe := Node.new()
			probe.set_script(preload("res://scenes/dev/zombie_death_physics/tests/step_probe.gd"))
			probe.target = zombie
			lab.add_child(probe)
			await tick(210)
			var peak_error: float = probe.peak_anchor
			var low_y: float = probe.minimum_y
			check(probe.samples >= 400, "Every fixed physics state sampled")
			check(probe.finite and probe.scale_error < 0.0001, "Finite rigid block transforms")
			probe.queue_free()
			check(peak_error < 0.05, "%s/%d constraint error %.4fm" % [state, weapon, peak_error])
			check(low_y > -0.05, "%s/%d ground penetration %.4fm" % [state, weapon, low_y])
			check(zombie.global_transform.is_equal_approx(root_at_death), "Living root stopped moving")
			check(zombie.ragdoll.minimum_corner_y() > -0.025, "Settled floor support")
			check(zombie.ragdoll.max_anchor_error() < 0.02, "Settled attached joints")
			check(zombie.visible_physics_samples > 10, "Evaluated modifier samples captured")
			check(zombie.maximum_skin_position_error < 0.0002, "Visible skin follows physics position")
			check(zombie.maximum_skin_angle_error < 0.002, "Visible skin follows physics orientation")
			var chest = zombie.ragdoll.bodies.Chest
			check(chest.global_position.y < 0.65, "%s/%d collapsed instead of standing: %.3f" % [state, weapon, chest.global_position.y])
			results.append({"state": state, "weapon": weapon, "handoff_m": zombie.ragdoll.handoff_error, "peak_anchor_m": peak_error, "minimum_corner_y": low_y, "chest": [chest.global_position.x, chest.global_position.y, chest.global_position.z]})
	# Aggregate falloff conserves total event impulse and falls off only for the shotgun.
	check(is_equal_approx(lab.shotgun_profile.strength_at(1.5), 1.0), "Shotgun near strength")
	check(is_equal_approx(lab.shotgun_profile.strength_at(8), 0.2), "Shotgun far strength")
	for i in 12:
		lab.reset_zombie()
		await tick(2)
		check(lab.zombies.size() == 1, "Repeated reset has one actor")
	lab.maximum_active_ragdolls = 4
	lab.stress_test()
	await tick(40)
	lab.trigger_death()
	await tick(180)
	check(lab.zombies.size() == 4, "Four actor stress cap")
	for zombie in lab.zombies: check(zombie.dead, "Stress actor died")
	lab.corpse_lifetime = 0.1
	await tick(5)
	check(lab.zombies.is_empty(), "Corpse cleanup removes bodies safely")
	lab.reset_zombie()
	await tick(2)
	check(lab.zombies.size() == 1 and not lab.actor.dead, "Respawn after cleanup")
	var output := {"engine": Engine.get_version_info().string, "results": results, "failures": failures}
	var file := FileAccess.open(OS.get_environment("ZOMBIE_LAB_RESULTS") if not OS.get_environment("ZOMBIE_LAB_RESULTS").is_empty() else "user://zombie_lab_handoff_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  "))
	print("HANDOFF_RESULTS ", JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
