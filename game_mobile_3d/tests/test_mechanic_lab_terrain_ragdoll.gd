extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("FAIL ", label)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func terrain(lab: Node3D, at: Vector3, size: Vector3, angle: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	lab.add_child(body)
	body.position = at
	body.rotation.z = angle
	return body

func run_case(wall_case: bool) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var collider: StaticBody3D
	if wall_case:
		collider = terrain(lab, Vector3(2.45, 3.0, 0.0), Vector3(0.4, 6.0, 8.0), 0.0)
	else:
		collider = terrain(lab, Vector3(4.0, 1.6, 0.0), Vector3(8.0, 0.4, 8.0), deg_to_rad(22.0))
	await ticks(12)
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var group := lab.get_node("Zombies")
	check(group.get_child_count() == 1, "A source zombie is available")
	if group.get_child_count() != 1:
		lab.free()
		return
	var zombie = group.get_child(0)
	await ticks(14)
	zombie.position = Vector3(0.0, 2.7, 0.0)
	zombie.velocity = Vector3.ZERO
	zombie.reset_physics_interpolation()
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, Vector3.RIGHT)
	var first_side := -1
	var first_support := -1
	var first_landing := -1
	var side_gravity := -50.0
	for i in 100:
		await physics_frame
		if not zombie.ragdoll.running:
			continue
		if first_landing < 0 and zombie._corpse_landed:
			first_landing = i
		for name in ["Chest", "Head"]:
			var part: PhysicalBone3D = zombie.ragdoll.bodies[name]
			var state := PhysicsServer3D.body_get_direct_state(part.get_rid())
			for contact in state.get_contact_count():
				var normal := state.get_contact_local_normal(contact)
				var on_fixture := state.get_contact_collider_object(contact) == collider
				if wall_case and on_fixture and absf(normal.y) < 0.05 and first_side < 0:
					first_side = i
				if normal.y > 0.8 and (wall_case or on_fixture) and first_support < 0:
					first_support = i
			if first_side >= 0 and first_support < 0:
				side_gravity = maxf(side_gravity, state.total_gravity.y)
	if wall_case:
		check(first_side >= 0 and first_support > first_side + 2, "The corpse contacts a real wall before reaching the floor")
		check(is_equal_approx(side_gravity, -50.0), "Side-only contact retains the source flight gravity")
	check(first_support >= 0 and first_landing == first_support + 1,
		"The landing transition follows head or chest support on the %s" % ("floor" if wall_case else "bank"))
	print("RAGDOLL_TERRAIN wall=", wall_case, " side=", first_side, " support=", first_support,
		" landing=", first_landing, " side_gravity=", side_gravity)
	lab.free()

func check_wall_handoff(repositioned: bool = false) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var wall := terrain(lab, Vector3(0, 1.0, -0.655), Vector3(6.0, 3.0, 0.4), 0.0)
	var group := lab.get_node("Zombies")
	var spawned: bool = group.spawn(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"))
	check(spawned, "A source zombie is available for the wall handoff")
	if not spawned:
		lab.free()
		return
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(0.0, 0.02, 0.0)
	zombie.rotation.y = 5.0 * PI / 4.0
	zombie.animation.play(zombie.IDLE, 0.0)
	zombie.animation.advance(0.40)
	if repositioned:
		zombie.global_position.x += 24.0
	await ticks(2)
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	if repositioned:
		zombie.global_position.x -= 24.0
		zombie.reset_physics_interpolation()
	var arm: PhysicalBone3D = zombie.ragdoll.bodies["Arm.R"]
	var rig: Skeleton3D = zombie.ragdoll.skeleton
	var pose := rig.global_transform * rig.get_bone_global_pose(arm.get_bone_id()) * arm.body_offset
	zombie.take_hit(100, Vector3.RIGHT)
	zombie._update_death(1.0 / 60.0)
	var shift := arm.global_position - pose.origin
	check(absf(shift.y) < 0.001 and shift.z > 0.06 and shift.length() <= 0.12,
		"The arm near the wall retains the bounded horizontal handoff correction")
	check(zombie.ragdoll.handoff_error < 0.005, "Wall clearance translates the whole pose without a handoff snap")
	if repositioned:
		var inherited: Dictionary = zombie.ragdoll.inherited["Arm.R"]
		check(Vector3(inherited.linear).is_zero_approx() and Vector3(inherited.angular).is_zero_approx(),
			"Repositioning does not supply motion to the ragdoll")
	print("LAB_WALL_HANDOFF repositioned=", repositioned, " shift=", shift,
		" error=", zombie.ragdoll.handoff_error)
	wall.free()
	lab.free()

func check_edge_landing_gravity() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var group := lab.get_node("Zombies")
	check(group.get_child_count() == 1, "A source zombie is available for the floor-edge replay")
	if group.get_child_count() != 1:
		lab.free()
		return
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(45.0, 0.02, 0.0)
	zombie.animation.play(zombie.IDLE, 0.0)
	zombie.animation.advance(0.0)
	await ticks(2)
	zombie.take_hit(100, Vector3.RIGHT)
	zombie._update_death(1.0 / 60.0)
	# Hold a captured pose close enough to the floor for the no-contact
	# fallback, then translate every rigid part past the platform edge.
	var y_offset: float = 0.008 - zombie.ragdoll.minimum_corner_y()
	for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
		body.global_position.y += y_offset
	var head: PhysicalBone3D = zombie.ragdoll.bodies.Head
	var motion: Dictionary = zombie.ragdoll.contact_motion()
	motion.supports = 0
	zombie._landing_age = 0.0
	zombie._update_landing_forces(0.2, false, false, motion)
	check(is_equal_approx(head.gravity_scale, 1.0), "A near-floor pose above the platform retains landing gravity")
	for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
		body.global_position.x += 8.0
	zombie._update_landing_forces(1.0 / 60.0, false, false, motion)
	check(is_equal_approx(head.gravity_scale, zombie._gravity_scale(zombie.ZOMBIE_GRAVITY)),
		"A corpse entirely beyond the floor edge returns to flight gravity")
	print("LAB_EDGE_GRAVITY scale=", head.gravity_scale)
	lab.free()

func run() -> void:
	await run_case(true)
	await run_case(false)
	await check_wall_handoff()
	await check_wall_handoff(true)
	await check_edge_landing_gravity()
	print("MECHANIC_LAB_TERRAIN_RAGDOLL failures=", failures)
	quit(0 if failures.is_empty() else 1)
