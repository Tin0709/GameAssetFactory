extends SceneTree

enum CornerFixture { NONE, SUPPORT_BEVEL, PINCHED_ARM, PINCHED_ARM_FROZEN_WALLS, FROZEN_WALLS }

const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
const MeleeTools := preload("res://scripts/mechanic_lab_melee_tools.gd")

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

func terrain(lab: Node3D, at: Vector3, size: Vector3, angle: float, frozen := false) -> PhysicsBody3D:
	var body: PhysicsBody3D
	if frozen:
		var blocker := RigidBody3D.new()
		blocker.freeze = true
		body = blocker
	else:
		body = StaticBody3D.new()
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

func check_wall_handoff(repositioned: bool = false, overlaps_floor: bool = false) -> void:
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
	zombie.global_position = Vector3(0.0, -0.04 if overlaps_floor else 0.02, 0.0)
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
	if overlaps_floor:
		var leg: PhysicalBone3D = zombie.ragdoll.bodies["Leg.L"]
		var leg_shape := (leg.get_child(0) as CollisionShape3D).shape as BoxShape3D
		var leg_pose := rig.global_transform * rig.get_bone_global_pose(leg.get_bone_id()) * leg.body_offset
		check((leg_pose * AABB(-leg_shape.size * 0.5, leg_shape.size)).position.y < 0.0,
			"The wall-handoff fixture also overlaps the top of the floor")
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
	print("LAB_WALL_HANDOFF repositioned=", repositioned, " floor_overlap=", overlaps_floor, " shift=", shift,
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
	var overhang := head.get_child(0) as CollisionShape3D
	var head_half := (overhang.shape as BoxShape3D).size * 0.5
	var bounds := head.global_transform * AABB(-head_half, 2.0 * head_half)
	var floor_shape := lab.get_node("Ground/Collision") as CollisionShape3D
	var edge := floor_shape.global_position.x + (floor_shape.shape as BoxShape3D).size.x * 0.5
	head.global_position += Vector3(edge - bounds.get_center().x, -0.08 - bounds.position.y, 0.0)
	zombie._update_landing_forces(1.0 / 60.0, false, false, motion)
	check(is_equal_approx(head.gravity_scale, 1.0),
		"An overhanging head does not mask a near-floor foot during a brief gap in contacts")
	for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
		body.global_position.x += 8.0
	zombie._update_landing_forces(1.0 / 60.0, false, false, motion)
	check(is_equal_approx(head.gravity_scale, zombie._gravity_scale(zombie.ZOMBIE_GRAVITY)),
		"A corpse entirely beyond the floor edge returns to flight gravity")
	# On a 45-degree roll, the lowest corner overhangs the edge by 6 cm.
	# The first part of the head above the platform is therefore 6 cm higher.
	var tilt := Basis(Vector3.BACK, PI / 4.0)
	var low_corner := tilt * Vector3(-head_half.x, -head_half.y, 0.0)
	var floor_top := floor_shape.global_position.y + (floor_shape.shape as BoxShape3D).size.y * 0.5
	head.global_transform = Transform3D(tilt, Vector3(edge + 0.06, floor_top - 0.05, 0.0) - low_corner)
	zombie._update_landing_forces(0.2, true, false, motion)
	check(is_equal_approx(head.gravity_scale, 1.0),
		"A rolling head 1 cm above the platform retains landing gravity even when its lowest corner overhangs")
	head.global_position.y += 0.05
	zombie._update_landing_forces(1.0 / 60.0, true, false, motion)
	check(is_equal_approx(head.gravity_scale, zombie._gravity_scale(zombie.ZOMBIE_GRAVITY)),
		"A head 6 cm clear of the platform returns to flight gravity even when its overhanging corner is level with it")
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

func check_corner_ragdoll(seed: int, settle_seconds: float, should_settle := true, landing_gravity := -1.0,
		max_anchor_gap := INF, strike: Zombie.DeathStrike = Zombie.DeathStrike.SABRE_FINISHER,
		strength := 1150.0, shared_wall := false, fixture := CornerFixture.NONE, tuning := Vector2.ONE,
		wall_yaw := 0.0, pose := &"") -> void:
	var lab: Node3D = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var frozen := fixture in [CornerFixture.PINCHED_ARM_FROZEN_WALLS, CornerFixture.FROZEN_WALLS]
	var layout: Node3D = lab
	if wall_yaw != 0.0:
		layout = Node3D.new()
		layout.rotation.y = wall_yaw
		lab.add_child(layout)
	var first_wall := terrain(layout, Vector3(4.5, 1.5, -1.85), Vector3(0.30, 3.0, 12.4), 0.0, frozen)
	var second_wall := terrain(layout, Vector3(-1.70, 1.5, 4.5), Vector3(12.7, 3.0, 0.30), 0.0, frozen)
	if shared_wall:
		second_wall.get_child(0).reparent(first_wall)
		second_wall.free()
		second_wall = first_wall
	if fixture in [CornerFixture.SUPPORT_BEVEL, CornerFixture.PINCHED_ARM, CornerFixture.PINCHED_ARM_FROZEN_WALLS]:
		var bevel_face := terrain(lab, Vector3(4.35, 0.73, 4.35), Vector3(0.10, 1.46, 0.26), 0.0)
		bevel_face.rotation.y = -PI / 4.0
	var group := lab.get_node("Zombies")
	group._spawn_serial = 1800 + seed
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "The closed corner fixture loads a source zombie")
		lab.free()
		return
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 472031 + seed
	var gap := rng.randf_range(0.47, 0.70) if seed % 128 < 64 else rng.randf_range(0.9, 3.0)
	zombie.global_position = Vector3(4.35 - gap, 0.02, 4.35 - gap + rng.randf_range(-0.035, 0.035))
	zombie.rotation.y = rng.randf_range(-PI, PI) + wall_yaw
	if layout != lab:
		zombie.global_position = layout.to_global(zombie.global_position)
	zombie.animation.stop()
	zombie.ragdoll.skeleton.reset_bone_poses()
	var clip: StringName = pose if pose != &"" else (zombie.ATTACK if seed % 2 == 0 else zombie.WALK_CLIPS[seed % 3])
	if not zombie.animation.has_animation(clip):
		check(false, "The corner fixture needs its source pose")
		lab.free()
		return
	zombie.animation.play(clip)
	zombie.animation.advance(0.0)
	zombie.animation.seek(rng.randf_range(0.05, 0.40), true)
	await ticks(2)
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	var direction := Vector3(1, 0, 1).normalized().rotated(Vector3.UP, rng.randf_range(-0.18, 0.18))
	zombie.ragdoll_launch_multiplier = tuning.x
	zombie.ragdoll_gravity_multiplier = tuning.y
	zombie.take_hit(100, layout.global_basis * direction if layout != lab else direction, Vector2.ZERO, 0.0, strength, strike)
	zombie.set_physics_process(true)
	var last_simulated: Array[Transform3D] = []
	var skeleton: Skeleton3D = zombie.ragdoll.skeleton
	skeleton.skeleton_updated.connect(func() -> void:
		if zombie.ragdoll.running:
			last_simulated.clear()
			for bone in skeleton.get_bone_count():
				last_simulated.append(skeleton.get_bone_global_pose(bone)))
	var peak_gap := 0.0
	var farthest := 0.0
	var walls_hit := {}
	var corner_samples := 0
	var missed_corner_samples := 0
	var used_handoff := false
	for i in roundi(settle_seconds * 60.0):
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		used_handoff = used_handoff or zombie.ragdoll._wall_handoff_frame >= 0
		peak_gap = maxf(peak_gap, zombie.ragdoll.max_anchor_error())
		var upper_wall_faces := 0
		for part: PhysicalBone3D in zombie.ragdoll.bodies.values():
			var position := layout.to_local(part.global_position) if layout != lab else part.global_position
			farthest = maxf(farthest, maxf(position.x, position.z))
			var state := PhysicsServer3D.body_get_direct_state(part.get_rid())
			for index in state.get_contact_count():
				var collider := state.get_contact_collider_object(index)
				if collider == first_wall:
					var face := state.get_contact_collider_shape(index) if shared_wall else 0
					walls_hit[face] = true
					if fixture == CornerFixture.SUPPORT_BEVEL and part in [zombie.ragdoll.bodies.Head, zombie.ragdoll.bodies.Chest]:
						var normal := state.get_contact_local_normal(index)
						if (face == 0 and absf(normal.x) > 0.99) or (face == 1 and absf(normal.z) > 0.99):
							upper_wall_faces |= 1 << face
				elif collider == second_wall:
					walls_hit[1] = true
		if fixture == CornerFixture.SUPPORT_BEVEL and upper_wall_faces == 3 and zombie.ragdoll.contact_motion().leg_supported:
			corner_samples += 1
			missed_corner_samples += int(not zombie.ragdoll.has_flat_corner_brace())
	check(walls_hit.size() == 2 and farthest < 4.65,
		"The corner ragdoll %d meets both faces and stays on the near side" % seed)
	check(zombie._corpse_parked == should_settle and (not should_settle or zombie.ragdoll.bodies.is_empty()),
		"The corner ragdoll %d has the expected rest state" % seed)
	if fixture == CornerFixture.SUPPORT_BEVEL:
		check(corner_samples > 0 and missed_corner_samples == 0,
			"The bevel leaves both supporting wall faces visible to the corner check")
		print("LAB_BEVELED_CORNER samples=", corner_samples, " missed=", missed_corner_samples)
	elif fixture in [CornerFixture.PINCHED_ARM, CornerFixture.PINCHED_ARM_FROZEN_WALLS]:
		check(used_handoff, "The pinched right arm is corrected before the first ragdoll step")
	if should_settle and zombie._corpse_parked:
		var pose_matches := last_simulated.size() == skeleton.get_bone_count()
		for bone in last_simulated.size():
			pose_matches = pose_matches and last_simulated[bone].is_equal_approx(skeleton.get_bone_global_pose(bone))
		check(pose_matches, "The corner ragdoll %d retains its final simulated pose" % seed)
	if max_anchor_gap < INF:
		check(peak_gap > 0.0 and peak_gap < max_anchor_gap,
			"Limb joints stay connected during the corner collision (%d, strike %d, %.3f m)" % [seed, strike, peak_gap])
	if landing_gravity >= 0.0 and not zombie._corpse_parked:
		var head: PhysicalBone3D = zombie.ragdoll.bodies.Head
		check(is_equal_approx(head.gravity_scale, landing_gravity), "The corner ragdoll %d uses the expected gravity" % seed)
	print("LAB_CORNER seed=", seed, " shared_wall=", shared_wall, " frozen=", frozen,
		" gap=", peak_gap, " farthest=", farthest, " walls=", walls_hit.size(),
		" parked=", zombie._corpse_parked, " seconds=", zombie._corpse_age)
	lab.free()

