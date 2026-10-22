extends SceneTree
## Same encounter/damage contract: direction, recovery, repeated hits and native death.
var failures: Array[String] = []
var report := {}
var fps := 60
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok and not failures.has(message):failures.append(message);push_error(message)
func ticks(count: int) -> void:
	for i in count:await physics_frame
	await process_frame
func nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():count += nodes(child)
	return count
func run() -> void:
	if "30" in OS.get_cmdline_user_args():fps=30
	Engine.max_fps=fps
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	# Explicit legacy damage/death fixture; saved performance lab remains100m.
	scene.performance_test_enabled=false;scene.grass_field_blocks=30;scene.grass_vegetation_enabled=false
	root.add_child(scene);scene.player.scripted_input=true
	await ticks(6)
	var z=scene.zombie_combat.zombies[0]
	var peer=scene.zombie_combat.zombies[1]
	for actor in scene.zombie_combat.zombies:
		actor.target=null;actor.set_physics_process(false);actor.current_hp=100000
		actor.visual.phase_offset=0.;actor.visual.life=0.;actor.visual.walk_clock=0.
		actor.visual.walk_weight=0.;actor.visual.attack_time=1.;actor.visual.attack_weight=0.
		actor.visual.rotation=Vector3.ZERO;actor.visual.play_state(&"Idle")
		actor.visual._process(0.)
	var v=z.visual;var ref=peer.visual;var sk=v.skeleton;var rs=ref.skeleton
	var chest: int=sk.find_bone("Chest")
	var lower_error:=0.;var peak:=0.;var peaks:=[];var recovery:=0.
	var dt:=1./fps
	for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.LEFT]:
		check(z.take_damage(1,direction),"Living zombie accepts nonlethal damage")
		check(v.flash_remaining>0.,"Damage flashes immediately")
		check(ref.flash_remaining==0.,"Damage flash remains per-instance")
		check(v.flash_duration<=.075,"Brief damage flash separates continuous shots")
		var directional_peak:=0.
		for i in int(.6*fps):
			v._process(dt);ref._process(dt)
			var delta_q: Quaternion=sk.get_bone_pose_rotation(chest)*rs.get_bone_pose_rotation(chest).inverse()
			var angle:=delta_q.get_angle();if angle>PI:angle=TAU-angle
			directional_peak=maxf(directional_peak,angle)
			for name in ["Hips","Leg.L","Leg.R"]:
				var bone: int=sk.find_bone(name)
				lower_error=maxf(lower_error,sk.get_bone_pose_position(bone).distance_to(rs.get_bone_pose_position(bone)))
				lower_error=maxf(lower_error,1.-absf(sk.get_bone_pose_rotation(bone).dot(rs.get_bone_pose_rotation(bone))))
			if i==1:
				var base_up: Vector3=rs.global_basis*rs.get_bone_global_pose(chest).basis.y
				var hit_up: Vector3=sk.global_basis*sk.get_bone_global_pose(chest).basis.y
				check((hit_up-base_up).dot(direction)>.005,"Upper body reacts along bullet direction "+str(direction))
			if i==int(.4*fps):recovery=maxf(recovery,angle)
		peaks.append(rad_to_deg(directional_peak));peak=maxf(peak,directional_peak)
		check(directional_peak>deg_to_rad(1.),"Nonlethal hit adds readable skeletal reaction")
		check(v.flash_remaining<=0.,"Flash clears between 6Hz shots")
	check(lower_error<.00002,"Live reaction preserves lower-body source pose")
	check(recovery<deg_to_rad(.2),"Reaction recovers quickly without movement stun")
	# Hit direction stays in world space even as the chasing zombie turns.
	v.rotation.y=PI*.5;ref.rotation.y=PI*.5
	z.take_damage(1,Vector3.RIGHT)
	for i in 2:v._process(dt);ref._process(dt)
	var base_up: Vector3=rs.global_basis*rs.get_bone_global_pose(chest).basis.y
	var hit_up: Vector3=sk.global_basis*sk.get_bone_global_pose(chest).basis.y
	check((hit_up-base_up).dot(Vector3.RIGHT)>.01,"Rotated zombie reacts along world-space shot direction")
	for i in fps:v._process(dt);ref._process(dt)
	var initial_nodes:=nodes(z)
	var train_peak:=0.;var speed_peak:=0.
	for i in fps*4:
		if i%int(fps/6)==0:z.take_damage(1,Vector3.FORWARD)
		v._process(dt)
		# Explicit bounded state is also useful for mobile telemetry/stacking checks.
		if v.get("hit_rotation")!=null:train_peak=maxf(train_peak,v.hit_rotation.length())
		speed_peak=maxf(speed_peak,z.knockback.length())
	check(nodes(z)==initial_nodes,"Sustained fire reuses a fixed feedback node budget")
	check(train_peak>deg_to_rad(2.) and train_peak<=deg_to_rad(7.)+.0001,"6Hz hit response is readable and bounded")
	check(speed_peak<=1.6001,"Nonlethal knockback is bounded")
	for i in 100:z.take_damage(1,Vector3.RIGHT)
	if v.get("hit_rotation")!=null:
		for i in fps:v._process(dt);train_peak=maxf(train_peak,v.hit_rotation.length())
		check(v.hit_rotation.length()<.00001,"Burst settles without accumulated pose drift")
	check(nodes(z)==initial_nodes,"Burst cannot allocate feedback nodes")
	check(train_peak<=deg_to_rad(7.)+.0001,"Same-tick burst remains restrained")
	# Actual controller continues chasing during repeated bullet impulses.
	z.position=Vector3(0,0,-7);z.target=scene.player;z.set_physics_process(true)
	z.knockback=Vector3.ZERO;var start: Vector3=z.position
	for i in 60:
		if i%10==0:z.take_damage(1,Vector3.FORWARD)
		await ticks(1)
	check(z.position.distance_to(start)>.8 and v.walk_clock>0.,"Hit zombie keeps approaching without gait resets or stun lock")
	z.take_damage(999999,Vector3.FORWARD)
	check(z.is_dead and z.death_triggers==1 and z.ragdoll.running,"Lethal damage starts existing native death exactly once")
	check(z.ragdoll.handoff_error<.0002,"Native death retains final hit-reacted pose")
	check(not z.take_damage(999,Vector3.RIGHT),"Dead zombie rejects repeated hits")
	check(z.ragdoll.total_applied_impulse.is_equal_approx(Vector3.FORWARD*240.+Vector3.UP*48.),"Approved lethal impulse is unchanged")
	var bodies: Array=z.ragdoll.bodies.values()
	await ticks(74)
	check(not is_instance_valid(z),"Corpse cleans up at existing 1.2seconds")
	for body in bodies:check(not is_instance_valid(body),"Death cleanup releases native physics resources")
	report={"passed":failures.is_empty(),"failures":failures,"render_fps":fps,"physics_hz":Engine.physics_ticks_per_second,"directional_chest_peaks_deg":peaks,"recovery_at_400ms_deg":rad_to_deg(recovery),"lower_body_error":lower_error,"sustained_burst_peak_deg":rad_to_deg(train_peak),"knockback_peak_mps":speed_peak,"fixed_actor_nodes":initial_nodes}
	print("ZOMBIE_HIT_FEEDBACK ",JSON.stringify(report))
	var out:=OS.get_environment("ZOMBIE_HIT_RESULTS")
	if not out.is_empty():FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	scene.free();quit(0 if failures.is_empty() else 1)
