
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
	check(Vector2(impulse.x, impulse.z).length() / launch_mass > 8.0,
		"A normal lethal strike adds over 8 m/s along the floor")
	var fastest_descent := 0.0
	var landing_time := INF
	var landing_speed := 0.0
	var follow_through_speed := -INF
	for i in 60:
		await physics_frame
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
	check(zombie._corpse_landed and zombie.ragdoll.max_anchor_error() < 0.10, "The corpse settles with connected joints")
	var skeleton: Skeleton3D = zombie.ragdoll.skeleton
	var last_physical_pose: Array[Transform3D] = []
	skeleton.skeleton_updated.connect(func():
		if not zombie.ragdoll.running:
			return
		last_physical_pose.clear()
		for bone in skeleton.get_bone_count():
			last_physical_pose.append(skeleton.get_bone_global_pose(bone)))
	while is_instance_valid(zombie) and zombie._corpse_age < 4.96:
		await physics_frame
	check(is_instance_valid(zombie), "Corpse remains until the table's five-second lifespan")
	if is_instance_valid(zombie):
		check(not zombie.ragdoll.running and zombie.ragdoll.bodies.is_empty() and zombie.ragdoll.source_joint_rids.is_empty(),
			"A grounded, settled corpse releases its physics bodies and joints before despawn")
		var dissolve: float = zombie._mesh.get_instance_shader_parameter("dissolve")
		check(zombie._mesh.is_visible_in_tree() and dissolve > 0.0 and dissolve < 1.0,
			"The retained corpse mesh still dissolves after physics is released")
		var pose_preserved := last_physical_pose.size() == skeleton.get_bone_count()
		for bone in last_physical_pose.size():
			pose_preserved = pose_preserved and skeleton.get_bone_global_pose(bone).is_equal_approx(last_physical_pose[bone])
		check(pose_preserved, "Releasing physics retains the last rendered pose, including utility bones")
	await ticks(6)
	check(not is_instance_valid(zombie), "Corpse is released after its breakup")
	await check_combo_finisher(lab, group, false)
	await check_combo_finisher(lab, group, true)
	print("MECHANIC_LAB_MD2_RAGDOLL ", JSON.stringify({"checks": checks, "failures": failures}))
	lab.free()
	quit(0 if failures.is_empty() else 1)

func check_combo_finisher(lab, group, sword: bool) -> void:
	lab.reset_player()
	lab._select_weapon(1 if sword else 0)
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
	var weapon := "Sword" if sword else "Sabre"
	var expected_clip := "Attack3" if sword else "NativeFinisher"
	check(group.sword_equipped == sword and lethal_clips == [expected_clip],
		weapon + "'s third strike produces a lethal ragdoll")
	var landing_time := INF
	var lowest_corner := 0.0
	var vertical_axis := INF
	var lower_contact_time := INF
	for i in 70:
		await physics_frame
		if zombie.ragdoll.running:
			lowest_corner = minf(lowest_corner, zombie.ragdoll.minimum_corner_y())
		if not zombie._corpse_landed:
			continue
		landing_time = minf(landing_time, zombie._corpse_age)
		if sword:
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
	check(landing_time > 0.25 and landing_time < 0.57, weapon + "'s finisher makes prompt core contact")
	check(lowest_corner > -0.17, weapon + "'s finisher avoids deep floor overlap")
	if not sword:
		check(vertical_axis < 0.34, "Sabre's finisher rolls out of its inverted pose within 300 ms")
		check(lower_contact_time < 0.40, "Sabre's chest or legs reach the floor within 400 ms of head contact")
	zombie.free()

