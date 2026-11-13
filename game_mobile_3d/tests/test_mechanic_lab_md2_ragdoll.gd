
extends SceneTree

const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var lab = load("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group = lab.get_node("Zombies")
	check(group.damage_digits().size() == 10 and group._visual != null and group.get_child_count() == 0,
		"Lab startup prepares the verified zombie model and digits before the first spawn")
	lab.get_node("HUD/BaseZombieToggle").button_pressed = true
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "Verified MD2 zombie spawns")
		quit(1)
		return
	var zombie = group.get_child(0)
	check(zombie.ragdoll.bodies.size() == 6 and not zombie.ragdoll.bodies.has("Hips"),
		"Verified SK_Zombie asset supplies six rigid bodies without a hip collider")
	check(zombie.ragdoll.bodies.Chest.get("bone_name") == "J_Spine" and zombie.ragdoll.bodies.Head.get("bone_name") == "J_Neck",
		"Physics bodies bind to the asset's spine and neck bones")
	var head_box := zombie.ragdoll.bodies.Head.get_child(0).shape as BoxShape3D
	check(head_box.size.is_equal_approx(Vector3(0.5, 0.5, 0.5)), "Neck collider uses the source box dimensions")
	var head: PhysicalBone3D = zombie.ragdoll.bodies.Head
	var arm: PhysicalBone3D = zombie.ragdoll.bodies["Arm.L"]
	# The verified 50 cm cube has 8/3 the volume of the 25 x 75 x 25 cm arm box.
	check(is_equal_approx(head.mass / arm.mass, pow(8.0 / 3.0, 0.75)),
		"MD2's physical material scales the mass ratio between the neck and arm")
	var strengths := [399.0, 400.0, 750.0, 1200.0]
	for i in range(1, strengths.size()):
		check(ZOMBIE._death_launch_speed(strengths[i]) > ZOMBIE._death_launch_speed(strengths[i - 1]),
			"Source strength threshold changes the launch tier")
	check(ZOMBIE._death_launch_speed(800.0) > ZOMBIE._death_launch_speed(500.0) * 1.25,
		"Sabre's final strike adds at least 25 percent launch speed for the same pose")
	var seed_before: int = zombie._death_rng.seed
	var twirls := 0
	var left_twirls := 0
	for i in 300:
		zombie._death_rng.seed = hash(Vector2i(i, 1709))
		var spin: Vector3 = zombie._death_spin(Vector3.FORWARD)
		if not is_zero_approx(spin.y):
			twirls += 1
			left_twirls += int(spin.y < 0.0)
	zombie._death_rng.seed = seed_before
	check(twirls >= 70 and twirls <= 130 and left_twirls > 0 and left_twirls < twirls,
		"Seeded death variants produce occasional twirls in both directions")
	await ticks(56)
	var attack := InputEventKey.new()
	attack.physical_keycode = KEY_E
	attack.pressed = true
	root.push_input(attack, true)
	await ticks(2)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	root.push_input(release, true)
	for i in 60:
		if zombie.health == 0:
			break
		await physics_frame
	await ticks(4)
	check(zombie.ragdoll.running and zombie.health == 0, "Lethal contact transfers the live pose to physics")
	var head_state := PhysicsServer3D.body_get_direct_state(zombie.ragdoll.bodies.Head.get_rid())
	check(head_state and is_equal_approx(head_state.total_gravity.y, -50.0),
		"Grounded hits use 50 m/s² of downward gravity in flight")
	check(is_equal_approx(zombie.ragdoll.bodies.Head.linear_damp, 0.01),
		"The ragdoll uses the authored air drag during launch")
	var impulse: Vector3 = zombie.ragdoll.total_applied_impulse
	check(absf(rad_to_deg(atan2(impulse.y, Vector2(impulse.x, impulse.z).length())) - 30.0) < 0.01,
		"DefaultHostile's 30-degree launch is applied to the death impulse")
	check(zombie.ragdoll.handoff_error < 0.005, "No snap at physics handoff")
	var joints: Dictionary = zombie.ragdoll.source_joint_rids.duplicate()
	check(joints.size() == 5, "All five authored joints become native Godot constraints")
	for child: String in joints:
		var joint: RID = joints[child]
		var spec: Dictionary = zombie.ragdoll.source_joints[child]
		check(spec.parent == "Chest", child + " connects to the spine body")
		check(is_equal_approx(PhysicsServer3D.cone_twist_joint_get_param(joint, PhysicsServer3D.CONE_TWIST_JOINT_SWING_SPAN), deg_to_rad(45.0))
			and is_equal_approx(PhysicsServer3D.cone_twist_joint_get_param(joint, PhysicsServer3D.CONE_TWIST_JOINT_TWIST_SPAN), deg_to_rad(15.0)),
			child + " uses the asset's cone and twist spans")
	var launch_mass := 0.0
	for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
		launch_mass += body.mass
	check(is_equal_approx(launch_mass, 60.0), "The relative source masses use the lab's total mass")
	check(Vector2(impulse.x, impulse.z).length() / launch_mass > 8.0,
		"A normal lethal strike adds over 8 m/s along the floor")
	var skeleton: Skeleton3D = zombie.ragdoll.skeleton
	var last_physical_pose: Array[Transform3D] = []
	skeleton.skeleton_updated.connect(func():
		if not zombie.ragdoll.running:
			return
		last_physical_pose.clear()
		for bone in skeleton.get_bone_count():
			last_physical_pose.append(skeleton.get_bone_global_pose(bone)))
	var fastest_descent := 0.0
	var landing_time := INF
	var landing_speed := 0.0
	var follow_through_speed := -INF
	var lowest_corner := 0.0
	var last_anchor_error := INF
	for i in 60:
		await physics_frame
		if not zombie.ragdoll.running:
			break
		lowest_corner = minf(lowest_corner, zombie.ragdoll.minimum_corner_y())
		last_anchor_error = zombie.ragdoll.max_anchor_error()
		var momentum := Vector3.ZERO
		for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
			momentum += body.linear_velocity * body.mass
		var velocity := momentum / launch_mass
		if zombie._corpse_landed:
			if landing_time == INF:
				landing_time = zombie._corpse_age
				landing_speed = velocity.dot(zombie._death_direction)
			elif follow_through_speed == -INF and zombie._corpse_age - landing_time >= 0.10 - 0.0001:
				follow_through_speed = velocity.dot(zombie._death_direction)
			continue
		fastest_descent = maxf(fastest_descent, -velocity.y)
	check(fastest_descent > 5.0, "The corpse falls faster than 5 m/s before head or chest contact")
	check(landing_time > 0.38 and landing_time < 0.55, "A grounded Sabre strike brings the torso down within 550 ms")
	check(landing_speed > 0.0 and follow_through_speed > landing_speed * 0.55,
		"The corpse retains forward momentum through its first 100 ms on the floor")
	check(lowest_corner >= -0.013, "The grounded strike stays within the floor contact tolerance")
	check(zombie._corpse_landed and last_anchor_error < 0.10, "The corpse settles with connected joints")
	while zombie.ragdoll.running and zombie._corpse_age < 1.85:
		await physics_frame
	check(not zombie.ragdoll.running, "A supported corpse holds still before the fade instead of vibrating on the floor")
	var resting_pose: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		resting_pose.append(skeleton.get_bone_global_pose(bone))
	await ticks(18)
	var held_still := true
	for bone in skeleton.get_bone_count():
		held_still = held_still and skeleton.get_bone_global_pose(bone).is_equal_approx(resting_pose[bone])
	check(held_still, "The parked corpse holds every bone still across later physics frames")
	while zombie._corpse_age < 2.95:
		await physics_frame
	var mid_fade: float = zombie._mesh.get_instance_shader_parameter("desaturation")
	check(absf(mid_fade - 0.4) < 0.02, "The corpse progresses through the existing color fade")
	while zombie._corpse_age < 3.60:
		await physics_frame
	var final_fade: float = zombie._mesh.get_instance_shader_parameter("desaturation")
	check(is_equal_approx(final_fade, 0.8), "The corpse reaches 80 percent desaturation")
	# A sentinel detects subsequent renderer writes of the same completed value.
	zombie._mesh.set_instance_shader_parameter("desaturation", 0.79)
	await ticks(2)
	var held_fade: float = zombie._mesh.get_instance_shader_parameter("desaturation")
	check(is_equal_approx(held_fade, 0.79), "The completed fade stops submitting shader updates")
	zombie._mesh.set_instance_shader_parameter("desaturation", final_fade)
	while is_instance_valid(zombie) and zombie._corpse_age < 4.96:
		await physics_frame
	check(is_instance_valid(zombie), "Corpse remains until the table's five-second lifespan")
	if is_instance_valid(zombie):
		check(not zombie.ragdoll.running and zombie.ragdoll.bodies.is_empty() and zombie.ragdoll.source_joint_rids.is_empty(),
			"A grounded, settled corpse releases its physics bodies and joints before despawn")
		var travel: Variant = zombie._mesh.get_instance_shader_parameter("fragment_travel")
		var dissolve: Variant = zombie._mesh.get_instance_shader_parameter("dissolve")
		check(zombie._mesh.is_visible_in_tree() and (travel == null or is_zero_approx(float(travel)))
			and (dissolve == null or is_zero_approx(float(dissolve))),
			"The settled corpse stays whole and solid until cleanup")
		var pose_preserved := last_physical_pose.size() == skeleton.get_bone_count()
		for bone in last_physical_pose.size():
			pose_preserved = pose_preserved and skeleton.get_bone_global_pose(bone).is_equal_approx(last_physical_pose[bone])
		check(pose_preserved, "Releasing physics retains the last rendered pose, including utility bones")
	await ticks(6)
	check(not is_instance_valid(zombie), "The intact corpse is released at the end of its lifetime")
	for slot in 3:
		await check_combo_finisher(lab, group, slot)
	await check_sabre_landing_reversal(lab, group)
	await check_sabre_landing_reversal(lab, group, true)
	await check_sabre_first_contact_anchors(lab, group)
	await check_sabre_supported_floor_lift(lab, group)
	await check_sabre_head_and_arm_brace(lab, group)
	await check_sabre_late_roll(lab, group)
	await check_flat_rest_after_tumble(lab, group)
	await check_sabre_fixed_pose_anchor(lab, group, 415, 0.10, "arm rebound")
	await check_sabre_fixed_pose_anchor(lab, group, 419, 0.101, "head impact at the start of the roll")
	await check_sabre_fixed_pose_anchor(lab, group, 652, 0.095, "leg contact after the landing blend")
	await check_flat_contact_jitter(lab, group, 246, 0.28, 0.91, 800.0, 2.2)
	await check_flat_contact_jitter(lab, group, 264, 0.2, 0.66, 1265.0, 2.9)
	await check_fresh_spawn_handoff(lab, group, 0)
	await check_fresh_spawn_handoff(lab, group, 1)
	await check_spawn_dive_handoff(lab, group)
	await check_moving_pose_history(lab, group)
	print("MECHANIC_LAB_MD2_RAGDOLL ", JSON.stringify({"checks": checks, "failures": failures}))
	lab.free()
	quit(0 if failures.is_empty() else 1)

