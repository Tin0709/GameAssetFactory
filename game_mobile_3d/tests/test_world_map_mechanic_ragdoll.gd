extends SceneTree

const Zombies := preload("res://scripts/mechanic_lab_zombies.gd")
const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func terrain_contact_depth(zombie: Node3D) -> float:
	var deepest := 0.0
	for part: PhysicalBone3D in zombie.ragdoll.bodies.values():
		var state := PhysicsServer3D.body_get_direct_state(part.get_rid())
		for i in state.get_contact_count():
			var collider := state.get_contact_collider_object(i) as Node
			if collider == null or collider.name != "WorldCollision":
				continue
			# Godot reports the two points and the normal in world coordinates.
			var separation := state.get_contact_collider_position(i) - state.get_contact_local_position(i)
			deepest = maxf(deepest, separation.dot(state.get_contact_local_normal(i)))
	return deepest

func launch(world: Node3D, group: Node3D, effects: Node3D, start: Vector3, direction: Vector3,
		strike := Zombie.DeathStrike.SABRE_FINISHER, yaw := 0.0, launch_multiplier := 1.0) -> Node3D:
	if not group.spawn(world.player, Basis.IDENTITY, effects):
		check(false, "The verified zombie is available on WorldMap")
		return null
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = start + Vector3.UP * 0.02
	zombie.rotation.y = yaw
	zombie.animation.play(Zombie.IDLE)
	zombie.animation.advance(0.2)
	zombie.reset_physics_interpolation()
	await ticks(2)
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	zombie.ragdoll_launch_multiplier = launch_multiplier
	zombie.take_hit(100, direction, Vector2.ZERO, 0.0, 800.0, strike)
	zombie.set_physics_process(true)
	return zombie

func cliff_case(world: Node3D, group: Node3D, effects: Node3D) -> void:
	var zombie = await launch(world, group, effects, Vector3(-37.5, 3.0, -33.5), Vector3.FORWARD)
	if zombie == null:
		return
	var first_wall := -1
	var first_landing := -1
	var supported_without_torso := false
	var wall_gravity := 0.0
	var settled_gravity := 0.0
	var parked_frame := -1
	var smallest_rest_axis_y := 1.0
	var worst_overlap := 0.0
	for frame in 135:
		await physics_frame
		if zombie._corpse_parked:
			parked_frame = frame
			break
		if not zombie.ragdoll.running:
			break
		worst_overlap = maxf(worst_overlap, terrain_contact_depth(zombie))
		var contact: Dictionary = zombie.ragdoll.contact_motion()
		supported_without_torso = supported_without_torso or (contact.supports >= 2 and contact.core_supports == 0)
		if zombie._corpse_landed and first_landing < 0:
			first_landing = frame
		var chest: PhysicalBone3D = zombie.ragdoll.bodies.Chest
		var chest_state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
		settled_gravity = chest_state.total_gravity.y
		if first_landing >= 0:
			var parts: Dictionary = zombie.ragdoll.bodies
			var feet: Vector3 = (parts["Leg.L"].global_position + parts["Leg.R"].global_position) * 0.5
			var axis: Vector3 = (parts.Head.global_position - feet).normalized()
			smallest_rest_axis_y = minf(smallest_rest_axis_y, absf(axis.y))
		for part: PhysicalBone3D in zombie.ragdoll.bodies.values():
			var state := PhysicsServer3D.body_get_direct_state(part.get_rid())
			for i in state.get_contact_count():
				var collider := state.get_contact_collider_object(i) as Node
				var is_wall := absf(state.get_contact_local_normal(i).y) < 0.05
				if first_wall < 0 and collider != null and collider.name == "WorldCollision" and is_wall:
					first_wall = frame
					wall_gravity = chest_state.total_gravity.y
	check(first_wall >= 0 and is_equal_approx(wall_gravity, -50.0),
		"The authored rock wall transfers a side impact while flight gravity is active")
	check(supported_without_torso and first_landing > first_wall and first_landing < 90,
		"Stable support at the foot of the cliff starts landing within 1.5 s")
	check(settled_gravity > -30.0, "A supported body leaves its flight-gravity state")
	check(parked_frame > first_landing and parked_frame < 120 and smallest_rest_axis_y < 0.32,
		"The corpse rolls away from the rock corner and comes to a supported rest within two seconds")
	check(worst_overlap < 0.12, "The cliff contact stays within the terrain penetration budget")
	print("WORLDMAP_CLIFF wall=", first_wall, " landing=", first_landing, " gravity=", settled_gravity,
		" park=", parked_frame, " min_axis_y=", smallest_rest_axis_y, " peak_overlap_m=", worst_overlap)
	zombie.free()
	await ticks(2)

