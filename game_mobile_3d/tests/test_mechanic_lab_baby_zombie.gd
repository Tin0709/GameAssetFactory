extends SceneTree

enum Strike { SABRE, SABRE_FINISHER, AIR, SWORD }
enum DeathPose { MD2, AS_FLAT, AS_CORNER }

const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func run() -> void:
	# Start this corner replay with a prewarmed rig, as in the live Lab.
	await check_tuned_contact(9, 13.0, 0.80, Strike.AIR, -44.0, Vector2(1000.0, 100.0), true)
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	var group: Node = lab.get_node("Zombies")
	group.set_actions_stuff_animation(false) # The phase assertions below measure MD2's original clips.
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
	var step_phases: Array[float] = []
	baby.melee_hit.connect(func(amount: int): hits.append(amount))
	baby.step_audio.connect(func(_point: Vector3):
		step_phases.append(baby.animation.current_animation_position))
	var peak_speed := 0.0
	for i in 180:
		await physics_frame
		peak_speed = maxf(peak_speed, baby.get_real_velocity().slide(Vector3.UP).length())
		if not hits.is_empty():
			break
	check(peak_speed > 8.45 and peak_speed < 8.55 and not step_phases.is_empty()
		and hits == [5] and lab.player_health == 95, "The baby chases at 8.5 m/s and applies its own five-HP hit")
	var peak_step_error := 0.0
	for i in step_phases.size():
		var authored: Vector3 = Zombie.BABY_STEP_CONTACTS[i % Zombie.BABY_STEP_CONTACTS.size()]
		peak_step_error = maxf(peak_step_error, absf(step_phases[i] - authored.x))
	check(step_phases.size() >= 2 and peak_step_error <= 0.000001,
		"The Baby Zombie emits once per authored planted-foot phase without an extra tick")
	print("LAB_BABY_STEP_PHASES phases=", step_phases, " max_error_s=", peak_step_error)
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
	await check_spawn_during_prewarm()
	await check_exit_during_prewarm()
	await check_tuned_contact(26)
	await check_tuned_contact(13, 0.0, 0.90)
	await check_tuned_contact(25, 27.0, 1.00)
	await check_tuned_contact(50, 27.0, 1.00)
	await check_tuned_contact(58, 27.0, 0.35, Strike.AIR)
	await check_tuned_contact(73, 27.0, 0.18, Strike.SABRE, -58.0)
	await check_tuned_contact(81, 27.0, 0.35, Strike.AIR, -58.0)
	await check_tuned_contact(19, 27.0, 0.35, Strike.SWORD, -58.0)
	await check_tuned_contact(60, 27.0, 0.20, Strike.SABRE, -58.0, Vector2(100.0, 100.0))
	await check_tuned_contact(58, 13.0, 0.18, Strike.AIR, -44.0, Vector2(100.0, 100.0))
	# The first head contact can separate several joints on the next two physics ticks.
	await check_tuned_contact(78, 27.0, 0.25, Strike.SWORD, -58.0, Vector2(1000.0, 100.0))
	await check_tuned_contact(88, 27.0, 0.35, Strike.SABRE_FINISHER, -58.0, Vector2(1000.0, 100.0))
	# Preserve the launch-only response when the initial neck gap is already large.
	await check_tuned_contact(17, 27.0, 0.32, Strike.SABRE_FINISHER, -58.0, Vector2(1000.0, 100.0))
	await check_first_wall_neck_contact()
	await check_first_wall_neck_contact(true)
	await check_floor_then_wall()
	# A free leg near the ground needs to recover from a sideways gap
	# even when its full anchor correction would point into the grass.
	await check_tuned_contact(3, 27.0, 0.12, Strike.SABRE_FINISHER, -58.0,
		Vector2(100.0, 100.0), true, DeathPose.AS_FLAT)
	await check_tuned_contact(35, 27.0, 0.20, Strike.AIR, -58.0, Vector2(100.0, 100.0), true, DeathPose.AS_FLAT)
	# Launch alone can pin a foot against the floor and a side of the corner.
	await check_tuned_contact(2, 27.0, 0.30, Strike.SABRE, -58.0, Vector2(1000.0, 100.0), true)
	# An A&S stride can hit two sides before the head or a foot reaches a wall.
	await check_tuned_contact(25, 27.0, 0.37, Strike.SABRE, -58.0,
		Vector2(1000.0, 100.0), true, DeathPose.AS_CORNER)
	# A collider can overlap a wall one step before a contact is reported.
	await check_tuned_contact(20, 0.0, 0.32, Strike.SWORD, -90.0, Vector2(1000.0, 100.0), true)
	await check_tuned_contact(4, 13.0, 0.37, Strike.SABRE_FINISHER, -44.0,
		Vector2(1000.0, 100.0), true, DeathPose.AS_CORNER)
	# The overlap can also start after the floor sweep predicts the wall.
	await check_tuned_contact(31, 13.0, 0.37, Strike.SWORD, -44.0,
		Vector2(1000.0, 100.0), true, DeathPose.AS_CORNER)
	print("LAB_BABY_ZOMBIE speed=", peak_speed, " damage=", hits, " steps=", step_phases.size(),
		" joint_gap=", peak_gap, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_prewarmed_spawn() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group: Node = lab.get_node("Zombies")
	check(group.get("_baby_visual") == null, "Opening the Lab does not import the baby rig synchronously")
	var last_pending := 0
	var partial_frames := 0
	for frame in 24:
		await process_frame
		if group.get("_baby_visual") != null:
			break
		var pending: Variant = group.get("_baby_bake_steps")
		if pending is Array and not pending.is_empty():
			if last_pending > 0:
				check(last_pending - pending.size() <= 1, "Baby prewarm bakes at most one step per render frame")
			last_pending = pending.size()
			partial_frames += 1
	check(partial_frames > 1, "Baby prewarm spreads the animation bake over multiple render frames")
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

func check_spawn_during_prewarm() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group: Node = lab.get_node("Zombies")
	var staged: Node3D
	for frame in 24:
		await process_frame
		staged = group.get("_baby_build_model") as Node3D
		if staged != null:
			break
	check(staged != null and group.get("_baby_visual") == null,
		"A detached Baby Zombie rig is available during prewarm")
	var button := lab.get_node("HUD/SpawnBabyZombie") as Button
	button.pressed.emit()
	var packed := group.get("_baby_visual") as PackedScene
	check(group.get_child_count() == 1 and packed != null and not is_instance_valid(staged),
		"An early press completes the in-progress rig and spawns exactly one Baby Zombie")
	await process_frame
	await process_frame
	check(group.get_child_count() == 1 and group.get("_baby_visual") == packed,
		"Resuming prewarm does not rebuild the completed rig or spawn an extra zombie")
	lab.free()

func check_exit_during_prewarm() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group: Node = lab.get_node("Zombies")
	var staged: Node3D
	for frame in 24:
		await process_frame
		staged = group.get("_baby_build_model") as Node3D
		if staged != null:
			break
	check(staged != null, "The exit fixture reaches a suspended Baby Zombie bake")
	lab.free()
	await process_frame
	check(not is_instance_valid(staged), "Closing the Lab frees the detached rig before prewarm resumes")

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

func check_tuned_contact(seed: int, wall_yaw := INF, gap_limit := 0.20, strike_kind := Strike.SABRE,
		strike_yaw := INF, tuning := Vector2(1000.0, 1000.0), prewarm := false, death_pose := DeathPose.MD2) -> void:
	var launch_percent := tuning.x
	var gravity_percent := tuning.y
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	if prewarm:
		for frame in 10:
			await process_frame
	lab.get_node("HUD/RagdollTuning/Launch/Slider").value = launch_percent
	lab.get_node("HUD/RagdollTuning/Gravity/Slider").value = gravity_percent
	var corner: Node3D
	if death_pose == DeathPose.AS_FLAT:
		corner = Node3D.new()
		corner.rotation.y = deg_to_rad(wall_yaw)
		lab.add_child(corner)
	elif wall_yaw != INF:
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
	if death_pose != DeathPose.MD2:
		clips = [Zombie.ActionsStuff.IDLE, Zombie.ActionsStuff.MOVE, Zombie.ActionsStuff.ATTACK]
	var clip: StringName = clips[seed % clips.size()]
	baby.animation.play(clip)
	baby.animation.advance(0.0)
	var clip_length := baby.animation.get_animation(clip).length
	if death_pose == DeathPose.AS_CORNER and clip == Zombie.ActionsStuff.MOVE:
		clip_length = minf(Zombie.ActionsStuff.STRIDE_SECONDS, clip_length)
	baby.animation.seek(clip_length * (seed % 10) * 0.1, true)
	await physics_frame
	for sample in 2:
		baby.ragdoll.sample(1.0 / 60.0)
	var direction := Vector3(0.91, 0.0, -0.22).normalized()
	if strike_yaw != INF:
		var angle := deg_to_rad(strike_yaw)
		direction = Vector3(cos(angle), 0.0, sin(angle))
	var origin := baby.global_position if corner == null else baby.global_position - direction
	var air_attack := strike_kind == Strike.AIR
	var finisher := strike_kind == Strike.SABRE_FINISHER
	var attack := "AirAttack" if air_attack else "Attack"
	var combo_index := 2 if finisher else 0
	group.sword_equipped = strike_kind == Strike.SWORD
	var strike: Dictionary = group.AIR_STRIKE if air_attack else group.SABRE_STRIKES[combo_index]
	if group.sword_equipped:
		strike = group.SWORD_STRIKES[0]
	group._apply_contact(baby, baby.combat_center(), attack, combo_index, seed, strike, direction, false, origin)
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
		if corner != null and death_pose != DeathPose.AS_FLAT:
			for part: PhysicalBone3D in baby.ragdoll.bodies.values():
				var local := corner.to_local(part.global_position)
				crossed = crossed or (local.y > 0.0 and local.y < 7.9 and (local.x > 6.13 or local.z < 0.07))
		if impulse == 0.0:
			impulse = baby.ragdoll.total_applied_impulse.length()
			var chest: PhysicalBone3D = baby.ragdoll.bodies.Chest
			gravity = PhysicsServer3D.body_get_direct_state(chest.get_rid()).total_gravity.y
	var expected_impulse := (125.664 if air_attack or finisher else 98.736) * launch_percent / 100.0
	check(baby.health == 0 and is_equal_approx(impulse, expected_impulse)
		and is_equal_approx(gravity, -50.0 * gravity_percent / 100.0),
		"The Baby Zombie receives the selected launch and gravity settings from the lethal contact")
	check(gap < gap_limit and baby._corpse_landed and baby._corpse_parked and not crossed,
		"At %d%% launch and %d%% gravity the Baby Zombie settles with limited joint stretch and no wall crossings"
		% [launch_percent, gravity_percent])
	print("LAB_BABY_TUNED_CONTACT launch=", launch_percent, " gravity_slider=", gravity_percent, " seed=", seed, " yaw=", wall_yaw, " strike_yaw=", strike_yaw, " gap=", gap, " crossed=", crossed,
		" parked=", baby._corpse_parked, " impulse=", impulse, " gravity=", gravity, " death_pose=", death_pose)
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


func check_floor_then_wall() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.get_node("HUD/RagdollTuning/Launch/Slider").value = 1000.0
	var corner := add_contact_corner(lab, 45.0)
	var group: Node = lab.get_node("Zombies")
	lab.get_node("HUD/SpawnBabyZombie").pressed.emit()
	var baby := group.get_child(0) as Zombie
	baby.set_physics_process(false)
	await physics_frame
	baby.take_hit(100, Vector3.RIGHT)
	baby._update_death(1.0 / 60.0)
	var leg: PhysicalBone3D = baby.ragdoll.bodies["Leg.L"]
	# Consecutive leg centres from the Sabre finisher at 1000% launch.
	var start := Vector3(4.429976, 0.077577, -3.713356)
	var finish := Vector3(4.632934, -0.086941, -3.824733)
	var local_velocity := Vector3(12.0, -9.0, 3.0)
	var velocity := corner.basis * local_velocity
	baby.ragdoll._tuned_wall_poses.clear()
	baby.ragdoll._tuned_wall_poses["Leg.L"] = start
	var state := PhysicsServer3D.body_get_direct_state(leg.get_rid())
	state.transform = Transform3D(state.transform.basis, finish)
	state.linear_velocity = velocity
	baby.ragdoll._sweep_tuned_lab_walls()
	var stopped := corner.to_local(state.transform.origin)
	var slide := corner.basis.inverse() * state.linear_velocity
	check(stopped.x < 5.875 and absf(stopped.z - corner.to_local(finish).z) < 0.001,
		"The leg stays on the near side of the wall when its sweep hits the floor first")
	check(slide.is_equal_approx(Vector3(0.0, local_velocity.y, local_velocity.z)),
		"The floor-to-wall contact cancels only the velocity into the wall")

	# The same path passes beneath a raised obstacle.
	var wall := corner.get_child(0) as StaticBody3D
	wall.position.y += 0.2
	await physics_frame
	await physics_frame
	state = PhysicsServer3D.body_get_direct_state(leg.get_rid())
	state.transform = Transform3D(state.transform.basis, finish)
	state.linear_velocity = velocity
	baby.ragdoll._sweep_tuned_lab_walls()
	check(state.transform.origin.is_equal_approx(finish) and state.linear_velocity.is_equal_approx(velocity),
		"The floor continuation leaves a path under a raised wall unobstructed")

	# The floor is finite. It cannot redirect a limb that travels off the edge.
	var edge_offset := Vector3(50.01 - finish.x, 0.0, 0.0)
	wall.position.y -= 0.2
	corner.position += edge_offset
	await physics_frame
	await physics_frame
	state = PhysicsServer3D.body_get_direct_state(leg.get_rid())
	baby.ragdoll._tuned_wall_poses["Leg.L"] = start + edge_offset
	state.transform = Transform3D(state.transform.basis, finish + edge_offset)
	baby.ragdoll._sweep_tuned_lab_walls()
	check(state.transform.origin.is_equal_approx(finish + edge_offset),
		"The floor continuation does not extend the platform past its edge")
	print("LAB_BABY_FLOOR_WALL near_side=", stopped.x, " slide=", slide)
	lab.free()


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