func check_moving_pose_history(lab, group) -> void:
	lab.reset_player()
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie := group.get_child(0) as ZOMBIE
	zombie.global_position = Vector3(0.0, 0.02, 9.0)
	for i in 150:
		await process_frame
		if zombie.animation.current_animation in ZOMBIE.WALK_CLIPS and zombie.get_real_velocity().length() > 1.0:
			break
	var ragdoll := zombie.ragdoll
	var previous := ragdoll.previous
	var current := ragdoll.current
	var saved := current.duplicate()
	await process_frame
	check(is_same(previous, ragdoll.current) and is_same(current, ragdoll.previous),
		"Consecutive pose samples reuse the same pair of buffers")
	var skeleton_pose := ragdoll.skeleton.global_transform
	var transforms_match := true
	var expected_velocity: Dictionary[String, Vector3] = {}
	for name: String in ragdoll.bodies:
		var body: PhysicalBone3D = ragdoll.bodies[name]
		var current_pose := skeleton_pose * ragdoll.skeleton.get_bone_global_pose(body.get_bone_id()) * body.body_offset
		var prior_pose: Transform3D = saved[name]
		transforms_match = (transforms_match and ragdoll.previous[name].is_equal_approx(prior_pose)
			and ragdoll.current[name].is_equal_approx(current_pose))
		expected_velocity[name] = ((current_pose.origin - prior_pose.origin) / ragdoll.sample_delta).limit_length(
			ragdoll.maximum_inherited_linear_speed)
	check(transforms_match, "Both snapshots retain the evaluated world poses of all six bodies")
	zombie.take_hit(100, Vector3.RIGHT)
	await process_frame
	var launch_matches := ragdoll.running and ragdoll.handoff_error < 0.005
	for name in expected_velocity:
		var inherited: Dictionary = ragdoll.inherited.get(name, {})
		launch_matches = (launch_matches and inherited.get("linear", Vector3.INF).is_equal_approx(expected_velocity[name]))
	check(launch_matches and expected_velocity.get("Chest", Vector3.ZERO).length() > 1.0,
		"The first death tick inherits the actual moving pose without snapping")
	zombie.free()