func ledge_case(world: Node3D, group: Node3D, effects: Node3D, strike: Zombie.DeathStrike,
		frames: int, start := Vector3(-33.5, 9.0, -39.5), direction := Vector3.RIGHT, yaw := 0.0,
		anchor_limit := 0.12, launch_multiplier := 1.0) -> void:
	var zombie = await launch(world, group, effects, start, direction, strike, yaw, launch_multiplier)
	if zombie == null:
		return
	var first_landing := -1
	var chest_height := INF
	var worst_anchor := 0.0
	var worst_overlap := 0.0
	var ledge_contact := false
	var parked_frame := -1
	for frame in frames:
		await physics_frame
		if zombie._corpse_parked:
			parked_frame = frame
			break
		if not zombie.ragdoll.running:
			continue
		worst_anchor = maxf(worst_anchor, zombie.ragdoll.max_anchor_error())
		worst_overlap = maxf(worst_overlap, terrain_contact_depth(zombie))
		var chest: PhysicalBone3D = zombie.ragdoll.bodies.Chest
		chest_height = minf(chest_height, chest.global_position.y)
		for name in ["Head", "Chest"]:
			var part: PhysicalBone3D = zombie.ragdoll.bodies[name]
			var state := PhysicsServer3D.body_get_direct_state(part.get_rid())
			for i in state.get_contact_count():
				var collider := state.get_contact_collider_object(i) as Node
				if collider != null and collider.name == "WorldCollision" and state.get_contact_local_normal(i).y > 0.8:
					ledge_contact = true
		if zombie._corpse_landed and first_landing < 0:
			first_landing = frame
	check(first_landing > 25 and first_landing < 60 and ledge_contact and chest_height < 6.0,
		"The corpse crosses the authored ledge and contacts the lower terrain")
	check(worst_anchor < anchor_limit, "The first impact on the lower terrace keeps the limb anchors connected")
	check(worst_overlap < 0.12, "The ledge contact at %.0f%% launch stays within the terrain penetration budget" % (launch_multiplier * 100.0))
	if strike == Zombie.DeathStrike.GROUND:
		check(parked_frame > first_landing and parked_frame < 150,
			"A forward melee finisher rolls off its upright foot support and settles within 2.5 seconds")
	print("WORLDMAP_LEDGE strike=", strike, " landing=", first_landing,
		" minimum_chest_y=", chest_height, " peak_anchor_m=", worst_anchor, " park=", parked_frame,
		" peak_overlap_m=", worst_overlap)
	zombie.free()
	await ticks(2)

func oblique_cliff_case(world: Node3D, group: Node3D, effects: Node3D) -> void:
	group._spawn_serial = 10
	var direction := Vector3.FORWARD.rotated(Vector3.UP, -0.10)
	var zombie = await launch(world, group, effects, Vector3(-37.5, 3.0, -33.5), direction, Zombie.DeathStrike.AIR)
	if zombie == null:
		return
	var worst_overlap := 0.0
	var worst_anchor := 0.0
	for frame in 80:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		worst_overlap = maxf(worst_overlap, terrain_contact_depth(zombie))
		worst_anchor = maxf(worst_anchor, zombie.ragdoll.max_anchor_error())
	check(zombie._corpse_landed, "The oblique cliff impact still reaches ground support")
	check(worst_overlap > 0.0 and worst_overlap < 0.12, "The oblique cliff contact stays within the terrain penetration budget")
	check(worst_anchor < 0.12, "The oblique cliff impact keeps the limb anchors connected")
	print("WORLDMAP_OBLIQUE_CLIFF peak_overlap_m=", worst_overlap, " peak_anchor_m=", worst_anchor)
	zombie.free()
	await ticks(2)

