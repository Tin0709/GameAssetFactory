extends SceneTree
var failures: Array[String] = []
var results: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func center(z: Node3D) -> Vector3:
	var value := Vector3.ZERO
	var mass := 0.0
	for b in z.ragdoll.bodies.values():
		value += b.global_position * b.mass
		mass += b.mass
	return value / mass
func run() -> void:
	var lab = load("res://scenes/dev/ZombieDeathPhysicsLab.tscn").instantiate()
	root.add_child(lab)
	lab.corpse_lifetime = 35.0
	lab.active_physics_duration = 35.0
	for weapon in 3:
		lab.weapon_choice.select(weapon)
		lab._load_profile(weapon)
		lab.reset_zombie()
		await ticks(24)
		var z = lab.actor
		var origin: Vector3 = center(z) if z.dead else z.global_position + Vector3(0,1,0)
		lab.trigger_death()
		await ticks(2)
		for pair in [["Chest", 8.0], ["Head", 18.0], ["Arm.L", 50.0], ["Leg.L", 30.0]]:
			check(float(z.ragdoll.bodies[pair[0]].get("joint_constraints/y/angular_limit_upper")) <= pair[1], "Controlled articulation: " + pair[0])
		var initial_speed := Vector3.ZERO
		for b in z.ragdoll.bodies.values(): initial_speed += b.linear_velocity * b.mass / 60.0
		var peak_anchor := 0.0
		var minimum_y := 0.0
		var maximum_travel := 0.0
		for i in 600:
			await physics_frame
			peak_anchor = maxf(peak_anchor, z.ragdoll.max_anchor_error())
			minimum_y = minf(minimum_y,z.ragdoll.minimum_corner_y())
			var delta: Vector3 = center(z)-origin
			maximum_travel = maxf(maximum_travel,Vector2(delta.x,delta.z).length())
		check(initial_speed.dot(Vector3.FORWARD) > [2.2,4.5,8.0][weapon], "Decisive whole-body launch speed / weapon %d: %.2f" % [weapon,initial_speed.dot(Vector3.FORWARD)])
		check(maximum_travel > [1.0,3.0,6.0][weapon], "Visible throw distance / weapon %d: %.2f" % [weapon,maximum_travel])
		check(peak_anchor < 0.06,"Joints remain attached during fast launch: %.3f" % peak_anchor)
		check(minimum_y > (-.075 if weapon == 2 else -.05),"Fast ground contact: %.3f" % minimum_y)
		check(z.ragdoll.minimum_corner_y() > -.03,"Settled ground support")
		results.append({"weapon":weapon,"initial_velocity":str(initial_speed),"maximum_horizontal_travel_m":maximum_travel,"peak_anchor_m":peak_anchor,"minimum_corner_y":minimum_y})
	var output := {"failures":failures,"results":results}
	var path := OS.get_environment("ZOMBIE_LAB_RESULTS")
	if not path.is_empty(): FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("WEIGHTED_LAUNCH ", JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