func check_fresh_spawn_handoff(lab, group, living_ticks: int) -> void:
	lab.reset_player()
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	# The physics_frame signal runs before the zombie's physics callback.
	for i in living_ticks:
		await process_frame
	check(zombie.ragdoll.sample_count == living_ticks, "The fresh-spawn fixture has the expected pose history")
	zombie.take_hit(100, Vector3.RIGHT)
	await process_frame
	var inherited_motion := false
	for sample: Dictionary in zombie.ragdoll.inherited.values():
		inherited_motion = inherited_motion or not sample.linear.is_zero_approx() or not sample.angular.is_zero_approx()
	check(zombie.ragdoll.running and zombie._corpse_age <= 1.0 / 60.0 + 0.00001
		and zombie.ragdoll.handoff_error < 0.0001 and not inherited_motion
		and zombie.ragdoll.total_applied_impulse.x > 0.0,
		"A lethal hit with %d prior samples launches on the first death tick from its current pose" % living_ticks)
	print("FRESH_ZOMBIE_HANDOFF samples=", living_ticks, " active=", zombie.ragdoll.running,
		" age=", zombie._corpse_age, " pose_gap_m=", zombie.ragdoll.handoff_error)
	zombie.free()

func check_spawn_dive_handoff(lab, group) -> void:
	lab.reset_player()
	await ticks(8)
	var selector := lab.get_node("HUD/Weapon") as OptionButton
	selector.select(0)
	selector.item_selected.emit(0)
	check(selector.selected == 0 and lab.player.drop_for_lab(5.0), "Fresh spawn fixture starts a Sabre dive")
	await ticks(2)
	var touchdown: Array[int] = []
	var landed := func(_point, _facing, _serial, _height): touchdown.append(Engine.get_physics_frames())
	lab.player.heavy_jump_landed.connect(landed)
	lab.player.attack(true)
	await ticks(1)
	lab.player.attack(false)
	for i in 60:
		await physics_frame
		if not touchdown.is_empty():
			break
	lab.player.heavy_jump_landed.disconnect(landed)
	check(touchdown.size() == 1, "The real dive touches down once before spawning the target")
	if touchdown.is_empty():
		return
	group._spawn_serial = 5
	lab.get_node("HUD/BaseZombieToggle").button_pressed = true
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	for i in 12:
		await physics_frame
		if zombie.ragdoll.running:
			break
	check(zombie.health == 0 and zombie.ragdoll.running, "Sabre kills the zombie during its spawn clip")
	var gap := 0.0
	var first_support := INF
	for i in 40:
		await physics_frame
		gap = maxf(gap, zombie.ragdoll.max_anchor_error())
		if zombie._corpse_landed and first_support == INF:
			first_support = zombie._corpse_age
	check(gap < 0.10 and first_support > 0.20 and is_finite(first_support),
		"The fresh corpse launches with connected joints before its first landing")
	print("SPAWN_DIVE_HANDOFF peak_gap_m=", gap, " landing_s=", first_support)
	zombie.free()

