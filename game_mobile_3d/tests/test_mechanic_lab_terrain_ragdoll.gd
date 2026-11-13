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

func check_straddled_wall_handoff(clip: StringName, facing: float, source_frame: int, part: String) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var wall := terrain(lab, Vector3(0.60, 1.5, 0), Vector3(0.30, 3.0, 20.0), 0.0)
	var group := lab.get_node("Zombies")
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	check(group.get_child_count() == 1, "A source zombie is available for the straddled wall handoff")
	if group.get_child_count() != 1:
		lab.free()
		return
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(0, 0.02, 0)
	zombie.rotation.y = TAU * facing / 16.0
	await ticks(2)
	zombie.animation.stop()
	var rig: Skeleton3D = zombie.ragdoll.skeleton
	rig.reset_bone_poses()
	zombie.animation.play(zombie.IDLE, 0.0)
	zombie.animation.advance(0.0)
	var tracked := [rig.find_bone("J_Head"), rig.find_bone("J_R_Arm"), rig.find_bone("J_L_Arm"),
		rig.find_bone("J_R_Leg"), rig.find_bone("J_L_Leg")]
	var idle_rotations: Array[Quaternion] = []
	for bone: int in tracked:
		idle_rotations.append(rig.get_bone_pose_rotation(bone))
	zombie.animation.stop()
	rig.reset_bone_poses()
	zombie.animation.play(clip, 0.0)
	zombie.animation.advance(0.0)
	zombie.animation.seek(float(source_frame) / 30.0, true)
	var ragdoll = zombie.ragdoll
	ragdoll.sample(1.0 / 60.0)
	ragdoll.sample(1.0 / 60.0)
	var torso: Transform3D = ragdoll.current.Chest
	var source_rotations: Array[Quaternion] = []
	for bone: int in tracked:
		source_rotations.append(rig.get_bone_pose_rotation(bone))
	var limb: Transform3D = ragdoll.current[part]
	check(torso.origin.x < 0.45 and limb.origin.x > 0.55,
		"The source pose leaves a limb centre inside or across the wall")
	zombie.take_hit(100, Vector3.RIGHT, Vector2.ZERO, 0.0, 1150.0, zombie.DeathStrike.SABRE_FINISHER)
	zombie._update_death(1.0 / 60.0)
	var farthest := -INF
	for body: PhysicalBone3D in ragdoll.bodies.values():
		farthest = maxf(farthest, body.global_position.x)
	check(ragdoll.running and farthest < 0.45 and ragdoll.max_anchor_error() < 0.05,
		"The handoff places all linked bodies on the actor's side of the wall")
	check(absf(ragdoll.skeleton.global_position.x) <= 0.12 + 0.0001,
		"The handoff keeps the existing whole-pose translation limit")
	var idle_distance := 0.0
	var handoff_distance := 0.0
	for i in tracked.size():
		idle_distance += idle_rotations[i].angle_to(source_rotations[i])
		handoff_distance += rig.get_bone_pose_rotation(tracked[i]).angle_to(source_rotations[i])
	check(handoff_distance < idle_distance * 0.90,
		"The handoff retains more of the evaluated source pose than a full Idle reset")
	var handoff_gap: float = ragdoll.max_anchor_error()
	zombie.set_physics_process(true)
	var escaped := false
	for i in 90:
		await physics_frame
		if not ragdoll.running:
			break
		for body: PhysicalBone3D in ragdoll.bodies.values():
			farthest = maxf(farthest, body.global_position.x)
		escaped = escaped or farthest > 0.75
	check(not escaped, "The launch keeps all six body centres on the near side through contact")
	print("LAB_STRADDLED_WALL clip=", clip, " farthest=", farthest, " handoff_gap=", handoff_gap, " branch_change=", handoff_distance, " idle_change=", idle_distance)
	wall.free()
	lab.free()