func shape_overlap(world: Node3D, shape: Shape3D, pose: Transform3D) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1
	query.shape = shape
	query.transform = pose
	var points := world.get_world_3d().direct_space_state.collide_shape(query, 16)
	var depth := 0.0
	for i in range(0, points.size(), 2):
		depth = maxf(depth, points[i].distance_to(points[i + 1]))
	return depth

func cliff_edge_case(world: Node3D, group: Node3D, effects: Node3D, seed: int, x: float,
		skew: float, yaw: float, strike: Zombie.DeathStrike, anchor_limit := 0.12) -> void:
	group._spawn_serial = seed
	var direction := Vector3.FORWARD.rotated(Vector3.UP, skew)
	var zombie = await launch(world, group, effects, Vector3(x, 3.0, -33.5), direction, strike, yaw)
	if zombie == null:
		return
	var peak_overlap := 0.0
	var peak_anchor := 0.0
	for frame in 120:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		peak_overlap = maxf(peak_overlap, terrain_contact_depth(zombie))
		peak_anchor = maxf(peak_anchor, zombie.ragdoll.max_anchor_error())
	check(zombie._corpse_landed and peak_anchor < anchor_limit,
		"Cliff-edge strike %d reaches ground with the source limb anchors connected" % seed)
	check(peak_overlap > 0.0 and peak_overlap < 0.12,
		"Cliff-edge strike %d stays within the contact depth budget" % seed)
	print("WORLDMAP_CLIFF_EDGE seed=", seed, " peak_overlap_m=", peak_overlap, " peak_anchor_m=", peak_anchor)
	zombie.free()
	await ticks(2)

func terrain_supported_rest(world: Node3D, group: Node3D, effects: Node3D, seed: int, start: Vector3,
		direction: Vector3, yaw: float, strike: Zombie.DeathStrike, expected_supports: int) -> void:
	group._spawn_serial = seed
	var zombie = await launch(world, group, effects, start, direction, strike, yaw)
	if zombie == null:
		return
	var skeleton: Skeleton3D = zombie.ragdoll.skeleton
	var last_simulated: Array[Transform3D] = []
	skeleton.skeleton_updated.connect(func() -> void:
		if not zombie.ragdoll.running:
			return
		last_simulated.clear()
		for bone in skeleton.get_bone_count():
			last_simulated.append(skeleton.get_bone_global_pose(bone)))
	var release_frame := -1
	var supports := 0
	for frame in 290:
		await physics_frame
		if zombie._corpse_parked:
			release_frame = frame
			break
		if zombie.ragdoll.running:
			supports = zombie.ragdoll.contact_motion().supports
	check(release_frame >= 170 and supports == expected_supports and zombie.ragdoll.bodies.is_empty(),
		"Terrain seed %d releases after the ragdoll settles on its terrain contacts" % seed)
	if zombie._corpse_parked:
		var pose_matches := last_simulated.size() == skeleton.get_bone_count()
		for bone in last_simulated.size():
			pose_matches = pose_matches and last_simulated[bone].is_equal_approx(skeleton.get_bone_global_pose(bone))
		check(pose_matches, "Terrain seed %d retains the final visible ragdoll pose" % seed)
	print("WORLDMAP_TERRAIN_REST seed=", seed, " release=", release_frame, " supports=", supports)
	zombie.free()
	await ticks(2)

