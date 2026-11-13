extends SceneTree

const ContactSparks := preload("res://scripts/mechanic_lab_contact_sparks.gd")

class FlashMonitor extends Node:
	var zombie: CharacterBody3D
	var hit := false
	var values: Array[float] = []
	var sparks: MultiMeshInstance3D
	var spark_counts: Array[int] = []

	func _process(_delta: float) -> void:
		if hit:
			var mesh := zombie.get("_mesh") as MeshInstance3D
			values.append(float(mesh.get_instance_shader_parameter("hit_flash")) if mesh.material_overlay != null else 0.0)
			if sparks != null:
				spark_counts.append(sparks.multimesh.visible_instance_count)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL ", description)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func check_hit(fatal: bool) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group := lab.get_node("Zombies")
	await ticks(13)
	lab.get_node("HUD/BaseZombieToggle").button_pressed = fatal
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	check(group.get_child_count() == 1, "A verified zombie spawns")
	if group.get_child_count() != 1:
		lab.free()
		return
	var zombie = group.get_child(0)
	var monitor := FlashMonitor.new()
	monitor.zombie = zombie
	monitor.sparks = lab.get_node_or_null("ContactSparks/Streaks") as MultiMeshInstance3D
	check(monitor.sparks != null, "Lab initializes the private source spark renderer")
	monitor.process_priority = 100
	lab.add_child(monitor)
	group.sabre_contact.connect(func(_point, _direction, _clip, _index, _serial, _lethal): monitor.hit = true)
	await ticks(38)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(36)
	check(not monitor.values.is_empty() and is_equal_approx(monitor.values[0], 1.0),
		"First displayed hit frame uses full body flash (fatal: %s)" % fatal)
	check(not monitor.values.is_empty() and is_zero_approx(monitor.values.back())
		and zombie._mesh.material_overlay == null and not zombie.is_processing(),
		"The temporary overlay clears and stops updating (fatal: %s)" % fatal)
	check(zombie.health == (0 if fatal else 36) and zombie.ragdoll.running == fatal,
		"Flash leaves damage and ragdoll handoff intact (fatal: %s)" % fatal)
	check(not monitor.spark_counts.is_empty() and monitor.spark_counts[0] >= 6
		and monitor.spark_counts.max() <= 12 and monitor.spark_counts.back() == 0,
		"Body contact starts a bounded spark burst that fades (fatal: %s)" % fatal)
	print("BODY_FLASH fatal=", fatal, " samples=", monitor.values.slice(0, 11))
	lab.free()

func run() -> void:
	await check_hit(false)
	await check_hit(true)
	await check_crowd_sparks()
	print("MECHANIC_LAB_HIT_FLASH failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_crowd_sparks() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var sparks := lab.get_node("ContactSparks") as ContactSparks
	var renderer := sparks.get_node("Streaks") as MultiMeshInstance3D
	var group := lab.get_node("Zombies")
	var origin: Vector3 = lab.player.global_position + Vector3.UP
	var nearest: Array[Vector3] = []
	# Feed the normal contact signal in near-first order, then flood it with distant contacts.
	for i in 100:
		var point := origin + Vector3.RIGHT * (0.8 * (i + 1))
		if i < 5:
			nearest.append(point)
		group.sabre_contact.emit(point, Vector3.RIGHT, "Attack3", 2, 1700, false)
	await process_frame
	await process_frame
	var counts := [0, 0, 0, 0, 0]
	for particle in sparks._particles:
		if particle.age >= particle.lifetime:
			continue
		for i in nearest.size():
			if particle.origin.distance_squared_to(nearest[i]) < 0.22 ** 2:
				counts[i] += 1
	check(counts == [9, 9, 9, 9, 9] and renderer.multimesh.visible_instance_count == 45,
		"A 100-contact burst shows five complete groups of streaks at the nearest hits")
	lab.reset_player()
	await process_frame
	await process_frame
	check(renderer.multimesh.visible_instance_count == 0 and not sparks.is_processing(),
		"Reset clears the crowd sparks and stops their frame callback")
	lab.free()