func check_wall_pinned_joint(floor_contact := false) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var group := lab.get_node("Zombies")
	group._spawn_serial = 6 if floor_contact else 29
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "The wall-pinned joint fixture loads a source zombie")
		lab.free()
		return
	var wall := terrain(lab, Vector3(4.5, 1.5, 0), Vector3(0.30, 3.0, 18.0), 0.0)
	var zombie = group.get_child(0)
	if not floor_contact:
		zombie.set_physics_process(false)
	await ticks(2)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(1.35, 0.02, -4.05) if floor_contact else Vector3(4.05, 0.02, -2.25)
	zombie.rotation.y = -2.8697657585144 if floor_contact else 2.913067
	zombie.animation.stop()
	zombie.ragdoll.skeleton.reset_bone_poses()
	zombie.animation.play(&"Zombie_Walk" if floor_contact else &"Zombie_Walk_Variant2")
	zombie.animation.advance(0.0)
	zombie.animation.seek(0.69999988079071 if floor_contact else 0.30, true)
	var ragdoll = zombie.ragdoll
	for i in 2:
		ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, Vector3.RIGHT, Vector2.ZERO, 0.0, 1150.0, zombie.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)
	var peak := 0.0
	var farthest := -INF
	var lowest_corner := INF
	for i in 90:
		await physics_frame
		if not ragdoll.running:
			continue
		peak = maxf(peak, ragdoll.max_anchor_error())
		if floor_contact and not zombie._corpse_landed:
			lowest_corner = minf(lowest_corner, ragdoll.minimum_corner_y())
		for body: PhysicalBone3D in ragdoll.bodies.values():
			farthest = maxf(farthest, body.global_position.x)
	var limit := 0.125 if floor_contact else 0.118
	check(peak > 0.0 and peak < limit, "The %s stays within the Lab recovery limit" %
		("hip at first floor contact" if floor_contact else "wall-pinned shoulder"))
	check(farthest < 4.65, "The wall-pinned ragdoll stays on the near side")
	if floor_contact:
		check(lowest_corner >= -0.013, "The hip correction keeps the first contact inside the floor tolerance")
	print("LAB_WALL_PINNED_JOINT floor_contact=", floor_contact, " peak=", peak,
		" farthest=", farthest, " lowest_corner=", lowest_corner)
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

func check_wall_rebound(serial: int, origin: Vector3, facing: float, clip: StringName, phase: float,
		part := "Head", peak_limit := 0.115, first_contact := false, overlap_limit := INF,
		during_landing := false) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var group := lab.get_node("Zombies")
	group._spawn_serial = serial
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "The wall rebound fixture loads a source zombie")
		lab.free()
		return
	var wall := terrain(lab, Vector3(4.5, 1.5, 0), Vector3(0.30, 3.0, 18.0), 0.0)
	await ticks(2)
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = origin
	zombie.rotation.y = facing
	zombie.animation.stop()
	var ragdoll = zombie.ragdoll
	ragdoll.skeleton.reset_bone_poses()
	zombie.animation.play(clip)
	zombie.animation.advance(0.0)
	zombie.animation.seek(phase, true)
	for i in 2:
		ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, Vector3.RIGHT, Vector2.ZERO, 0.0, 1150.0, zombie.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)
	var peak := 0.0
	var farthest := -INF
	var overlap := 0.0
	var rebounded := false
	var reached_wall := false
	for i in 90:
		await physics_frame
		if not ragdoll.running:
			continue
		peak = maxf(peak, ragdoll.max_anchor_error())
		for body: PhysicalBone3D in ragdoll.bodies.values():
			farthest = maxf(farthest, body.global_position.x)
		var body: PhysicalBone3D = ragdoll.bodies[part]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if overlap_limit < INF:
			var collider := body.get_child(0) as CollisionShape3D
			var box := collider.shape as BoxShape3D
			var extent := (state.transform * collider.transform) * AABB(-box.size * 0.5, box.size)
			overlap = maxf(overlap, extent.end.x - 4.35)
		var flight_gravity := is_equal_approx(state.total_gravity.y, -50.0)
		if first_contact and reached_wall and state.linear_velocity.x < -1.0 and flight_gravity:
			rebounded = true
		for contact in state.get_contact_count():
			if state.get_contact_collider_object(contact) != wall:
				continue
			if during_landing and zombie._corpse_landed and state.linear_velocity.x < -0.1 and state.linear_velocity.y < -0.5:
				rebounded = true
			if state.linear_velocity.x > 1.0:
				reached_wall = reached_wall or flight_gravity
			if not during_landing and state.linear_velocity.x < -1.0:
				rebounded = rebounded or flight_gravity
	if first_contact:
		check(reached_wall, "%s reaches the side wall while moving inward under flight gravity" % part)
	if during_landing:
		check(rebounded, "The head moves outward and downward at the wall during the landing roll")
	else:
		check(rebounded, "%s rebounds from the side wall under flight gravity" % part)
	check(peak > 0.0 and peak < peak_limit, "The %s joint stays attached through the side impact (%s)" % [part, serial])
	check(farthest < 4.65, "The ragdoll stays on the near side of the rebound fixture wall")
	if overlap_limit < INF:
		check(overlap < overlap_limit, "The leading box limits its overlap with the side wall")
	print("LAB_WALL_REBOUND serial=", serial, " part=", part, " peak=", peak,
		" farthest=", farthest, " rebound=", rebounded, " overlap=", overlap)
	lab.free()