func check_wall_brace_impact(seed: int, wall_angle: float, strike_angle: float, attack: String,
		sword: bool, clip: StringName, launch_percent := 1000.0, combo_index := 0) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	for frame in 10:
		await process_frame
	lab.get_node("HUD/RagdollTuning/Launch/Slider").value = launch_percent
	var corner := Node3D.new()
	lab.add_child(corner)
	corner.rotation.y = deg_to_rad(wall_angle)
	terrain(corner, Vector3(6.0, 4.0, 0.0), Vector3(0.25, 8.0, 30.0), 0.0)
	terrain(corner, Vector3(0.0, 4.0, 0.20), Vector3(30.0, 8.0, 0.25), 0.0)
	var group := lab.get_node("Zombies")
	group._spawn_serial = seed
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	check(group.get_child_count() == 1, "The wall brace fixture loads an adult zombie")
	if group.get_child_count() != 1:
		lab.free()
		return
	var zombie := group.get_child(0) as Zombie
	zombie.set_physics_process(false)
	zombie.global_position = corner.to_global(Vector3(3.0, 0.02, 2.0))
	zombie.rotation.y = seed * 0.47 + corner.rotation.y
	zombie.animation.play(clip)
	zombie.animation.advance(0.0)
	zombie.animation.seek(zombie.animation.get_animation(clip).length * (float(seed % 10) * 0.1), true)
	await physics_frame
	for sample in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	var angle := deg_to_rad(strike_angle)
	var direction := Vector3(cos(angle), 0.0, sin(angle))
	group.sword_equipped = sword
	var strike: Dictionary = group.AIR_STRIKE if attack == "AirAttack" else group.SABRE_STRIKES[combo_index]
	if sword:
		strike = group.SWORD_STRIKES[0]
	zombie.health = 1
	group._apply_contact(zombie, zombie.combat_center(), attack, combo_index, seed, strike, direction, false,
		zombie.global_position - direction)
	zombie.set_physics_process(true)

	var landed := -1
	var parked := -1
	var crossed := false
	for frame in 284:
		await physics_frame
		if zombie._corpse_landed and landed < 0:
			landed = frame
		if zombie._corpse_parked:
			parked = frame
			break
		if not zombie.ragdoll.running:
			continue
		for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
			var local := corner.to_local(body.global_position)
			crossed = crossed or (local.y > 0.0 and local.y < 7.9 and (local.x > 6.13 or local.z < 0.07))
	check(landed > 20 and parked > landed + 30 and zombie.ragdoll.bodies.is_empty() and not crossed,
		"An adult zombie braced against a wall settles after the initial bounce (case %d)" % seed)
	print("LAB_WALL_BRACE_IMPACT launch=", launch_percent, " seed=", seed, " landed=", landed, " parked=", parked, " crossed=", crossed)
	lab.free()


