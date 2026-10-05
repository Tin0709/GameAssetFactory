extends SceneTree
const LAB = preload("res://scenes/PlayerPoseLab.tscn")
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
const FIXTURE = preload("res://tests/legacy_fixture.gd")
const Spring = preload("res://scripts/secondary_spring.gd")
var checks := 0
var failures: Array[String] = []
var lab: Node3D
var level: Node3D
var maximum_contact := 0.0
var maximum_drop := 0.0
var maximum_ground_error := 0.0
var player_usec := 0.0
var zombie_off_usec := 0.0
var zombie_on_usec := 0.0
var zombie_death_usec := 0.0
var rendered := false
var render_sample := {}
var directions := [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3(1,0,1).normalized(), Vector3(-1,0,1).normalized()]

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func tick(count: int) -> void:
	for i in count: await physics_frame
func contact_error(v: Node3D) -> float:
	var result := 0.0
	var socket_pose: Transform3D = v.skeleton.get_bone_global_pose(v.socket_bone)
	for pair in [[v.main_arm, v.socket.grips[v.weapon_type], v.Socket.MAIN_HAND_CONTACTS[v.weapon_type]], [v.support_arm, v.socket.supports[v.weapon_type], v.Socket.SUPPORT_HAND_CONTACTS[v.weapon_type]]]:
		var hand: Vector3 = v.skeleton.get_bone_global_pose(pair[0]) * pair[2]
		result = maxf(result, hand.distance_to(socket_pose * pair[1]))
	return result
func capture(label: String) -> void:
	if not rendered: return
	if is_instance_valid(lab): lab._update_status()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tests/bounce_%s.png" % label) == OK, "Capture " + label)
func render_frames(count: int) -> float:
	var start := Time.get_ticks_usec()
	for frame in count: await RenderingServer.frame_post_draw
	return float(count) * 1000000.0 / (Time.get_ticks_usec() - start)

