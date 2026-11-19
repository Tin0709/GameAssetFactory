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
	await check_tuned_contact(26)
	await check_tuned_contact(13, 0.0, 0.90)
	await check_tuned_contact(25, 27.0, 1.00)
	await check_tuned_contact(50, 27.0, 1.00)
	await check_tuned_contact(58, 27.0, 0.35, true)
	await check_tuned_contact(73, 27.0, 0.18, false, -58.0)
	await check_tuned_contact(81, 27.0, 0.35, true, -58.0)
	await check_tuned_contact(19, 27.0, 0.35, false, -58.0, true)
	await check_tuned_contact(60, 27.0, 0.20, false, -58.0, false, 100.0)
	await check_tuned_contact(58, 13.0, 0.18, true, -44.0, false, 100.0)
	await check_tuned_contact(78, 27.0, 0.75, false, -58.0, true, 1000.0, 100.0)
	await check_first_wall_neck_contact()
	await check_first_wall_neck_contact(true)
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

func check_tuned_contact(seed: int, wall_yaw := INF, gap_limit := 0.20, air_attack := false,
		strike_yaw := INF, sword_attack := false, launch_percent := 1000.0, gravity_percent := INF) -> void:
	if gravity_percent == INF:
		gravity_percent = launch_percent
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.get_node("HUD/RagdollTuning/Launch/Slider").value = launch_percent
	lab.get_node("HUD/RagdollTuning/Gravity/Slider").value = gravity_percent
	var corner: Node3D
	if wall_yaw != INF:
		corner = add_contact_corner(lab, wall_yaw)
	var group: Node = lab.get_node("Zombies")
	group._spawn_serial = seed
	lab.get_node("HUD/SpawnBabyZombie").pressed.emit()
	var baby := group.get_child(0) as Zombie
	baby.set_physics_process(false)
	baby.position = Vector3(3.0, 0.02, 2.0)
	baby.rotation.y = seed * 0.47
	if corner != null:
		baby.position = corner.to_global(baby.position)
		baby.rotation.y += corner.rotation.y
	var clips := [Zombie.IDLE, Zombie.WALK_CLIPS[0], Zombie.ATTACK]
	var clip: StringName = clips[seed % clips.size()]
	baby.animation.play(clip)
	baby.animation.advance(0.0)
	baby.animation.seek(baby.animation.get_animation(clip).length * (seed % 10) * 0.1, true)
	await physics_frame
	for sample in 2:
		baby.ragdoll.sample(1.0 / 60.0)
	var direction := Vector3(0.91, 0.0, -0.22).normalized()
	if strike_yaw != INF:
		var angle := deg_to_rad(strike_yaw)
		direction = Vector3(cos(angle), 0.0, sin(angle))
	var origin := baby.global_position if corner == null else baby.global_position - direction
	var attack := "AirAttack" if air_attack else "Attack"
	group.sword_equipped = sword_attack
	var strike: Dictionary = group.AIR_STRIKE if air_attack else group.SABRE_STRIKES[0]
	if sword_attack:
		strike = group.SWORD_STRIKES[0]
	group._apply_contact(baby, baby.combat_center(), attack, 0, seed, strike, direction, false, origin)
	baby.set_physics_process(true)
	var gap := 0.0
	var impulse := 0.0
	var gravity := 0.0
	var crossed := false
	for tick in 120:
		await physics_frame
		if baby._corpse_parked:
			break
		if not baby.ragdoll.running:
			continue
		gap = maxf(gap, baby.ragdoll.max_anchor_error())
		if corner != null:
			for part: PhysicalBone3D in baby.ragdoll.bodies.values():
				var local := corner.to_local(part.global_position)
				crossed = crossed or (local.y > 0.0 and local.y < 7.9 and (local.x > 6.13 or local.z < 0.07))
		if impulse == 0.0:
			impulse = baby.ragdoll.total_applied_impulse.length()
			var chest: PhysicalBone3D = baby.ragdoll.bodies.Chest
			gravity = PhysicsServer3D.body_get_direct_state(chest.get_rid()).total_gravity.y
	var expected_impulse := (125.664 if air_attack else 98.736) * launch_percent / 100.0
	check(baby.health == 0 and is_equal_approx(impulse, expected_impulse)
		and is_equal_approx(gravity, -50.0 * gravity_percent / 100.0),
		"The Baby Zombie receives the selected launch and gravity settings from the lethal contact")
	check(gap < gap_limit and baby._corpse_landed and baby._corpse_parked and not crossed,
		"At %d%% launch and %d%% gravity the Baby Zombie settles with limited joint stretch and no wall crossings"
		% [launch_percent, gravity_percent])
	print("LAB_BABY_TUNED_CONTACT launch=", launch_percent, " gravity_slider=", gravity_percent, " seed=", seed, " yaw=", wall_yaw, " strike_yaw=", strike_yaw, " gap=", gap, " crossed=", crossed,
		" parked=", baby._corpse_parked, " impulse=", impulse, " gravity=", gravity)
	lab.free()