func check_combo_finisher(lab, group, slot: int) -> void:
	lab.reset_player()
	var selector := lab.get_node("HUD/Weapon") as OptionButton
	selector.select(slot)
	selector.item_selected.emit(slot)
	lab.get_node("HUD/BaseZombieToggle").button_pressed = false
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	var lethal_clips: Array[String] = []
	var record_lethal := func(_point, _direction, clip, _index, _serial, lethal):
		if lethal:
			lethal_clips.append(clip)
	group.sabre_contact.connect(record_lethal)
	await ticks(56)
	var attack := InputEventKey.new()
	attack.physical_keycode = KEY_E
	attack.pressed = true
	root.push_input(attack, true)
	for i in 130:
		if zombie.health == 0:
			break
		await physics_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	root.push_input(release, true)
	group.sabre_contact.disconnect(record_lethal)
	var weapon: String = ["Sabre", "Sword", "Curved Greatsword"][slot]
	var expected_clip: String = ["NativeFinisher", "Attack3", "NativeCurvedAttack3"][slot]
	check(lethal_clips == [expected_clip],
		weapon + "'s third strike produces a lethal ragdoll")
	var landing_time := INF
	var lowest_corner := 0.0
	var vertical_axis := INF
	var lower_contact_time := INF
	var flight_gravity := 0.0
	for i in 70:
		await physics_frame
		if zombie._corpse_parked:
			break
		if zombie.ragdoll.running:
			lowest_corner = minf(lowest_corner, zombie.ragdoll.minimum_corner_y())
			if not zombie._corpse_landed:
				var head: PhysicalBone3D = zombie.ragdoll.bodies.Head
				var state := PhysicsServer3D.body_get_direct_state(head.get_rid())
				if state != null:
					flight_gravity = state.total_gravity.y
		if not zombie._corpse_landed:
			continue
		landing_time = minf(landing_time, zombie._corpse_age)
		if slot == 1 and zombie._corpse_age - landing_time >= ZOMBIE.DEATH_LANDING_BLEND_TIME - 0.00001:
			# Rebound from the landed state while the bodies are still simulated.
			break
		if slot != 0:
			continue
		var since_contact: float = zombie._corpse_age - landing_time
		var bodies: Dictionary = zombie.ragdoll.bodies
		for part in ["Chest", "Leg.L", "Leg.R"]:
			var state := PhysicsServer3D.body_get_direct_state(bodies[part].get_rid())
			if state and state.get_contact_count() > 0:
				lower_contact_time = minf(lower_contact_time, since_contact)
		if vertical_axis == INF and since_contact >= 0.30 - 0.0001:
			var feet: Vector3 = (bodies["Leg.L"].global_position + bodies["Leg.R"].global_position) * 0.5
			var head_to_legs: Vector3 = bodies.Head.global_position - feet
			vertical_axis = absf(head_to_legs.normalized().y)
	check(landing_time > 0.25 and landing_time < 0.50, weapon + "'s finisher makes prompt core contact")
	check(lowest_corner >= -0.013, weapon + "'s finisher stays within the floor contact tolerance")
	if slot == 0:
		check(vertical_axis < 0.34, "Sabre's finisher rolls out of its inverted pose within 300 ms")
		check(lower_contact_time < 0.40, "Sabre's chest or legs reach the floor within 400 ms of head contact")
		while zombie.ragdoll.running and zombie._corpse_age < 1.35 - 0.00001:
			await physics_frame
		check(zombie._corpse_parked, "Sabre's finisher releases the fully supported corpse within 1.35 seconds")
	elif slot == 1:
		await check_rebound(zombie)
	else:
		check(is_equal_approx(flight_gravity, -50.0), "Curved Greatsword uses the Overworld flight gravity")
	zombie.free()