func run() -> void:
	rendered = "--capture" in OS.get_cmdline_user_args()
	# Mathematical stability over frame rates/hitches and return to zero rest.
	for fps in [15, 30, 60, 120]:
		var spring := Spring.new()
		spring.kick(Vector3(-0.6, 0.3, 0.1), 1.2)
		for frame in fps * 3: spring.advance(1.0 / fps, Vector3.ZERO, 3.6, 0.48, Vector3(0.024,0.045,0.045))
		check(spring.value.length() < 0.00001 and spring.velocity.length() < 0.00001, "Finite stable rest at %d FPS" % fps)
		spring.kick(Vector3.ONE, 1.2)
		spring.advance(0.5, Vector3.ZERO, 3.6, 0.48, Vector3.ONE * 0.05)
		check(spring.value.is_finite() and spring.value.length() < 0.087, "Hitch remains bounded")
	check(Spring.contacts_crossed(0.49, 0.02, 0) == 1 and Spring.contacts_crossed(0.99,0.02,0) == 1 and Spring.contacts_crossed(0.01,-0.02,0) == 1, "Contacts handle wrap and reverse gait")
	lab = LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.set_process(false)
	var v: Node3D = lab.visual
	for weapon in 3:
		lab.equip(weapon)
		for strength in [0.0, 0.5, 1.0, 1.5]:
			lab.set_bounce_strength(strength)
			for aiming in [false, true]:
				lab.set_aim(aiming)
				for state in 3:
					lab.set_locomotion(state)
					for frame in 100:
						if frame in [20, 40, 60]: lab.fire_recoil()
						lab._advance(1.0/60.0)
						if frame > 15:
							maximum_contact = maxf(maximum_contact, contact_error(v))
						maximum_drop = maxf(maximum_drop, absf(v.body_spring.value.x * strength))
					check(v.body_spring.value.is_finite() and absf(v.body_spring.value.x) <= 0.0241, "Bounded player spring across weapon/state/strength")
					for bone in v.skeleton.get_bone_count(): check(v.skeleton.get_bone_pose_scale(bone) == Vector3.ONE, "Rigid bone scale")
	check(maximum_contact < 0.015, "Held hand contacts remain within 15mm")
	lab.set_bounce_strength(1.0)
	for fps in [30, 60, 120]:
		v.set_bounce(true)
		v.movement_speed = 6.25
		v.move_weight = 1.0
		v.run_weight = 1.0
		v.cycles_per_second = 2.3
		v.locomotion_phase = 0.01
		v.stride_sign = 1.0
		var initial_count: int = v.contact_count
		for frame in fps: v._process(1.0 / fps)
		check(v.contact_count - initial_count == 4, "Gait contacts follow real phase at %d FPS" % fps)
	# Start/stop, hard turn, hit and rapid fire, then complete settling.
	for frame in 360:
		var velocity: Vector3 = directions[(frame / 20) % 6] * (6.25 if frame < 180 else 0.0)
		v.update_motion(velocity, null, 1.0/60.0)
		if frame < 120 and frame % 4 == 0: v.shot_recoil(Vector3.BACK)
		if frame in [0, 30, 60]: v.hit_impulse(directions[(frame / 30) % 6])
		v._process(1.0/60.0)
	check(v.body_spring.value.length() < 0.001 and v.weapon_spring.value.length() < 0.001, "Start/stop/turn/hit/rapid-fire settle without rest drift")
	check(not v.is_firing, "Primary recoil settles after rapid fire")
	# Evaluate the same sampled pose ON/OFF: added layer never moves soles.
	v.movement_speed = 6.25
	for frame in 60: v._process(1.0/60.0)
	var left_before: Transform3D = v.skeleton.get_bone_global_pose(v.leg_left)
	var right_before: Transform3D = v.skeleton.get_bone_global_pose(v.leg_right)
	v.bounce_enabled = false
	v._evaluate(0)
	check(v.skeleton.get_bone_global_pose(v.leg_left).is_equal_approx(left_before) and v.skeleton.get_bone_global_pose(v.leg_right).is_equal_approx(right_before), "Leg compensation preserves original sampled soles")
	lab.toggle_bounce() # UI had been ON; now OFF.
	check(not lab.bounce_enabled and not v.bounce_enabled, "Pose Lab bounce toggle")
	lab.toggle_bounce()
	for speed in [1.0,0.5,0.25]:
		lab.set_speed(speed)
		v.recoil_time = 100.0
		v.queued_recoil = false
		lab.fire_recoil()
		lab._advance(1.0/60.0)
		check(absf(v.recoil_time - speed / 60.0) < 0.0001, "Lab speed shares spring/recoil clock")
	lab.set_speed(1.0)
	lab.toggle_pause()
	var spring_before: Vector3 = v.body_spring.value
	lab._process(0.5)
	check(v.body_spring.value == spring_before, "Lab freeze also freezes springs")
	lab.toggle_pause()
	var started := Time.get_ticks_usec()
	for frame in 1000: lab._advance(1.0/60.0)
	player_usec = float(Time.get_ticks_usec() - started) / 1000.0
	if rendered:
		for weapon in 3:
			lab.equip(weapon)
			lab.set_locomotion(2)
			for aiming in [false,true]:
				lab.set_aim(aiming)
				for state in 3:
					lab.set_locomotion(state)
					for frame in 80: lab._advance(1.0/60.0)
					lab.set_view(4 if state == 2 else 3)
					await capture("%s_%s_%s" % [v.WEAPON_NAMES[weapon].to_lower(), "aim" if aiming else "low", String(lab.STATES[state]).to_lower()])
				lab.fire_recoil()
				for frame in 4: lab._advance(1.0/60.0)
				lab.set_view(1)
				lab.distance = 5.0
				lab._update_camera()
				await capture("%s_%s_fire" % [v.WEAPON_NAMES[weapon].to_lower(), "aim" if aiming else "low"])
		lab.equip(0)
		lab.set_view(3)
		lab.set_aim(false)
		lab.set_locomotion(0)
		for frame in 120: lab._advance(1.0/60.0)
		lab.set_locomotion(2)
		for frame in 4: lab._advance(1.0/60.0)
		await capture("player_start")
		for frame in 60: lab._advance(1.0/60.0)
		lab.set_locomotion(0)
		for frame in 4: lab._advance(1.0/60.0)
		await capture("player_stop")
		for frame in 4:
			v.update_motion(Vector3.RIGHT * 6.25, null, 1.0/60.0)
			v._process(1.0/60.0)
		await capture("player_turn")
		v.hit_impulse(Vector3.LEFT)
		for frame in 5: v._process(1.0/60.0)
		await capture("player_hit")
	lab.queue_free()
	await process_frame
	level = LEVEL.instantiate()
	FIXTURE.prepare(level)
	level.get_node("Actors/Player/Pistol").enabled = false
	root.add_child(level)
	current_scene = level
	var combat: Node = level.get_node("Combat")
	# Measure animation/feedback, excluding compressed audio; its hooks have a suite.
	combat.audio.minimum_event_interval = 1000000.0
	combat.player.position = Vector3(-7, 0.02, 5)
	for enemy in combat.living_zombies.duplicate():
		combat.living_zombies.erase(enemy)
		enemy.queue_free()
	await process_frame
	var variants := []
	var actors := []
	for i in 6:
		var enemy := ZOMBIE.instantiate()
		enemy.position = Vector3((i % 3 - 1) * 2.4, 0.02, (i / 3 - 0.5) * 3.0)
		level.get_node("Actors").add_child(enemy)
		combat.register_zombie(enemy)
		enemy.set_physics_process(false)
		enemy.visual.set_process(false)
		enemy.visual.play_state(&"Walk")
		for frame in 60: enemy.visual._process(1.0/60.0)
		check(enemy.visual.contact_count > 0, "Zombie gait creates contact impulse")
		enemy.take_damage(10, directions[i])
		for frame in 8: enemy.visual._process(1.0/60.0)
		check(enemy.visual.body_spring.value.length() > 0 and enemy.knockback.length() > 0, "Zombie hit adds spring alongside knockback")
		enemy.take_damage(50, directions[i])
		actors.append(enemy)
		variants.append(enemy.visual.death_variant)
	check(variants.size() == 6 and variants.duplicate().reduce(func(unique, item): return unique if unique.has(item) else unique + [item], []).size() == 6, "Six death variants")
	var camera: Camera3D = level.get_node("Camera3D")
	camera.size = 10
	var final_poses := []
	for frame in 64:
		for enemy in actors:
			enemy.visual._process(1.0/60.0)
			var visual: Node3D = enemy.visual
			var lower := INF
			for corner in visual.bound_corners.size():
				var point: Vector3 = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(visual.bound_bones[corner]) * visual.bound_corners[corner]
				lower = minf(lower, point.y)
			maximum_ground_error = maxf(maximum_ground_error, maxf(0.0, -lower))
		if frame in [11, 26, 35, 48]: await capture("death_%d" % frame)
		if frame == 50:
			for enemy in actors: final_poses.append(enemy.visual.skeleton.get_bone_pose(enemy.visual.root_bone))
	check(maximum_ground_error < 0.0001, "All rigid death cuboids remain above ground")
	for i in actors.size():
		check(actors[i].visual.ground_bounce_count == 1, "Exactly one ground rebound")
		check(actors[i].visual.skeleton.get_bone_pose(actors[i].visual.root_bone).is_equal_approx(final_poses[i]), "Corpse holds stable final pose")
	check(combat.pickups.get_child_count() == 0, "EXP waits through short corpse hold")
	for enemy in actors: enemy.visual._process(1.0/60.0)
	await process_frame
	check(combat.pickups.get_child_count() == 6 and combat.effects.get_children().filter(func(node): return node.get_script() == preload("res://scripts/zombie_death_smoke.gd")).size() == 6, "Exactly one smoke/drop after hold")
	await capture("death_smoke")
	await tick(50)
	check(get_nodes_in_group("zombies").is_empty(), "No infinite corpse nodes")
	# Forty varied zombies, with original library sample cost vs added spring cost.
	actors.clear()
	for i in 40:
		var enemy := ZOMBIE.instantiate()
		enemy.position = Vector3((i % 8 - 3.5) * 0.85,0.02,(i / 8 - 2) * 0.9)
		level.get_node("Actors").add_child(enemy)
		combat.register_zombie(enemy)
		enemy.set_physics_process(false)
		enemy.visual.set_process(false)
		enemy.visual.play_state(&"Walk")
		actors.append(enemy)
	for enabled in [false,true]:
		for enemy in actors: enemy.visual.bounce_enabled = enabled
		started = Time.get_ticks_usec()
		for frame in 120:
			for enemy in actors: enemy.visual._process(1.0/60.0)
		var usec := float(Time.get_ticks_usec() - started) / 120.0
		if enabled: zombie_on_usec = usec
		else: zombie_off_usec = usec
	check(actors[0].visual.phase_offset != actors[1].visual.phase_offset, "Crowd phase variation retained")
	for enemy in actors:
		check(enemy.visual.body_spring.value.is_finite(), "Crowd spring remains finite")
		check(enemy.visual.skeleton.get_bone_pose_scale(enemy.visual.hips) == Vector3.ONE, "Zombie stays rigid")
	if rendered:
		camera.size = 11
		for enemy in actors: enemy.visual.set_process(true)
		await render_frames(30)
		for enemy in actors: enemy.visual.bounce_enabled = false
		render_sample["off_fps"] = await render_frames(90)
		for enemy in actors: enemy.visual.bounce_enabled = true
		render_sample["on_fps"] = await render_frames(90)
		render_sample["gpu"] = RenderingServer.get_video_adapter_name()
		await capture("crowd")
	for enemy in actors:
		enemy.visual.set_process(false)
		enemy.take_damage(60, Vector3.RIGHT)
	started = Time.get_ticks_usec()
	for frame in 45:
		for enemy in actors: enemy.visual._process(1.0/60.0)
	zombie_death_usec = float(Time.get_ticks_usec() - started) / 45.0
	for enemy in actors: enemy.visual.set_process(true)
	paused = true
	var corpse_time: float = actors[0].visual.death_time
	for frame in 10: await process_frame
	check(actors[0].visual.death_time == corpse_time, "Scene pause freezes death/hold clocks")
	paused = false
	if rendered: render_sample["forty_deaths_fps"] = await render_frames(90)
	await tick(120)
	check(combat.living_zombies.is_empty() and get_nodes_in_group("zombies").is_empty(), "Forty simultaneous deaths clean up")
	var report := {"checks": checks, "failures": failures, "max_hand_contact_m": maximum_contact, "max_body_drop_m": maximum_drop,
		"max_death_ground_penetration_m": maximum_ground_error, "death_variants": variants, "corpse_hold_seconds": 0.45,
		"smoke_start_seconds": 1.07, "player_update_usec": player_usec, "forty_zombies_off_usec": zombie_off_usec,
		"forty_zombies_on_usec": zombie_on_usec, "forty_zombies_added_usec": zombie_on_usec - zombie_off_usec,
		"forty_death_pose_usec": zombie_death_usec,
		"rendered": rendered, "render_sample": render_sample, "phone_tested": false}
	var output := FileAccess.open("res://tests/bounce_%s_validation.json" % ("rendered" if rendered else "headless"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	level.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
