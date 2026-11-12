
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
	for i in 60:
		await physics_frame
		if zombie._corpse_landed:
			landing_time = minf(landing_time, zombie._corpse_age)
			continue
		var vertical_momentum := 0.0
		for body: PhysicalBone3D in zombie.ragdoll.bodies.values():
			vertical_momentum += body.linear_velocity.y * body.mass
		fastest_descent = maxf(fastest_descent, -vertical_momentum / launch_mass)
	check(fastest_descent > 5.0, "The corpse falls faster than 5 m/s before head or chest contact")
	check(landing_time > 0.40 and landing_time < 0.64, "The torso reaches the floor in the calibrated window")
	check(zombie._corpse_landed and zombie.ragdoll.max_anchor_error() < 0.10, "The corpse settles with connected joints")
	while is_instance_valid(zombie) and zombie._corpse_age < 4.96:
		await physics_frame
	check(is_instance_valid(zombie), "Corpse remains until the table's five-second lifespan")
	await ticks(6)
	check(not is_instance_valid(zombie), "Corpse is released after its breakup")
	print("MECHANIC_LAB_MD2_RAGDOLL ", JSON.stringify({"checks": checks, "failures": failures}))
	lab.free()
	quit(0 if failures.is_empty() else 1)