func check_rebound(zombie) -> void:
	# Give every body the same upward speed to test re-entry into free flight.
	for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
		body.apply_central_impulse(Vector3.UP * body.mass * 6.0)
	var free_flight := false
	for i in 24:
		await physics_frame
		if zombie.ragdoll.minimum_corner_y() <= 0.025:
			continue
		var head: PhysicalBone3D = zombie.ragdoll.bodies.Head
		var state := PhysicsServer3D.body_get_direct_state(head.get_rid())
		if state and is_equal_approx(state.total_gravity.y, -50.0) and is_equal_approx(head.linear_damp, 0.01) \
				and is_equal_approx(head.angular_damp, zombie._death_profile.angular_damping):
			free_flight = true
			break
	check(free_flight, "A corpse that rebounds clear of the floor returns to air gravity and drag")

func check_sabre_landing_reversal(lab, group, offset_spawn := false) -> void:
	lab.reset_player()
	var selector := lab.get_node("HUD/Weapon") as OptionButton
	selector.select(0)
	selector.item_selected.emit(0)
	lab.get_node("HUD/BaseZombieToggle").button_pressed = false
	group._spawn_serial = 7 if offset_spawn else 5
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	if offset_spawn:
		zombie.global_position += Vector3(-0.30, 0.0, 0.13)
		zombie.reset_physics_interpolation()
	await ticks(68 if offset_spawn else 56)
	var attack := InputEventKey.new()
	attack.physical_keycode = KEY_E
	attack.pressed = true
	root.push_input(attack, true)
	for i in 140:
		if zombie.health == 0:
			break
		await physics_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	root.push_input(release, true)
	var previous_height: Dictionary[String, float]
	var previous_step: Dictionary[String, float]
	var peak_reversal := 0.0
	var peak_supported_reversal := 0.0
	var previous_damping := 0.0
	var peak_damping_step := 0.0
	var reached_low_pose := false
	var first_contact := INF
	var previous_mean_height := INF
	var previous_mean_step := 0.0
	var whole_body_reversals := 0
	var peak_whole_body_reversal := 0.0
	var previous_center_height := 0.0
	var peak_supported_rise := 0.0
	for i in 120:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		var motion: Dictionary = zombie.ragdoll.contact_motion()
		if motion.supports > 0:
			first_contact = minf(first_contact, zombie._corpse_age)
		var was_low := reached_low_pose
		if zombie._corpse_landed and motion.supports > 0 and zombie.ragdoll.minimum_corner_y() <= 0.015 \
				and absf(zombie._corpse_axis().normalized().y) <= 0.25:
			reached_low_pose = true
		var damping: float = zombie.ragdoll.bodies.Head.angular_damp
		if previous_damping >= ZOMBIE.DEATH_LANDING_ANGULAR_DAMP and damping >= previous_damping:
			peak_damping_step = maxf(peak_damping_step, damping - previous_damping)
		previous_damping = damping
		var mean_height := 0.0
		var weighted_height := 0.0
		var total_mass := 0.0
		for name: String in zombie.ragdoll.bodies:
			var body: PhysicalBone3D = zombie.ragdoll.bodies[name]
			var height := body.global_position.y
			var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
			weighted_height += (height + state.center_of_mass.y) * body.mass
			total_mass += body.mass
			mean_height += height
			if previous_height.has(name):
				var step := height - previous_height[name]
				var prior := previous_step.get(name, 0.0) as float
				if reached_low_pose and step * prior < 0.0:
					var reversal := absf(step - prior) * 0.5
					peak_reversal = maxf(peak_reversal, reversal)
					if was_low:
						peak_supported_reversal = maxf(peak_supported_reversal, reversal)
				previous_step[name] = step
			previous_height[name] = height
		var center_height := weighted_height / total_mass
		if was_low:
			peak_supported_rise = maxf(peak_supported_rise, center_height - previous_center_height)
		previous_center_height = center_height
		mean_height /= zombie.ragdoll.bodies.size()
		if previous_mean_height < INF:
			var mean_step := mean_height - previous_mean_height
			var since_contact: float = zombie._corpse_age - first_contact
			if first_contact < INF and since_contact <= 0.55 and mean_step * previous_mean_step < 0.0:
				var reversal := absf(mean_step - previous_mean_step) * 0.5
				peak_whole_body_reversal = maxf(peak_whole_body_reversal, reversal)
				if reversal > 0.02:
					whole_body_reversals += 1
			previous_mean_step = mean_step
		previous_mean_height = mean_height
	if not offset_spawn:
		check(reached_low_pose and peak_supported_rise < 0.040,
			"Sabre's grounded finisher keeps upward center-of-mass steps below 4 cm after the low pose")
		check(reached_low_pose and peak_reversal < 0.075 and peak_supported_reversal < 0.065,
			"Sabre's grounded finisher avoids large alternating vertical steps after contact")
		check(zombie._corpse_parked and zombie._corpse_age <= 1.25 and peak_damping_step > 0.0 and peak_damping_step < 1.40,
			"Sabre's low roll settles with a gradual increase in angular damping")
	check(reached_low_pose and whole_body_reversals <= 4 and peak_whole_body_reversal < 0.05,
		"Sabre's finisher lands without repeatedly lifting the entire corpse (offset=%s)" % offset_spawn)
	print("SABRE_LANDING_REVERSAL offset=", offset_spawn, " entry_m=", peak_reversal,
		" supported_m=", peak_supported_reversal, " peak_damping_step=", peak_damping_step,
		" whole_body_reversals=", whole_body_reversals, " peak_whole_body_m=", peak_whole_body_reversal,
		" upward_step_m=", peak_supported_rise, " age=", zombie._corpse_age)
	zombie.free()