func stacked_wall_lab(seam: float) -> Node3D:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.player.position = Vector3(-8.0, 0.0, -8.0)
	var wall := StaticBody3D.new()
	# Two stacked boxes make one continuous face, with a seam at arm height.
	for dimensions in [[Vector3(4.5, 1.5, 0.0), Vector3(0.30, 3.0, 20.0)],
			[Vector3(-2.0, seam * 0.5, 4.5), Vector3(12.7, seam, 0.30)],
			[Vector3(-2.0, (3.0 + seam) * 0.5, 4.5), Vector3(12.7, 3.0 - seam, 0.30)]]:
		var box := BoxShape3D.new()
		box.size = dimensions[1]
		var collider := CollisionShape3D.new()
		collider.shape = box
		collider.position = dimensions[0]
		wall.add_child(collider)
	lab.add_child(wall)
	await ticks(2)
	return lab


func launch_at_stacked_wall(lab: Node3D, seed: int, strength: float, clip: StringName) -> Zombie:
	var group := lab.get_node("Zombies")
	group._spawn_serial = 3700 + seed
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "The stacked-wall fixture loads a source zombie")
		return null
	var zombie := group.get_child(0) as Zombie
	zombie.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 402910 + seed
	var gap := rng.randf_range(0.48, 0.75) if seed % 2 == 0 else rng.randf_range(0.85, 2.20)
	zombie.position = Vector3(4.35 - gap, 0.0, 4.35 - gap + rng.randf_range(-0.45, 0.45) * 0.12)
	zombie.rotation.y = rng.randf_range(-PI, PI)
	var direction := Vector3(1, 0, 1).normalized().rotated(Vector3.UP, rng.randf_range(-0.20, 0.20))
	var phase := rng.randf_range(0.0, 1.0)
	zombie.reset_physics_interpolation()
	await ticks(2)
	zombie.animation.stop()
	zombie.ragdoll.skeleton.reset_bone_poses()
	zombie.animation.play(clip, 0.0)
	zombie.animation.advance(0.0)
	zombie.animation.seek(phase * zombie.animation.get_animation(clip).length, true)
	zombie.ragdoll.sample(1.0 / 60.0)
	zombie.ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, direction, Vector2.ZERO, 0.0, strength, Zombie.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)
	return zombie


