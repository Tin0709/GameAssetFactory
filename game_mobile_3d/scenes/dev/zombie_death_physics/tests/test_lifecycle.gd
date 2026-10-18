extends SceneTree
var failures: Array[String] = []
var observations: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func tick(seconds: float) -> void:
	for i in ceili(seconds * Engine.physics_ticks_per_second): await physics_frame
	await process_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var lab = load("res://scenes/dev/ZombieDeathPhysicsLab.tscn").instantiate()
	root.add_child(lab)
	check(is_equal_approx(lab.corpse_lifetime,1.2),"Default total death lifetime must be 1.2 s")
	if lab.get("active_physics_duration") == null:
		print("LIFECYCLE_FAIL missing separate physics budget")
		quit(1)
		return
	# Real default timing from all three states/weapons, including an airborne
	# shoulder impact. Measure simulated hit-to-removal time, not wall time.
	for state in 3:
		for weapon in 3:
			lab.animation_choice.select(state)
			lab.weapon_choice.select(weapon)
			lab._load_profile(weapon)
			lab.reset_zombie()
			await tick(.2)
			var subject = lab.actor
			var saw_fade := false
			lab.trigger_death()
			for frame in 260:
				await tick(1.0/120.0)
				if lab.actor == null: break
				if subject.fade_started>=0 and not saw_fade:
					saw_fade = true
					var core_contact := false
					for name in ["Hips","Chest","Head"]:
						var body: PhysicalBone3D = subject.ragdoll.bodies.get(name)
						if body:
							var direct := PhysicsServer3D.body_get_direct_state(body.get_rid())
							core_contact = core_contact or (direct != null and direct.get_contact_count()>0)
					check(core_contact or subject.corpse_parked or subject.age>=1.7,"Protect torso landing, not only first boot contact")
			check(lab.actor==null,"Default cleanup completes for state/weapon")
			check(subject.age>=1.18 and subject.age<=1.86,"Death lifetime includes fade and respects extension cap")
			observations.append({"state":state,"weapon":weapon,"cleanup_simulated_seconds":subject.age})
	lab.animation_choice.select(0)
	lab.weapon_choice.select(0)
	lab._load_profile(0)
	lab.reset_zombie()
	# Standard death: keep physics through impact; tear down everything on cleanup.
	await tick(.2)
	var z = lab.actor
	var old_bodies: Array = z.ragdoll.bodies.values()
	lab.trigger_death()
	await tick(.5)
	check(z.dead and z.ragdoll.running,"Full ragdoll survives meaningful first impact")
	await tick(1.4)
	check(lab.zombies.is_empty(),"Default death cleaned by bounded airborne extension")
	for body in old_bodies: check(not is_instance_valid(body),"Cleanup frees physical bodies and joints")
	check(lab.corpse_pool.size() == 1,"Model-only pool retains one reusable visual")
	check(not z.visible and not z.is_physics_processing(),"Pooled corpse invisible and idle")
	# Airborne: expiry of requested physics duration must never freeze it in air.
	lab.reset_zombie()
	check(lab.actor == z,"Respawn actually reuses pooled actor")
	lab.actor.position.y = 4.0
	lab.corpse_lifetime = .3
	lab.active_physics_duration = .1
	lab.airborne_extension = .5
	await tick(.1)
	lab.trigger_death()
	await tick(.45)
	check(lab.actor != null and lab.actor.ragdoll.running,"Airborne extension keeps simulation active")
	check(not lab.actor.corpse_parked,"No midair parked pose")
	await tick(.5)
	check(lab.zombies.is_empty(),"Airborne cleanup has a hard bounded deadline")
	# Longer visual review with short active budget may park ONLY after settling.
	lab.corpse_lifetime = 5.0
	lab.active_physics_duration = .2
	lab.reset_zombie()
	lab.controls.linear.value = 0
	lab.controls.up.value = 0
	lab.controls.angular.value = 0
	await tick(.2)
	lab.trigger_death()
	var parked = lab.actor
	var before_park: Dictionary = {}
	for i in 600:
		if parked.corpse_parked: break
		for name in parked.ragdoll.bodies:
			var body: PhysicalBone3D = parked.ragdoll.bodies[name]
			before_park[name] = body.global_transform * body.body_offset.affine_inverse()
		await tick(1.0/120.0)
	await tick(.04)
	for name in before_park:
		var held: Transform3D = parked.visible_pose[parked.skeleton.find_bone(name)]
		check(held.origin.distance_to(before_park[name].origin)<.025,"Park transition preserves fallen world position: "+name)
		check(held.basis.get_rotation_quaternion().angle_to(before_park[name].basis.get_rotation_quaternion())<.05,"Park transition preserves fallen world angle: "+name)
	check(parked.corpse_parked,"Grounded settled corpse releases early physics budget")
	check(parked.ragdoll.bodies.is_empty(),"Park removes all bodies rather than sleeping them")
	var pose: Array = parked.visible_pose.duplicate()
	await tick(.15)
	for i in pose.size():
		check(pose[i].origin.distance_to(parked.visible_pose[i].origin)<.0002,"Parked mesh holds captured position")
		check(pose[i].basis.get_rotation_quaternion().angle_to(parked.visible_pose[i].basis.get_rotation_quaternion())<.002,"Parked mesh holds captured angle")
	# Repeated pool reuse: no stale pose, velocity, fade, offsets, or queued lethal hit.
	for attempt in 12:
		lab.reset_zombie()
		var fresh = lab.actor
		await tick(.04)
		check(not fresh.dead and fresh.age == 0 and not fresh.corpse_parked,"Pool reset clears death state")
		check(fresh.ragdoll.bodies.size()==7 and fresh.ragdoll.anchors.is_empty(),"Pool reset rebuilds a clean joint graph")
		check(fresh.model.position.is_zero_approx(),"Pool reset clears model lunge")
		check(absf(fresh.player.current_animation_position-fresh.elapsed)<.01,"Pool reset restarts clip phase")
		for body in fresh.ragdoll.bodies.values():
			check(body.linear_velocity.is_zero_approx() and body.angular_velocity.is_zero_approx(),"Pool reset clears physics velocity")
		lab.trigger_death()
		await tick(.04)
		check(fresh.dead and fresh.ragdoll.handoff_error<.0001,"Reused model hands off without snap")
	lab.reset_zombie()
	lab.pool_corpses = false
	var unpooled = lab.actor
	lab.reset_zombie()
	await tick(.04)
	check(not is_instance_valid(unpooled),"Free mode retains no retired model")
	lab.pool_corpses = true
	lab.corpse_lifetime = 1.2
	lab.active_physics_duration = 1.2
	lab.airborne_extension = .6
	lab.maximum_active_ragdolls = 4
	lab.stress_test()
	await tick(.65)
	check(lab.zombies.size()==4,"Simultaneous death count stays capped")
	await tick(2.0)
	check(lab.zombies.is_empty(),"Whole stress wave cleans up")
	for pooled in lab.corpse_pool: check(pooled.ragdoll.bodies.is_empty(),"No pooled physics/collisions retained")
	check(lab.corpse_pool.size()<=4,"Pool is bounded by cap")
	var output := {"failures":failures,"observations":observations}
	var path := OS.get_environment("ZOMBIE_LAB_RESULTS")
	if not path.is_empty(): FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("LIFECYCLE ",JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