func check_sabre_first_contact_anchors(lab, group) -> void:
	var zombie = await replay_offset_sabre_finisher(lab, group, 415)
	var peak_gap := 0.0
	for i in 48:
		await physics_frame
		if zombie._corpse_landed:
			break
		if zombie.ragdoll.running:
			peak_gap = maxf(peak_gap, zombie.ragdoll.max_anchor_error())
	check(zombie._corpse_landed and peak_gap < 0.094,
		"Sabre first-contact floor recovery keeps the joint gap below 9.4 cm")
	print("SABRE_FIRST_CONTACT peak_gap_m=", peak_gap)
	zombie.free()

func replay_offset_sabre_finisher(lab, group, spawn_serial: int):
	lab.reset_player()
	var selector := lab.get_node("HUD/Weapon") as OptionButton
	selector.select(0)
	selector.item_selected.emit(0)
	lab.get_node("HUD/BaseZombieToggle").button_pressed = false
	group._spawn_serial = spawn_serial
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 120011 + spawn_serial
	zombie.global_position += Vector3(rng.randf_range(-0.42, 0.42), 0.0, rng.randf_range(-0.37, 0.35))
	zombie.reset_physics_interpolation()
	await ticks(rng.randi_range(44, 69))
	var attack := InputEventKey.new()
	attack.physical_keycode = KEY_E
	attack.pressed = true
	root.push_input(attack, true)
	for i in 140:
		if zombie.health == 0:
			break
		await physics_frame
	attack.pressed = false
	root.push_input(attack, true)
	return zombie