func check_stacked_wall_handoff(seam: float, seed: int, strength: float, clips: Array[StringName]) -> void:
	var lab := await stacked_wall_lab(seam)
	for clip in clips:
		var zombie := await launch_at_stacked_wall(lab, seed, strength, clip)
		if zombie == null:
			break
		var peak_gap := 0.0
		var farthest := 0.0
		for tick in 120:
			await physics_frame
			if zombie._corpse_parked:
				break
			peak_gap = maxf(peak_gap, zombie.ragdoll.max_anchor_error())
			for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
				farthest = maxf(farthest, maxf(body.global_position.x, body.global_position.z))
		check(zombie.ragdoll._wall_handoff_frame >= 0 and zombie._corpse_parked,
			"The stacked-wall ragdoll corrects its launch pose and comes to rest (%s)" % clip)
		check(peak_gap < 0.14 and farthest < 4.65,
			"The shoulder clears the wall seam without stretching or crossing the wall (%s, %.3f m)" % [clip, peak_gap])
		print("LAB_STACKED_WALL clip=", clip, " seam=", seam, " gap=", peak_gap, " farthest=", farthest,
			" settled=", zombie._corpse_parked)
		zombie.free()
	lab.free()


func check_one_foot_stacked_wall_landing() -> void:
	var lab := await stacked_wall_lab(1.35)
	# Reuse the same corner for both launches to cover a second combat contact.
	var first := await launch_at_stacked_wall(lab, 62, 800.0, &"Zombie_ExpressiveWalk")
	if first == null:
		lab.free()
		return
	await ticks(294)
	check(first._corpse_landed, "The first launch lands after sliding down the stacked wall")
	first.free()
	var zombie := await launch_at_stacked_wall(lab, 95, 800.0, &"Zombie_ExpressiveWalk")
	if zombie == null:
		lab.free()
		return
	var result := await measure_braced_landing(zombie)
	check(result.landing >= 1.5 and result.landing <= 2.15, "A supported one-foot wall brace enters the normal landing blend")
	check(result.samples >= 30 and result.peak_step < 0.004,
		"The late one-foot brace stays simulated with less than 4 mm of torso movement per step")
	print("LAB_STACKED_WALL_LANDING landing=", result.landing, " late_step=", result.peak_step, " samples=", result.samples)
	lab.free()


