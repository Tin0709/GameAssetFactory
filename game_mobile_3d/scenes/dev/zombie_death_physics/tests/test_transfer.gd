extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var lab = load("res://scenes/dev/ZombieDeathPhysicsLab.tscn").instantiate()
	root.add_child(lab)
	var actor = lab.actor
	actor.set_physics_process(false)
	actor.player.pause()
	actor.model.position = Vector3(0.03, 0, 0.137)
	actor.position = Vector3(3, 0, 2)
	actor.rotation.y = 0.6
	var dt := 1.0 / 60.0
	var travel := Vector3(1.2, 0.4, -0.7)
	var spin := Vector3(0, 0.4, 0)
	actor.ragdoll.sample(dt)
	actor.position += travel * dt
	actor.rotation.y += spin.y * dt
	actor.ragdoll.sample(dt)
	var captured: Dictionary = actor.ragdoll.current.duplicate()
	var zero: Resource = lab.pistol_profile.duplicate(true)
	zero.linear_impulse = 0.0
	zero.angular_impulse = 0.0
	zero.upward_impulse = 0.0
	actor.dead = true
	actor.ragdoll.begin(zero, Vector3.FORWARD, "Chest", 1.5, 9.8)
	for name in actor.ragdoll.bodies:
		var body: PhysicalBone3D = actor.ragdoll.bodies[name]
		var expected: Transform3D = captured[name]
		check(body.global_position.distance_to(expected.origin) < 0.00001, "Translated/rotated root position continuity")
		check(body.global_basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion()) < 0.001, "Full body orientation continuity")
		var expected_linear := travel + spin.cross(expected.origin - actor.global_position)
		check(body.linear_velocity.distance_to(expected_linear) < 0.004, "Whole-world center velocity once, including root spin")
		check(body.angular_velocity.distance_to(spin) < 0.001, "Whole-world angular velocity continuity")
	check(actor.model.position.is_equal_approx(Vector3(0.03,0,0.137)), "Model offset survives transfer")
	# Same total shotgun J at every spread; spread redistributes shoulder-edge hits.
	var distributions: Array[Dictionary] = []
	for radius in [0.0, 0.11, 0.25]:
		lab.reset_zombie()
		actor = lab.actor
		actor.set_physics_process(false)
		actor.player.pause()
		actor.ragdoll.sample(dt)
		actor.ragdoll.sample(dt)
		var profile: Resource = lab.shotgun_profile.duplicate(true)
		profile.pattern_radius = radius
		profile.angular_impulse = 0.0
		actor.dead = true
		actor.ragdoll.begin(profile, Vector3.FORWARD, "Right shoulder", 1.5, 9.8)
		var sum := Vector3.ZERO
		for impulse in actor.ragdoll.impact_distribution.values(): sum += impulse
		check(sum.distance_to(Vector3(0,10,-86)) < 0.0001, "Pellet total momentum conserved")
		distributions.append(actor.ragdoll.impact_distribution.duplicate())
	check(distributions[0] != distributions[2], "Spread changes which physical parts receive impulse")
	print("TRANSFER_TESTS ", JSON.stringify({"failures": failures, "shotgun_distributions": distributions}))
	quit(0 if failures.is_empty() else 1)
