extends SceneTree
var failures: Array[String] = []
var results: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://scenes/dev/ZombieDeathPhysicsLab.tscn").instantiate()
	root.add_child(lab)
	lab.corpse_lifetime = 35.0
	for setting in [[120,0.0],[120,1.0],[60,2.5],[120,2.5]]:
		var gain: float = setting[1]
		Engine.physics_ticks_per_second = int(setting[0])
		lab.reset_zombie()
		var z = lab.actor
		z.set_physics_process(false)
		z.player.pause()
		z.position.y = 3.0
		z.ragdoll.sample(1.0/120.0)
		z.ragdoll.sample(1.0/120.0)
		var p: Resource = lab.pistol_profile.duplicate(true)
		p.linear_impulse = 0.0
		p.upward_impulse = 0.0
		p.angular_impulse = 0.0
		p.joint_resistance = gain
		z.dead = true
		z.ragdoll.begin(p,Vector3.FORWARD,"Chest",1.5,0.0)
		var arm: PhysicalBone3D = z.ragdoll.bodies["Arm.L"]
		var chest: PhysicalBone3D = z.ragdoll.bodies.Chest
		var axis: Vector3 = arm.global_basis.y
		arm.angular_velocity = axis * 0.8
		for i in roundi(Engine.physics_ticks_per_second*.1): await physics_frame
		await process_frame
		var relative := absf((arm.angular_velocity-chest.angular_velocity).dot(axis))
		var momentum := Vector3.ZERO
		for body in z.ragdoll.bodies.values(): momentum += body.linear_velocity * body.mass
		if momentum.length() > 0.01: failures.append("Internal resistance must not kick COM")
		results.append({"hz":Engine.physics_ticks_per_second,"gain":gain,"relative_angular_speed":relative,"linear_momentum":str(momentum)})
		if relative > .7 and gain>0: failures.append("Resistance must remain stable at exposed rate/gain")
		for i in ceili(Engine.physics_ticks_per_second*2.2): await physics_frame
		if z.ragdoll.is_physics_processing(): failures.append("Resistance must stop so corpse can sleep")
	if results[1].relative_angular_speed >= results[0].relative_angular_speed * .7:
		failures.append("Resistance must suppress relative flailing without locking limbs")
	var output := {"results":results,"failures":failures}
	var path := OS.get_environment("ZOMBIE_LAB_RESULTS")
	if not path.is_empty(): FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("JOINT_RESISTANCE ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