func check_sustained_wall_landing() -> void:
	var lab := await stacked_wall_lab(1.08)
	var zombie := await launch_at_stacked_wall(lab, 105, 1150.0, &"Zombie_ExpressiveRun")
	if zombie != null:
		var result := await measure_braced_landing(zombie)
		check(result.landing >= 2.0 and result.landing <= 3.2,
			"The long one-foot wall brace enters landing after the initial tumble")
		check(result.samples >= 30 and result.peak_step < 0.0015,
			"The planted zombie simulates with less than 1.5 mm of late torso movement per step")
		print("LAB_SUSTAINED_WALL_LANDING ", result)
	lab.free()


func measure_braced_landing(zombie: Zombie) -> Dictionary:
	var landing := INF
	var previous_chest := Vector3.INF
	var peak_late_step := 0.0
	var measured_steps := 0
	for tick in 294:
		await physics_frame
		if zombie._corpse_parked:
			break
		if zombie._corpse_landed and not is_finite(landing):
			landing = zombie._corpse_age
		if zombie._corpse_age < 3.5 or not zombie.ragdoll.running:
			continue
		var chest: Vector3 = zombie.ragdoll.bodies.Chest.global_position
		if previous_chest.is_finite():
			peak_late_step = maxf(peak_late_step, previous_chest.distance_to(chest))
			measured_steps += 1
		previous_chest = chest
	return {"landing": landing, "peak_step": peak_late_step, "samples": measured_steps}


func check_wall_shoulder_rebound(seam: float, seed: int, clip: StringName, gap_limit: float,
		landing_time := INF) -> void:
	var lab := await stacked_wall_lab(seam)
	var zombie := await launch_at_stacked_wall(lab, seed, 1150.0, clip)
	if zombie == null:
		lab.free()
		return
	var peak_gap := 0.0
	var landing := INF
	var farthest := 0.0
	for tick in 48:
		await physics_frame
		if not zombie.ragdoll.running:
			continue
		peak_gap = maxf(peak_gap, zombie.ragdoll.max_anchor_error())
		for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
			farthest = maxf(farthest, maxf(body.global_position.x, body.global_position.z))
		if zombie._corpse_landed and not is_finite(landing):
			landing = zombie._corpse_age
	check(zombie.ragdoll._wall_handoff_frame < 0, "The shoulder hits the wall after a clean launch")
	if is_finite(landing_time):
		check(is_equal_approx(landing, landing_time), "The shoulder rebound keeps its first landing time")
	check(peak_gap < gap_limit and farthest < 4.35,
		"The shoulder stays connected during a corner rebound (%s at seam %.2f m, gap %.3f m)" % [clip, seam, peak_gap])
	print("LAB_WALL_SHOULDER_REBOUND clip=", clip, " seam=", seam, " gap=", peak_gap, " farthest=", farthest,
		" landing=", landing)
	lab.free()