func cliff_delayed_roll_case(world: Node3D, group: Node3D, effects: Node3D) -> void:
	group._spawn_serial = 68
	var zombie = await launch(world, group, effects, Vector3(-37.21, 3.0, -33.5),
		Vector3.FORWARD.rotated(Vector3.UP, 0.085), Zombie.DeathStrike.SABRE_FINISHER, 0.195)
	if zombie == null:
		return
	var leg_at_pause := Vector3.ZERO
	var leg_travel := 0.0
	for frame in 215:
		await physics_frame
		if zombie._corpse_parked:
			break
		if frame < 101 or not zombie.ragdoll.running:
			continue
		var leg: PhysicalBone3D = zombie.ragdoll.bodies["Leg.L"]
		if frame == 101:
			leg_at_pause = leg.global_position
		elif not leg_at_pause.is_zero_approx():
			leg_travel = maxf(leg_travel, leg.global_position.distance_to(leg_at_pause))
	check(leg_travel > 0.055, "A brief pause against a cliff leaves the later leg roll intact")
	print("WORLDMAP_DELAYED_ROLL leg_travel_m=", leg_travel)
	zombie.free()
	await ticks(2)

func braced_cliff_case(world: Node3D, group: Node3D, effects: Node3D) -> void:
	group._spawn_serial = 8
	var direction := Vector3.FORWARD.rotated(Vector3.UP, 0.17)
	var zombie = await launch(world, group, effects, Vector3(-37.28, 3.0, -33.5), direction,
		Zombie.DeathStrike.SABRE_FINISHER, 0.16)
	if zombie == null:
		return
	var first_landing := -1
	var parked_frame := -1
	var peak_overlap := 0.0
	var gravity_resumed := false
	var supported_gravity := false
	for frame in 240:
		await physics_frame
		if zombie._corpse_parked:
			parked_frame = frame
			break
		if not zombie.ragdoll.running:
			continue
		peak_overlap = maxf(peak_overlap, terrain_contact_depth(zombie))
		if not zombie._corpse_landed:
			continue
		if first_landing < 0:
			first_landing = frame
		var chest: PhysicalBone3D = zombie.ragdoll.bodies.Chest
		var gravity := PhysicsServer3D.body_get_direct_state(chest.get_rid()).total_gravity.y
		supported_gravity = supported_gravity or gravity > -20.0
		gravity_resumed = gravity_resumed or (supported_gravity and is_equal_approx(gravity, -50.0))
	check(first_landing >= 15 and first_landing <= 35 and peak_overlap < 0.12,
		"The braced cliff case keeps its initial landing and contact depth")
	check(gravity_resumed and parked_frame > first_landing,
		"The corpse tips from its wall brace under Overworld gravity and settles within four seconds")
	print("WORLDMAP_BRACED_CLIFF landing=", first_landing, " park=", parked_frame,
		" gravity_resumed=", gravity_resumed, " peak_overlap_m=", peak_overlap)
	zombie.free()
	await ticks(2)