func check_first_wall_neck_contact(frozen := false) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.get_node("HUD/RagdollTuning/Launch/Slider").value = 1000.0
	lab.get_node("HUD/RagdollTuning/Gravity/Slider").value = 1000.0

	var wall: PhysicsBody3D
	if frozen:
		var blocker := RigidBody3D.new()
		blocker.freeze = true
		wall = blocker
	else:
		wall = StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.30, 3.0, 96.0)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(4.5, 1.5, 0.0)
	lab.add_child(wall)

	var group: Node = lab.get_node("Zombies")
	group._spawn_serial = 4
	lab.get_node("HUD/SpawnBabyZombie").pressed.emit()
	var baby := group.get_child(0) as Zombie
	baby.set_physics_process(false)
	await physics_frame
	await physics_frame
	baby.global_position = Vector3(4.09, 0.02, -40.95)
	baby.rotation.y = TAU * 11.0 / 16.0
	baby.animation.stop()
	baby.ragdoll.skeleton.reset_bone_poses()
	baby.animation.play(Zombie.STAGGER, 0.0)
	baby.animation.advance(0.0)
	baby.animation.seek(7.0 / 30.0, true)
	for sample in 2:
		baby.ragdoll.sample(1.0 / 60.0)

	var direction := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(-25.0))
	group._apply_contact(baby, baby.combat_center(), "Attack", 2, 4, group.SABRE_STRIKES[2],
		direction, false, baby.global_position - direction)
	baby.set_physics_process(true)
	var peak := 0.0
	var crossed := false
	for tick in 180:
		await physics_frame
		if baby._corpse_parked:
			break
		if not baby.ragdoll.running:
			continue
		peak = maxf(peak, baby.ragdoll.max_anchor_error())
		for part: PhysicalBone3D in baby.ragdoll.bodies.values():
			crossed = crossed or part.global_position.x > 4.655
	check(peak > 0.0 and peak < 0.20 and baby._corpse_parked and not crossed,
		"At 1000%% launch and gravity the Baby Zombie keeps its neck connected against a %s wall" %
		("frozen" if frozen else "static"))
	print("LAB_BABY_FIRST_WALL frozen=", frozen, " gap=", peak, " crossed=", crossed, " parked=", baby._corpse_parked)
	if frozen:
		await check_lower_wall_edge(lab, group, wall)
	lab.free()

