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
		and adult._live_capsule.height == Zombie.HEIGHT, "Adult and baby variants coexist with their own capsules")
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
	print("LAB_BABY_ZOMBIE speed=", peak_speed, " damage=", hits, " steps=", steps.size(),
		" joint_gap=", peak_gap, " failures=", failures)
	lab.free()
	quit(0 if failures.is_empty() else 1)

func attack_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)