func near_wall_handoff(world: Node3D, group: Node3D, effects: Node3D) -> void:
	if not group.spawn(world.player, Basis.IDENTITY, effects):
		check(false, "The verified zombie is available for the wall handoff")
		return
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(-33.5, 9.02, -39.545)
	zombie.rotation.y = 5.0 * PI / 4.0
	zombie.animation.play(Zombie.IDLE)
	zombie.animation.advance(0.40)
	zombie.reset_physics_interpolation()
	await ticks(2)
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	var capsule := zombie.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D
	check(shape_overlap(world, capsule.shape, capsule.global_transform) < 0.001,
		"The standing capsule clears the wall before the limb enters ragdoll physics")
	var arm: PhysicalBone3D = zombie.ragdoll.bodies["Arm.R"]
	var arm_shape := arm.get_child(0) as CollisionShape3D
	var captured_arm: Transform3D = zombie.ragdoll.current["Arm.R"]
	var before := shape_overlap(world, arm_shape.shape, captured_arm * arm_shape.transform)
	check(before > 0.08, "The idle arm collider overlaps the wall in the captured pose")
	zombie.take_hit(100, Vector3.RIGHT, Vector2.ZERO, 0.0, 800.0, Zombie.DeathStrike.GROUND)
	zombie._update_death(1.0 / 60.0)
	var after := shape_overlap(world, arm_shape.shape, arm_shape.global_transform)
	var shift := arm.global_position - captured_arm.origin
	check(after < 0.02 and absf(shift.y) < 0.001 and shift.length() <= 0.12,
		"The handoff reduces the arm overlap with a bounded horizontal shift")
	check(zombie.ragdoll.handoff_error < 0.005, "The wall handoff preserves the relative animated pose")
	zombie.set_physics_process(true)
	var peak := 0.0
	for i in 40:
		await physics_frame
		peak = maxf(peak, terrain_contact_depth(zombie))
	check(zombie._corpse_landed and peak < 0.045, "The cleared pose launches and reaches the lower terrace")
	print("WORLDMAP_HANDOFF before=", before, " after=", after, " peak_overlap_m=", peak, " shift=", shift)
	zombie.free()
	await ticks(2)

func check_supported_breakup(world: Node3D, group: Node3D, effects: Node3D) -> void:
	group._spawn_serial = 5
	var zombie = await launch(world, group, effects, Vector3(-33.5, 9.0, -39.5), Vector3.RIGHT)
	if zombie == null:
		return
	while zombie._corpse_age < 4.40:
		await physics_frame
	var mesh: MeshInstance3D = zombie._mesh
	check(is_zero_approx(float(mesh.get_instance_shader_parameter("fragment_travel"))),
		"The terrace corpse does not separate before its breakup window")
	while zombie._corpse_age < 4.73:
		await physics_frame
	check(zombie._corpse_landed and zombie.ragdoll.running and zombie.ragdoll.contact_motion().supports > 0,
		"The terrace fixture still has an active, supported ragdoll during breakup")
	var directions: Variant = mesh.material_override.get_shader_parameter("fragment_directions")
	check(float(mesh.get_instance_shader_parameter("fragment_travel")) > 0.0
		and directions is PackedVector3Array and directions.size() == mesh.skin.get_bind_count(),
		"An active, supported corpse separates using its evaluated pose")
	await ticks(20)
	check(not is_instance_valid(zombie), "The supported breakup still despawns at five seconds")