func check_wall_entry_rays() -> void:
	var rig := preload("res://scripts/mechanic_lab_ragdoll.gd").new()
	var fixture := Node3D.new()
	root.add_child(fixture)
	fixture.add_child(rig)
	var wall := AABB(Vector3(0.0, 0.0, -1.0), Vector3(0.3, 2.0, 2.0))
	terrain(fixture, wall.get_center(), wall.size, 0.0)
	await ticks(2)
	# Recreate the single-wall neighborhood established during a handoff.
	rig._handoff_ray_region = wall.grow(1.0)
	rig._handoff_region_wall = wall
	rig._handoff_region_floor = AABB(Vector3(-2, -1, -2), Vector3(4, 1, 4))
	rig._handoff_ray.collision_mask = 1
	var space := fixture.get_world_3d().direct_space_state
	var outside := Vector3(-0.02, 1.0, 0.0)
	var inside := Vector3(0.02, 1.0, 0.0)
	check(not rig._wall_ray_crosses(space, outside, inside, Vector3.ZERO, 0.0, {}),
		"Wall handoff ignores ray travel below the existing anchor tolerance")
	check(not rig._wall_ray_crosses(space, inside, Vector3(-0.12, 1.0, 0.0), Vector3.ZERO, 0.0, {}),
		"A wall ray starting inside the box keeps the native ray semantics")
	check(rig._wall_ray_crosses(space, Vector3(-0.12, 1.0, 0.0), inside, Vector3.ZERO, 0.0, {}),
		"An exterior ray reaching the same wall interior rejects the pose")
	fixture.free()

func check_free_arm_at_compound_wall() -> void:
	var lab: Node3D = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var wall := terrain(lab, Vector3(0, 1.5, 4.50), Vector3(12, 3, 0.30), 0.0)
	var other := terrain(lab, Vector3(4.50, 1.5, 0), Vector3(0.30, 3, 12), 0.0)
	other.get_child(0).reparent(wall)
	other.free()
	var group := lab.get_node("Zombies")
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "The compound shoulder fixture loads an adult")
		lab.free()
		return
	var zombie := group.get_child(0) as Zombie
	var ragdoll := zombie.ragdoll
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(0, 3.0, 0)
	await ticks(1)
	for sample in 2:
		ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, Vector3.FORWARD, Vector2.ZERO, 0.0, 1150.0, Zombie.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)
	await ticks(1)
	zombie.set_physics_process(false)
	check(ragdoll.running and ragdoll._wall_handoff_frame < 0, "The compound shoulder starts from a clean launch")
	if not ragdoll.running:
		lab.free()
		return
	var limb: PhysicalBone3D = ragdoll.bodies["Arm.L"]
	var chest: PhysicalBone3D = ragdoll.bodies.Chest
	var arm := PhysicsServer3D.body_get_direct_state(limb.get_rid())
	var core := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	# Restore the third-step compound-wall sample independently of solver ordering.
	var start := Transform3D(Basis(Quaternion(-0.19653854, 0.93974185, 0.12168454, -0.25189444)),
		Vector3(3.00102735, 1.58355558, 3.96992183))
	core.transform = Transform3D(Basis(Quaternion(-0.00200266, -0.59945297, 0.79507399, 0.09224670)),
		Vector3(3.90424490, 1.29187953, 3.90114474))
	var joint: Dictionary = ragdoll.source_joints["Arm.L"]
	var parent_frame: Transform3D = joint.parent_frame
	var child_frame: Transform3D = joint.child_frame
	arm.transform = start
	arm.linear_velocity = Vector3(-22.0, -8.5, -0.9)
	var linear := arm.linear_velocity
	var angular := arm.angular_velocity
	var orientation := arm.transform.basis
	var overlap := ragdoll._deepest_contact(ragdoll._terrain_contact_points(limb, arm, Vector3.ZERO))
	check(arm.get_contact_count() == 0 and overlap > 0.02 and overlap < 0.035,
		"The released arm still starts inside a shallow wall overlap")
	ragdoll._slide_wall_shoulder_anchors()
	var gap := (core.transform * parent_frame).origin.distance_to((arm.transform * child_frame).origin)
	check(gap < 0.06 and ragdoll._terrain_contact_points(limb, arm, Vector3.ZERO).is_empty(),
		"The free shoulder can return to its source anchor through a clear path")
	check(arm.transform.basis.is_equal_approx(orientation) and arm.linear_velocity == linear and arm.angular_velocity == angular,
		"The shoulder correction preserves rotation and rebound velocities")
	print("LAB_COMPOUND_FREE_ARM gap=", gap, " start_overlap=", overlap)
	lab.free()