func run() -> void:
	await run_case(true)
	await run_case(false)
	await check_wall_handoff()
	await check_wall_handoff(true)
	await check_straddled_wall_handoff(&"Zombie_BasicAttack", 3, 17, "Arm.L")
	await check_straddled_wall_handoff(&"Zombie_Walk", 2, 11, "Arm.L")
	await check_straddled_wall_handoff(&"Zombie_Staggered", 11, 7, "Head")
	await check_wall_pinned_joint()
	await check_wall_pinned_joint(true)
	await check_edge_landing_gravity()
	await check_wall_rebound(77, Vector3(2.25, 0.02, 2.25), -0.57424086332321,
		&"Zombie_Walk_Variant2", 0.13333353201548)
	await check_wall_rebound(96, Vector3(1.35, 0.02, 4.05), 2.56416249275208,
		&"Zombie_Walk", 0.39999988079071)
	await check_wall_rebound(69, Vector3(4.05, 0.02, 1.35), 3.10392570495605,
		&"Zombie_Walk", 0.51666654745737, "Arm.R", 0.145)
	await check_wall_rebound(69, Vector3(4.05, 0.02, 1.35), 3.10486793518066,
		&"Zombie_Walk", 0.36666654745737, "Arm.R", 0.13)
	await check_wall_rebound(99, Vector3(4.05, 0.02, 4.05), -0.14667794108391,
		&"Zombie_Walk", 0.41666654745737, "Arm.L", 0.125)
	await check_wall_rebound(29, Vector3(4.05, 0.02, -2.25), -3.00971364974976,
		&"Zombie_Walk_Variant2", 0.31666686534881, "Arm.R", 0.128, true)
	await check_wall_rebound(95, Vector3(0.45, 0.02, 4.05), -2.78497982025146,
		&"Zombie_Walk_Variant2", 0.11666686534881, "Head", 0.145, true)
	await check_wall_rebound(39, Vector3(4.05, 0.02, -1.35), -1.56346619129181,
		&"Zombie_Walk", 0.39999988079071, "Head", 0.14)
	await check_wall_rebound(99, Vector3(4.05, 0.02, 4.05), -0.6086288690567,
		&"Zombie_Walk", 0.39999988079071, "Head", 0.14)
	await check_wall_rebound(46, Vector3(1.35, 0.02, -0.45), -1.91272187232971,
		&"Zombie_Walk_Variant1", 0.11666686534881, "Head", 0.13, false, 0.28)
	await check_wall_rebound(46, Vector3(1.35, 0.02, -0.45), -1.80590081214905,
		&"Zombie_Walk_Variant1", 0.13333353201548, "Head", 0.13, false, 0.28)
	await check_wall_rebound(17, Vector3(2.25, 0.02, -3.15), -0.67080754041672,
		&"Zombie_Walk_Variant2", 0.13333353201548, "Arm.L", 0.145)
	await check_wall_rebound(94, Vector3(-0.45, 0.02, 4.05), -2.41648817062378,
		&"Zombie_Walk_Variant1", 0.10000019868214, "Head", 0.13, false, INF, true)
	print("MECHANIC_LAB_TERRAIN_RAGDOLL failures=", failures)
	quit(0 if failures.is_empty() else 1)