func run() -> void:
	var world = preload("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(12)
	check(world.map_ready, "The real WorldMap collision geometry loads")
	if world.map_ready:
		var group := Zombies.new()
		var effects := Node3D.new()
		world.add_child(effects)
		world.add_child(group)
		await cliff_case(world, group, effects)
		await ledge_case(world, group, effects, Zombie.DeathStrike.SABRE_FINISHER, 72)
		await ledge_case(world, group, effects, Zombie.DeathStrike.SABRE_FINISHER, 72)
		# Curved Greatsword and Sword use the same forward ground death response.
		await ledge_case(world, group, effects, Zombie.DeathStrike.GROUND, 200)
		# Reproduce the first spawn's tumble variant, whose head and feet rest at different heights.
		group._spawn_serial = 0
		await ledge_case(world, group, effects, Zombie.DeathStrike.GROUND, 200)
		# Offset the launch toward the next cell so the head and arm strike at an angle.
		group._spawn_serial = 2
		await ledge_case(world, group, effects, Zombie.DeathStrike.SABRE_FINISHER, 190,
			Vector3(-33.5, 9.0, -39.15), Vector3.RIGHT.rotated(Vector3.UP, -0.10))
		# A different airborne tumble catches the left arm after the head hits the lower terrace.
		group._spawn_serial = 7
		await ledge_case(world, group, effects, Zombie.DeathStrike.AIR, 190,
			Vector3(-33.5, 9.0, -39.5), Vector3.RIGHT.rotated(Vector3.UP, 0.10))
		# The spinning head can still travel into a floor or an edge after the first bounce.
		group._spawn_serial = 5
		await ledge_case(world, group, effects, Zombie.DeathStrike.SABRE_FINISHER, 190, Vector3(-33.5, 9.0, -39.15))
		group._spawn_serial = 10
		await ledge_case(world, group, effects, Zombie.DeathStrike.AIR, 190,
			Vector3(-33.5, 9.0, -39.5), Vector3.RIGHT.rotated(Vector3.UP, -0.10))
		# The right arm brushes the lower terrace while its anchor pulls away from it.
		group._spawn_serial = 3
		await ledge_case(world, group, effects, Zombie.DeathStrike.GROUND, 200,
			Vector3(-33.5, 9.0, -39.5), Vector3.RIGHT.rotated(Vector3.UP, 0.055), 0.16)
		# The left arm reaches the next step a tick before the solver reports it.
		group._spawn_serial = 43
		await ledge_case(world, group, effects, Zombie.DeathStrike.AIR, 190,
			Vector3(-33.5, 9.0, -39.35), Vector3.RIGHT.rotated(Vector3.UP, 0.21), -0.065, 0.22)
		group._spawn_serial = 11
		await ledge_case(world, group, effects, Zombie.DeathStrike.SABRE_FINISHER, 180,
			Vector3(-33.5, 9.0, -39.28), Vector3.RIGHT.rotated(Vector3.UP, -0.18))
		# A faster Sabre throw crosses the slanted edge within one physics tick.
		group._spawn_serial = 8
		await ledge_case(world, group, effects, Zombie.DeathStrike.SABRE_FINISHER, 125,
			Vector3(-33.5, 9.0, -39.14), Vector3.RIGHT.rotated(Vector3.UP, -0.18), 0.0, 0.12, 1.20)
		await oblique_cliff_case(world, group, effects)
		await cliff_edge_case(world, group, effects, 10, -37.39, -0.18, -0.08, Zombie.DeathStrike.AIR)
		# A glancing right arm can cross the front triangle before the side reports contact.
		await cliff_edge_case(world, group, effects, 30, -37.5, 0.055, -0.08, Zombie.DeathStrike.GROUND)
		await cliff_edge_case(world, group, effects, 57, -37.46, 0.085, -0.065, Zombie.DeathStrike.GROUND)
		# The corrected pose leaves a shallow wall contact before the limb slows.
		await cliff_edge_case(world, group, effects, 51, -37.46, 0.21, 0.0, Zombie.DeathStrike.GROUND, 0.055)
		await near_wall_handoff(world, group, effects)
		await braced_cliff_case(world, group, effects)
		await terrain_supported_rest(world, group, effects, 28, Vector3(-33.5, 9.0, -39.39),
			Vector3.RIGHT.rotated(Vector3.UP, -0.18), 0.16, Zombie.DeathStrike.AIR, 2)
		await terrain_supported_rest(world, group, effects, 63, Vector3(-33.5, 9.0, -39.46),
			Vector3.RIGHT.rotated(Vector3.UP, -0.13), -0.13, Zombie.DeathStrike.GROUND, 2)
		await terrain_supported_rest(world, group, effects, 21, Vector3(-37.5, 3.0, -33.5),
			Vector3.FORWARD.rotated(Vector3.UP, 0.055), 0.0, Zombie.DeathStrike.GROUND, 4)
		await terrain_supported_rest(world, group, effects, 48, Vector3(-37.46, 3.0, -33.5),
			Vector3.FORWARD.rotated(Vector3.UP, 0.085), -0.195, Zombie.DeathStrike.GROUND, 4)
		await cliff_delayed_roll_case(world, group, effects)
		await check_supported_breakup(world, group, effects)
	world.free()
	print("WORLD_MAP_MECHANIC_RAGDOLL failures=", failures)
	quit(0 if failures.is_empty() else 1)