func check_sabre_supported_floor_lift(lab, group) -> void:
	var zombie = await replay_offset_sabre_finisher(lab, group, 505)
	var previous_y := 0.0
	var low_pose := false
	var peak_rise := 0.0
	var overlap := 0.0
	for i in 90:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		var weighted_y := 0.0
		var mass := 0.0
		for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
			weighted_y += body.global_position.y * body.mass
			mass += body.mass
		var centre_y := weighted_y / mass
		if low_pose:
			peak_rise = maxf(peak_rise, centre_y - previous_y)
		elif zombie._corpse_landed and absf(zombie._corpse_axis().normalized().y) <= 0.25 \
				and zombie.ragdoll.contact_motion().supports > 0:
			low_pose = true
		previous_y = centre_y
		overlap = maxf(overlap, -zombie.ragdoll.minimum_corner_y())
	check(low_pose and peak_rise < 0.022 and overlap <= 0.013 and zombie._corpse_parked,
		"The low Sabre roll avoids a sharp upward correction without pushing the limbs through the floor")
	print("SABRE_SUPPORTED_FLOOR_LIFT rise_m=", peak_rise, " overlap_m=", overlap, " release_s=", zombie._corpse_age)
	zombie.free()

func check_sabre_head_and_arm_brace(lab, group) -> void:
	var zombie = await replay_offset_sabre_finisher(lab, group, 464)
	var braced := false
	var leg_supported_after_brace := false
	for i in 130:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		var contact: Dictionary = zombie.ragdoll.contact_motion()
		if zombie._corpse_age >= 0.82 and contact.supports == 2 and contact.core_supports == 1 and not contact.leg_supported:
			braced = true
		if braced and contact.leg_supported:
			leg_supported_after_brace = true
	check(braced and leg_supported_after_brace and zombie._corpse_parked,
		"Sabre's head-and-arm brace rolls onto leg support and releases within 130 ticks")
	print("SABRE_HEAD_ARM_REST seconds=", zombie._corpse_age,
		" braced=", braced, " leg_supported_after_brace=", leg_supported_after_brace)
	zombie.free()

