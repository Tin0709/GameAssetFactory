extends SceneTree
## Actual scene, actual swept rifle projectiles and native Lab death bodies.
var failures: Array[String] = []
var report := {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message);push_error(message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func run() -> void:
	var scene = load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	# Preserve this original manual-barrel damage/handoff regression. Automatic
	# target selection/turning/projectile kills have their own end-to-end suite.
	scene.auto_aim_enabled=false
	root.add_child(scene)
	var combat = scene.get("zombie_combat")
	check(combat != null,"Existing research scene contains zombie combat")
	if combat == null: scene.free();quit(1);return
	var hz := Engine.physics_ticks_per_second
	scene.player.scripted_input = true
	await ticks(15)
	check(combat.zombies.size() == 4,"Small fixed group of four zombies")
	check(combat.zombies[0].visual.get("source_library")!=null,"Requested Mobs A&S Idle/Walk/Attack library is active")
	for i in combat.zombies.size():
		var z = combat.zombies[i]
		check(absf(z.position.y)<.02,"Living capsules remain grounded without dormant-body self collision")
		z.target = null;z.move_speed = 0.0
		z.position = Vector3(20+i*3,0,20);z.velocity=Vector3.ZERO
	var z = combat.zombies[0]
	var aim := InputEventKey.new();aim.keycode=KEY_E;aim.physical_keycode=KEY_E;aim.pressed=true
	scene._unhandled_input(aim)
	await ticks(25)
	var v = scene.player.visual
	var carrier: Transform3D = v.skeleton.global_transform * v.skeleton.get_bone_global_pose(v.carrier_bone)
	var direction := carrier.basis.y.normalized()
	z.position = v.socket.muzzle_position()+direction*2.5
	z.position.y = 0.0
	z.velocity=Vector3.ZERO
	await ticks(4)
	var shots_before: int = scene.rifle_fire.shots_fired
	for i in hz*3:
		await ticks(1)
		if z.is_dead: break
	check(z.is_dead and z.current_hp == 0,"Real held-E rifle projectiles deal lethal damage")
	if not z.is_dead:scene.free();quit(1);return
	check(scene.rifle_fire.shots_fired-shots_before>=4,"Existing12damage/60HP requires multiple actual bullets")
	aim.pressed=false;scene._input(aim)
	check(z.ragdoll.running and z.ragdoll.bodies.size()==7,"Lethal shot starts existing seven-part Lab physics")
	check(z.ragdoll.handoff_error<.0002,"Animated world pose retained at death handoff")
	var impulse: Vector3 = z.ragdoll.total_applied_impulse
	var directed_impulse:=impulse-Vector3.UP*180.0
	check(absf(directed_impulse.length()-360.0)<.01 and directed_impulse.normalized().dot(direction)>.998,"Existing Rifle preset impulse follows actual projectile direction")
	check(not z.take_damage(999,Vector3.RIGHT),"Dead zombie rejects repeated damage/impulses")
	check(z.death_triggers==1,"One lethal handoff only")
	var bodies: Array = z.ragdoll.bodies.values()
	var chest: PhysicalBone3D = z.ragdoll.bodies.Chest
	var start := chest.global_position
	var saw_contact := false
	var min_y := INF
	var peak_anchor := 0.0
	while is_instance_valid(z):
		if z.is_dead and not z.ragdoll.bodies.is_empty():
			min_y=minf(min_y,z.ragdoll.minimum_corner_y())
			peak_anchor=maxf(peak_anchor,z.ragdoll.max_anchor_error())
			saw_contact=saw_contact or z.ragdoll.contact_motion().core_contacts>0
			for b in z.ragdoll.bodies.values():check(b.global_position.is_finite(),"Finite physical corpse transforms")
		await ticks(1)
	check(saw_contact,"Native corpse reaches ground with core-body collision before cleanup")
	for body in bodies: check(not is_instance_valid(body),"Cleanup frees every native physical body")
	check(combat.last_corpse_lifetime>=1.1 and combat.last_corpse_lifetime<=1.3,"Corpse removal within1.1–1.3seconds")
	check(min_y>-.075 and peak_anchor<.05,"Bounded ground penetration and joint separation at gameplay physics rate")
	# Simultaneous deaths, then reset mid-flight: no orphaned graphs or stale shots.
	for other in combat.zombies:other.take_damage(999,Vector3.FORWARD)
	await ticks(3)
	check(combat.active_ragdolls()<=4,"At most four active ragdolls")
	var old_bodies: Array=[]
	for other in combat.zombies:old_bodies.append_array(other.ragdoll.bodies.values())
	scene.reset_player();await ticks(3)
	for body in old_bodies:check(not is_instance_valid(body),"Reset releases old corpse bodies/joints")
	check(combat.zombies.size()==4 and combat.active_ragdolls()==0,"R restores four living zombies without accumulating corpses")
	check(scene.rifle_fire.active_projectiles()==0 and not scene.rifle_fire.trigger_held,"Reset clears pending shots")
	check(absf(scene.player.walk_speed-2.70)<.001 and absf(scene.player.run_speed-7.55)<.01,"Approved movement speeds retained")
	await ticks(hz*3)
	var attack_count := 0
	for other in combat.zombies:
		check(other.visual.walk_clock>0.0,"Chasing uses requested source Walk")
		attack_count += other.visual.attack_count
	check(attack_count>=4,"Existing AI triggers requested source Attack at stand-off range")
	check(not scene.player.is_dead,"Research attacks do not replace approved player health/death gameplay")
	# Worst admitted burst: all four native graphs die at once and fully retire.
	var burst_bodies: Array=[]
	for other in combat.zombies:
		other.take_damage(999,Vector3.FORWARD)
		burst_bodies.append_array(other.ragdoll.bodies.values())
	check(combat.active_ragdolls()==4 and burst_bodies.size()==28,"Fixed encounter bounds a simultaneous burst to28native bodies")
	await ticks(hz+hz/3)
	check(combat.zombies.is_empty() and combat.active_ragdolls()==0,"All four corpses cleaned after the short lifetime")
	for body in burst_bodies:check(not is_instance_valid(body),"Burst cleanup releases every native body/joint")
	report={"passed":failures.is_empty(),"failures":failures,"physics_hz":hz,"impulse":str(impulse),"minimum_corner_y":min_y,"maximum_anchor_error_m":peak_anchor,"corpse_lifetime":combat.last_corpse_lifetime,"native_ground_contact":saw_contact,"maximum_ragdolls":4,"source_attack_triggers":attack_count}
	print("ZOMBIE_COMBAT ",JSON.stringify(report))
	var destination:=OS.get_environment("ZOMBIE_COMBAT_RESULTS")
	if not destination.is_empty():FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	scene.free();quit(0 if failures.is_empty() else 1)
