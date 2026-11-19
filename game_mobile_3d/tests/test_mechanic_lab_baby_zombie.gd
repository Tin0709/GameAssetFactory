extends SceneTree

const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var group: Node = lab.get_node("Zombies")
	var button := lab.get_node_or_null("HUD/SpawnBabyZombie") as Button
	check(button != null and not button.disabled, "The Lab offers a separate Baby Zombie button")
	if button == null or button.disabled:
		lab.free()
		quit(1)
		return
	button.pressed.emit()
	check(group.get_child_count() == 1, "Each Baby Zombie button press spawns one mob")
	if group.get_child_count() != 1:
		lab.free()
		quit(1)
		return
	var baby := group.get_child(0) as Zombie
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var adult := group.get_child(1) as Zombie if group.get_child_count() == 2 else null
	check(adult != null and not adult.is_baby and adult.max_health == Zombie.TRAINING_HEALTH
		and is_equal_approx(adult._live_capsule.height, Zombie.HEIGHT), "Adult and baby variants coexist with their own capsules")
	if adult != null:
		adult.set_physics_process(false)
		adult.position = Vector3(14.0, 0.02, 0.0)
	check(baby.is_baby and baby.health == 8 and baby._mesh.name == &"SK_BabyZombie"
		and is_equal_approx(baby._live_capsule.height, 1.125), "The Baby Zombie uses its source mesh and 8 HP")
	check(baby.animation.has_animation(Zombie.SPAWN) and baby.animation.has_animation(Zombie.STAGGER)
		and is_equal_approx(baby.animation.get_animation(Zombie.ATTACK).length, 32.0 / 30.0),
		"The baby has its own spawn, stagger and attack clips")
	baby.position = Vector3(0.0, 0.02, 6.0)
	var hits: Array[int] = []
	var steps: Array[Vector3] = []
	baby.melee_hit.connect(func(amount: int): hits.append(amount))
	baby.step_audio.connect(func(point: Vector3): steps.append(point))
	var peak_speed := 0.0
	for i in 180:
		await physics_frame
		peak_speed = maxf(peak_speed, baby.get_real_velocity().slide(Vector3.UP).length())
		if not hits.is_empty():
			break
	check(peak_speed > 8.45 and peak_speed < 8.55 and not steps.is_empty()
		and hits == [5] and lab.player_health == 95, "The baby chases at 8.5 m/s and applies its own five-HP hit")
	var skeleton := baby.ragdoll.skeleton
	var hip := skeleton.get_bone_global_pose(skeleton.find_bone(&"J_Hip"))
	check(hip.basis.get_scale().is_equal_approx(Vector3.ONE), "The Baby Zombie restores full size after its spawn clip")
	var aimed: Variant = group.bow_aim_point(8.0, Vector3.ZERO)
	check(aimed is Vector3 and aimed.is_equal_approx(baby.combat_center()),
		"Ranged aim uses the centre of the smaller living capsule")
	lab.player.set_physics_process(true)
	for i in 5:
		await physics_frame
	attack_key(true)
	for i in 75:
		if baby.health == 0:
			break
		await physics_frame
	attack_key(false)
	check(baby.health == 0, "A real player attack can hit and kill the Baby Zombie")
	var landed := false
	var peak_gap := 0.0
	for i in 220:
		await physics_frame
		if baby._corpse_parked:
			break
		if baby.ragdoll.running:
			landed = landed or baby._corpse_landed
			peak_gap = maxf(peak_gap, baby.ragdoll.max_anchor_error())
	check(landed and baby._corpse_parked and baby.ragdoll.bodies.is_empty() and peak_gap < 0.18,
		"The baby lands with the full rig connected and releases the simulation at rest")
	lab.free()
	await check_prewarmed_spawn()
	await check_tuned_floor_contact()
	print("LAB_BABY_ZOMBIE speed=", peak_speed, " damage=", hits, " steps=", steps.size(),
		" joint_gap=", peak_gap, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_prewarmed_spawn() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group: Node = lab.get_node("Zombies")
	check(group.get("_baby_visual") == null, "Opening the Lab does not import the baby rig synchronously")
	for frame in 9:
		await process_frame
	check(group.get_child_count() == 0 and group.get("_baby_visual") is PackedScene,
		"The idle Lab prepares the Baby Zombie without spawning one")
	var button := lab.get_node("HUD/SpawnBabyZombie") as Button
	button.pressed.emit()
	button.pressed.emit()
	check(group.get_child_count() == 2, "Two presses after preparation spawn exactly two Baby Zombies")
	for zombie: Zombie in group.get_children():
		var material := zombie._mesh.material_override as ShaderMaterial
		var skin: Variant = material.get_shader_parameter("living_skin") if material != null else null
		check(zombie.is_baby and skin is Texture2D, "The prepared Baby Zombie keeps its verified skin")
	if group.get_child_count() == 2:
		check_walk_contacts(group.get_child(0) as Zombie)
	lab.free()

func check_walk_contacts(baby: Zombie) -> void:
	var clip: StringName = Zombie.WALK_CLIPS[0]
	var phases: Array[float] = []
	var points: Array[Vector3] = []
	baby.step_audio.connect(func(point: Vector3):
		phases.append(baby.animation.current_animation_position)
		points.append(baby.to_local(point))
	)
	baby.animation.play(clip, 0.0)
	baby.animation.advance(0.0)
	var step := 1.0 / 120.0
	for tick in 96:
		var previous := baby.animation.current_animation_position
		baby.animation.advance(step)
		baby._emit_walk_step(clip, previous)
	check(points.size() == 4, "The Baby Zombie emits one step per foot in each walk cycle")
	if points.size() != 4:
		return
	var authored_contacts := [Vector3(-0.117, 0.0, 0.116), Vector3(0.102, 0.0, 0.083)]
	for contact in points.size():
		var expected_phase := (2.0 if contact % 2 == 0 else 8.0) / 30.0
		check(absf(phases[contact] - expected_phase) <= step + 0.00001
			and points[contact].distance_to(authored_contacts[contact % 2]) < 0.005,
			"The Baby Zombie step matches the source sole and phase at frame 2 or 8")

func check_tuned_floor_contact() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.get_node("HUD/RagdollTuning/Launch/Slider").value = 1000.0
	lab.get_node("HUD/RagdollTuning/Gravity/Slider").value = 1000.0
	var group: Node = lab.get_node("Zombies")
	group._spawn_serial = 26
	lab.get_node("HUD/SpawnBabyZombie").pressed.emit()
	var baby := group.get_child(0) as Zombie
	baby.set_physics_process(false)
	baby.position = Vector3(3.0, 0.02, 2.0)
	baby.rotation.y = 26 * 0.47
	baby.animation.play(Zombie.ATTACK)
	baby.animation.advance(0.0)
	baby.animation.seek(baby.animation.get_animation(Zombie.ATTACK).length * 0.6, true)
	await physics_frame
	for sample in 2:
		baby.ragdoll.sample(1.0 / 60.0)
	var direction := Vector3(0.91, 0.0, -0.22).normalized()
	group._apply_contact(baby, baby.combat_center(), "Attack", 0, 1,
		group.SABRE_STRIKES[0], direction, false, baby.global_position)
	baby.set_physics_process(true)
	var gap := 0.0
	var impulse := 0.0
	var gravity := 0.0
	for tick in 120:
		await physics_frame
		if baby._corpse_parked:
			break
		if not baby.ragdoll.running:
			continue
		gap = maxf(gap, baby.ragdoll.max_anchor_error())
		if impulse == 0.0:
			impulse = baby.ragdoll.total_applied_impulse.length()
			var chest: PhysicalBone3D = baby.ragdoll.bodies.Chest
			gravity = PhysicsServer3D.body_get_direct_state(chest.get_rid()).total_gravity.y
	check(baby.health == 0 and is_equal_approx(impulse, 987.36) and is_equal_approx(gravity, -500.0),
		"The Baby Zombie receives both 1000% settings from the Sabre contact")
	check(gap < 0.20 and baby._corpse_landed and baby._corpse_parked,
		"At 1000% launch and gravity the braced Baby Zombie lands with its legs connected")
	print("LAB_BABY_TUNED_CONTACT gap=", gap, " impulse=", impulse, " gravity=", gravity)
	lab.free()

func attack_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)