func run() -> void:
	if OS.get_cmdline_user_args().has("--compound-contact-arm"):
		await check_corner_ragdoll(20, 2.0, true, -1.0, 0.29, Zombie.DeathStrike.SABRE_FINISHER,
			1150.0, true, CornerFixture.NONE, Vector2.ONE, deg_to_rad(27.0), Zombie.ActionsStuff.ATTACK)
		await check_corner_ragdoll(2, 2.0, true, -1.0, 0.30, Zombie.DeathStrike.SABRE_FINISHER,
			1150.0, true, CornerFixture.NONE, Vector2.ONE, deg_to_rad(27.0), Zombie.ActionsStuff.ATTACK)
		print("LAB_COMPOUND_CONTACT_ARM failures=", failures)
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--compound-free-arm"):
		await check_free_arm_at_compound_wall()
		print("LAB_COMPOUND_ARM failures=", failures)
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--rotated-wall-arm"):
		await check_corner_ragdoll(24, 4.90, true, -1.0, 0.18, Zombie.DeathStrike.SABRE_FINISHER,
			1150.0, false, CornerFixture.NONE, Vector2.ONE, deg_to_rad(27.0), Zombie.ActionsStuff.ATTACK)
		print("LAB_ROTATED_WALL_ARM failures=", failures)
		quit(0 if failures.is_empty() else 1)
		return
	await check_wall_entry_rays()
	await run_case(true)
	await run_case(false)
	await check_wall_handoff()
	await check_wall_handoff(true)
	await check_wall_handoff(false, true)
	await check_straddled_wall_handoff(&"Zombie_BasicAttack", 3, 17, "Arm.L")
	await check_straddled_wall_handoff(&"Zombie_Walk", 2, 11, "Arm.L")
	await check_straddled_wall_handoff(&"Zombie_Staggered", 11, 7, "Head")
	await check_wall_pinned_joint()
	await check_wall_pinned_joint(true)
	await check_edge_landing_gravity()
	await check_corner_ragdoll(16, 2.0, true, -1.0, 0.18)
	await check_corner_ragdoll(16, 2.0, true, -1.0, 0.22, Zombie.DeathStrike.GROUND,
		MeleeTools.strikes(MeleeTools.Tool.SHOVEL).back().strength)
	await check_corner_ragdoll(16, 2.0, true, -1.0, 0.24, Zombie.DeathStrike.AIR,
		MeleeTools.air_strike(MeleeTools.Tool.PICKAXE).strength)
	await check_corner_ragdoll(77, 2.0, true, -1.0, 0.25, Zombie.DeathStrike.AIR,
		MeleeTools.air_strike(MeleeTools.Tool.PICKAXE).strength)
	await check_corner_ragdoll(170, 2.0, true, -1.0, 0.23)
	await check_corner_ragdoll(287, 2.0, true, -1.0, 0.17)
	await check_corner_ragdoll(396, 2.0, true, -1.0, 0.19)
	await check_corner_ragdoll(433, 2.0, true, -1.0, 0.20)
	await check_corner_ragdoll(65, 4.25)
	await check_corner_ragdoll(29, 4.25, false, 50.0 / float(ProjectSettings.get_setting("physics/3d/default_gravity")))
	await check_corner_ragdoll(101, 4.05)
	await check_corner_ragdoll(113, 4.95)
	await check_corner_ragdoll(238, 4.90, false, 1.0)
	await check_corner_ragdoll(113, 4.60, true, -1.0, 0.12, Zombie.DeathStrike.SABRE_FINISHER, 1150.0, true)
	await check_corner_ragdoll(108, 4.90, false, 1.0, 0.09, Zombie.DeathStrike.SABRE_FINISHER, 1150.0, true)
	await check_corner_ragdoll(238, 4.80, true, -1.0, 0.12, Zombie.DeathStrike.SABRE_FINISHER, 1150.0, true)
	await check_corner_ragdoll(87, 4.90, true, -1.0, 0.09, Zombie.DeathStrike.SABRE_FINISHER,
		1150.0, true, CornerFixture.SUPPORT_BEVEL)
	await check_corner_ragdoll(141, 2.0, true, -1.0, 0.18, Zombie.DeathStrike.SABRE_FINISHER,
		1150.0, true, CornerFixture.PINCHED_ARM)
	await check_corner_ragdoll(141, 2.0, true, -1.0, 0.18, Zombie.DeathStrike.SABRE_FINISHER,
		1150.0, false, CornerFixture.PINCHED_ARM_FROZEN_WALLS)
	for seed: int in [5, 13, 36, 43]:
		await check_corner_ragdoll(seed, 0.40, false, -1.0, INF, Zombie.DeathStrike.SABRE_FINISHER,
			1150.0, true, CornerFixture.NONE, Vector2(10.0, 10.0))
	# The feet and torso stay supported while the head rests against both faces.
	await check_corner_ragdoll(90, 4.90, true, -1.0, INF, Zombie.DeathStrike.SABRE_FINISHER,
		1150.0, true, CornerFixture.NONE, Vector2(10.0, 10.0))
	await check_wall_rebound(77, Vector3(2.25, 0.02, 2.25), -0.57424086332321,
		&"Zombie_Walk_Variant2", 0.13333353201548)
	await check_wall_rebound(96, Vector3(1.35, 0.02, 4.05), 2.56416249275208,
		&"Zombie_Walk", 0.39999988079071)
	await check_wall_rebound(19, Vector3(4.05, 0.02, -3.15), 0.02946007624269,
		&"Zombie_BasicAttack", 1.45, "Arm.L", 0.12, true)
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
	await check_corner_ragdoll(101, 4.95, true, -1.0, INF, Zombie.DeathStrike.SABRE_FINISHER,
		1150.0, false, CornerFixture.FROZEN_WALLS)
	await check_wall_brace_impact(20, 27.0, -58.0, "Attack", true, Zombie.ATTACK)
	await check_wall_brace_impact(69, 45.0, -85.0, "AirAttack", false, Zombie.IDLE)
	await check_wall_brace_impact(74, 45.0, -85.0, "Attack", false, Zombie.ATTACK)
	await check_wall_brace_impact(29, 27.0, -58.0, "Attack", false, Zombie.ATTACK, 100.0, 2)
	await check_stacked_wall_handoff(1.08, 24, 1150.0, [&"Zombie_ExpressiveWalk", &"Zombie_ExpressiveRun"])
	await check_stacked_wall_handoff(1.35, 24, 1150.0, [&"Zombie_Walk"])
	await check_stacked_wall_handoff(1.35, 130, 800.0, [&"Zombie_Walk_Variant1"])
	await check_one_foot_stacked_wall_landing()
	await check_sustained_wall_landing()
	await check_wall_shoulder_rebound(1.08, 77, &"Zombie_ExpressiveRun", 0.145, 17.0 / 60.0)
	await check_wall_shoulder_rebound(1.08, 73, &"Zombie_ExpressiveWalk", 0.145)
	await check_wall_shoulder_rebound(1.35, 73, &"Zombie_ExpressiveWalk", 0.145)
	await check_wall_shoulder_rebound(1.08, 73, &"Zombie_Walk_Variant1", 0.26)
	print("MECHANIC_LAB_TERRAIN_RAGDOLL failures=", failures)
	quit(0 if failures.is_empty() else 1)