func check_sabre_late_roll(lab, group) -> void:
	var zombie = await replay_offset_sabre_finisher(lab, group, 424)
	var peak_damping := 0.0
	var first_support_damping := -1.0
	var overlap := 0.0
	for i in 120:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		var contact: Dictionary = zombie.ragdoll.contact_motion()
		var chest: PhysicalBone3D = zombie.ragdoll.bodies.Chest
		if first_support_damping < 0.0 and contact.supports > 0:
			first_support_damping = chest.angular_damp
		peak_damping = maxf(peak_damping, chest.angular_damp)
		overlap = maxf(overlap, -zombie.ragdoll.minimum_corner_y())
	check(first_support_damping >= 0.0 and first_support_damping <= 4.0,
		"The late roll adds no angular damping at the first impact")
	check(peak_damping > 12.0 and zombie._corpse_parked and zombie._corpse_age < 1.15 and overlap <= 0.018,
		"The supported Sabre roll slows and releases without extra floor penetration")
	print("SABRE_LATE_ROLL first_damp=", first_support_damping, " peak_damp=", peak_damping,
		" release_s=", zombie._corpse_age, " overlap_m=", overlap)
	zombie.free()

func check_flat_rest_after_tumble(lab, group) -> void:
	group._spawn_serial = 35
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(2.0, 0.02, 0.0)
	zombie.rotation.y = 35 * 0.41
	zombie.animation.play(ZOMBIE.ATTACK)
	zombie.animation.advance(0.18)
	zombie.reset_physics_interpolation()
	await ticks(2)
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, Vector3.RIGHT.rotated(Vector3.UP, 0.66), Vector2.ZERO, 0.0, 1150.0, ZOMBIE.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)
	while not zombie._corpse_parked and zombie._corpse_age < 1.85:
		await physics_frame
	check(zombie._corpse_parked and zombie.ragdoll.bodies.is_empty(),
		"The flat-floor tumble stops vibrating and releases its rigid bodies within 1.85 seconds")
	zombie.free()

func check_sabre_fixed_pose_anchor(lab, group, serial: int, gap_limit: float, impact: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 120011 + serial
	group._spawn_serial = serial
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(2.0, 0.02, 0.0)
	zombie.rotation.y = rng.randf_range(0.0, TAU)
	zombie.animation.play(ZOMBIE.ATTACK)
	zombie.animation.advance(rng.randf_range(0.05, 0.3))
	zombie.reset_physics_interpolation()
	await ticks(4)
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	var direction := Vector3.RIGHT.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
	zombie.take_hit(100, direction, Vector2.ZERO, 0.0, 1150.0, ZOMBIE.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)
	var peak := 0.0
	while not zombie._corpse_parked and zombie._corpse_age < 1.55:
		await physics_frame
		if zombie.ragdoll.running:
			peak = maxf(peak, zombie.ragdoll.max_anchor_error())
	check(peak > 0.0 and peak < gap_limit and zombie._corpse_parked,
		"Fixed-pose Sabre %s keeps the joint connected and settles" % impact)
	print("SABRE_FIXED_IMPACT serial=", serial, " peak_gap_m=", peak, " release_s=", zombie._corpse_age)
	zombie.free()

func check_flat_contact_jitter(lab, group, serial: int, pose_time: float, direction_angle: float,
		strength: float, settle_deadline: float) -> void:
	group._spawn_serial = serial
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = Vector3(2.0, 0.02, 0.0)
	zombie.rotation.y = fmod(serial * 0.41, TAU)
	zombie.animation.play(ZOMBIE.IDLE)
	zombie.animation.advance(pose_time)
	zombie.reset_physics_interpolation()
	await ticks(2)
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, Vector3.RIGHT.rotated(Vector3.UP, direction_angle), Vector2.ZERO, 0.0, strength)
	zombie.set_physics_process(true)
	var lowest_corner := 0.0
	while not zombie._corpse_parked and zombie._corpse_age < settle_deadline:
		await physics_frame
		if zombie.ragdoll.running:
			lowest_corner = minf(lowest_corner, zombie.ragdoll.minimum_corner_y())
	check(zombie._corpse_parked, "Flat-floor corpse %d stops shaking within %.1f seconds" % [serial, settle_deadline])
	check(lowest_corner >= -0.013, "The corpse stays within the floor contact tolerance while settling")
	print("RAGDOLL_FLAT_CONTACT_REST serial=", serial, " seconds=", zombie._corpse_age, " peak_overlap_m=", -lowest_corner)
	zombie.free()