func check_lower_wall_edge(lab: Node3D, group: Node, wall: PhysicsBody3D) -> void:
	lab.get_node("HUD/SpawnBabyZombie").pressed.emit()
	var baby := group.get_child(-1) as Zombie
	baby.set_physics_process(false)
	await physics_frame
	baby.take_hit(100, Vector3.RIGHT)
	baby._update_death(1.0 / 60.0)
	var leg: PhysicalBone3D = baby.ragdoll.bodies["Leg.L"]
	var state := PhysicsServer3D.body_get_direct_state(leg.get_rid())
	var box := (leg.get_child(0) as CollisionShape3D).shape as BoxShape3D
	var floor := lab.get_node("Ground") as StaticBody3D
	# Captured leg transform at the lower edge during the 1000% launch.
	var basis := Basis(Vector3(0.077177, 0.234985, -0.968930),
		Vector3(0.946671, -0.322191, -0.002734), Vector3(-0.312823, -0.917047, -0.247320)).orthonormalized()
	var pose := Transform3D(basis, Vector3(4.348000, 0.118846, 19.796310))
	var correction := Vector3(-0.259280, 0.230669, 0.045452)
	state.transform = pose
	var moved: Vector3 = baby.ragdoll._slide_floor_wall_part(leg, state, box.size * 0.5,
		correction, 0.0, floor.get_rid())
	check(moved.x < -0.18 and moved.y >= 0.0, "The leg can withdraw from the lower wall edge above the floor")
	# This pose hits the underside with a purely vertical contact normal.
	var underside_basis := Basis(Vector3(0.136516, 0.244008, -0.960117),
		Vector3(0.976023, 0.132734, 0.172511), Vector3(0.169534, -0.960647, -0.220037)).orthonormalized()
	var underside_pose := Transform3D(underside_basis, Vector3(4.364025, 0.088364, 44.055260))
	var underside_motion := Vector3(-0.291128, 0.186346, 0.054950)
	state.transform = underside_pose
	var underside: Vector3 = baby.ragdoll._slide_floor_wall_part(leg, state, box.size * 0.5,
		underside_motion, 0.0, floor.get_rid())
	check(underside.x < -0.20 and underside.y >= 0.0,
		"The leg can withdraw from the wall's underside without a horizontal contact normal")
	var obstruction := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.08, 0.4, 0.3)
	collider.shape = shape
	obstruction.add_child(collider)
	obstruction.position = Vector3(4.02, 0.2, 19.80)
	lab.add_child(obstruction)
	await physics_frame
	state = PhysicsServer3D.body_get_direct_state(leg.get_rid())
	state.transform = pose
	var blocked: Vector3 = baby.ragdoll._slide_floor_wall_part(leg, state, box.size * 0.5,
		correction, 0.0, floor.get_rid())
	check(blocked.is_zero_approx(), "A second obstacle prevents the outward leg correction")
	print("LAB_BABY_LOWER_WALL_EDGE moved=", moved, " underside=", underside, " blocked=", blocked)

	# Rotate the same contact geometry without changing the floor height.
	var yaw := Basis(Vector3.UP, deg_to_rad(27.0))
	var rotated := Transform3D(yaw, Vector3.ZERO)
	wall.global_transform = rotated * wall.global_transform
	obstruction.global_transform = rotated * obstruction.global_transform
	await physics_frame
	await physics_frame
	state = PhysicsServer3D.body_get_direct_state(leg.get_rid())
	state.transform = rotated * pose
	var rotated_blocked: Vector3 = baby.ragdoll._slide_floor_wall_part(leg, state, box.size * 0.5,
		yaw * correction, 0.0, floor.get_rid())
	check(rotated_blocked.dot(yaw * Vector3.LEFT) < 0.18,
		"A second obstacle prevents the leg from clearing the rotated wall")
	obstruction.free()
	await physics_frame
	state = PhysicsServer3D.body_get_direct_state(leg.get_rid())
	state.transform = rotated * pose
	var rotated_edge: Vector3 = yaw.transposed() * baby.ragdoll._slide_floor_wall_part(
		leg, state, box.size * 0.5, yaw * correction, 0.0, floor.get_rid())
	state.transform = rotated * underside_pose
	var rotated_underside: Vector3 = yaw.transposed() * baby.ragdoll._slide_floor_wall_part(
		leg, state, box.size * 0.5, yaw * underside_motion, 0.0, floor.get_rid())
	check(rotated_edge.x < -0.18 and rotated_edge.y >= 0.0,
		"The leg clears the lower edge of a 27-degree wall")
	check(rotated_underside.x < -0.20 and rotated_underside.y >= 0.0,
		"The leg clears the underside of a rotated wall with a vertical contact normal")
	print("LAB_BABY_ROTATED_WALL_EDGE moved=", rotated_edge, " underside=", rotated_underside,
		" blocked=", rotated_blocked)


func add_contact_corner(lab: Node3D, yaw: float) -> Node3D:
	var corner := Node3D.new()
	corner.rotation.y = deg_to_rad(yaw)
	lab.add_child(corner)
	for face: Array in [[Vector3(6.0, 4.0, 0.0), Vector3(0.25, 8.0, 30.0)],
			[Vector3(0.0, 4.0, 0.20), Vector3(30.0, 8.0, 0.25)]]:
		var wall := StaticBody3D.new()
		wall.position = face[0]
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = face[1]
		collider.shape = box
		wall.add_child(collider)
		corner.add_child(wall)
	return corner

func attack_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)
