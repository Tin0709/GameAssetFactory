extends SceneTree
const PLAYER = preload("res://scenes/characters/CuboidPlayer.tscn")
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
var checks := 0
var failures: Array[String] = []
var max_contact := 0.0
var world: Node3D
var player: Node3D
var v: Node3D

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func step(count: int) -> void:
	for i in count: v._process(1.0 / 60.0)

func contacts() -> float:
	var error := 0.0
	for pair in [["Arm.R", "Grip_Point"], ["Arm.L", "Support_Hand_Point"]]:
		var bone: int = v.skeleton.find_bone(pair[0])
		var palm: Vector3 = v.Socket.MAIN_HAND_CONTACTS[v.weapon_type] if pair[0] == "Arm.R" else v.Socket.SUPPORT_HAND_CONTACTS[v.weapon_type]
		var hand: Vector3 = v.skeleton.global_transform * v.skeleton.get_bone_global_pose(bone) * palm
		# Update attachment explicitly for deterministic manual evaluation.
		var socket_bone: int = v.skeleton.find_bone("WeaponSocket")
		var contact: Vector3 = v.socket.grips[v.weapon_type] if pair[0] == "Arm.R" else v.socket.supports[v.weapon_type]
		var point: Vector3 = v.skeleton.global_transform * v.skeleton.get_bone_global_pose(socket_bone) * contact
		error = maxf(error, hand.distance_to(point))
	return error

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	v = player.visual
	v.set_process(false)
	check(v.skeleton.get_bone_count() == 11, "Player retains ten bones plus non-deforming socket")
	check(v.animation_player.get_animation_list().size() >= 15, "All player actions imported")
	var target := Node3D.new()
	world.add_child(target)
	target.position = Vector3(0,0,5)
	var start_us := Time.get_ticks_usec()
	for weapon in 3:
		v.equip_weapon(weapon)
		step(12)
		var visible_count := 0
		for item in v.socket.instances:
			if item.visible: visible_count += 1
		check(visible_count == 1, "Exactly one equipped weapon")
		check(v.socket.instances[weapon].scale.is_equal_approx(Vector3.ONE * v.Socket.HOLD_SCALES[weapon]), "Per-weapon scale applied once")
		for arm in [v.main_arm, v.support_arm]:
			var adjustment: Vector3 = v.skeleton.get_bone_pose_position(arm) - v.raise_pose.position(arm, v.aim_weight * v.raise_pose.clip.length)
			check(adjustment.length() <= 0.191 and (weapon != 0 or adjustment.is_zero_approx()), "Shoulder hold adjustment bounded; pistol retains authored shoulders")
		for aiming in [false, true]:
			for speed in [0.0, 4.25, 6.25]:
				for direction in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT, Vector3(1,0,1).normalized(), Vector3(-1,0,-1).normalized()]:
					for frame in 30:
						v.update_motion(direction * speed, target if aiming else null, 1.0/60.0)
						step(1)
						max_contact = maxf(max_contact, contacts())
					var phase: float = v.locomotion_phase
					v.shot_recoil(Vector3.BACK)
					step(3)
					check(speed == 0.0 or not is_equal_approx(phase, v.locomotion_phase), "Recoil preserves moving gait")
					for bone in v.skeleton.get_bone_count():
						check(v.skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE), "Rigid unscaled bone")
					max_contact = maxf(max_contact, contacts())
					step(35)
					check(not v.is_firing, "Recoil settles")
		v.has_target = true
		step(10)
		v.has_target = false
		step(1)
		check(v.aim_weight > 0.0 and v.aim_weight < 1.0, "Target loss blends")
		step(10)
		check(v.aim_weight == 0.0, "Target loss returns LowReady")
		v.has_target = true
		step(10)
		v.shot_recoil(Vector3.BACK)
		step(2)
		var time_before: float = v.recoil_time
		v.shot_recoil(Vector3.BACK)
		check(v.recoil_time == time_before and v.recoil_gain <= 1.45, "Repeated fire bounded without restart")
	var elapsed := Time.get_ticks_usec() - start_us
	check(max_contact < 0.015, "Hand contacts within 15mm: " + str(max_contact))
	# No other pose writer and no phase resets while stance/weapon changes.
	check(not v.animation_player.is_playing(), "Animation library has no competing playback")
	# Measure phase travel, not just the configured rate. Settled clocks must
	# produce the same cadence at different display frame rates.
	v.stride_sign = 1.0
	for speed_and_rate in [[2.125, 0.85], [4.25, 1.7], [6.25, 2.3], [12.5, 2.3]]:
		v.movement_speed = speed_and_rate[0]
		step(30)
		check(absf(v.cycles_per_second - speed_and_rate[1]) < 0.001, "Speed-responsive bounded cadence")
		for fps in [30, 120]:
			var phase_start: float = v.locomotion_phase
			for frame in fps: v._process(1.0 / fps)
			var expected_phase := fposmod(phase_start + speed_and_rate[1], 1.0)
			check(absf(wrapf(v.locomotion_phase - expected_phase, -0.5, 0.5)) < 0.001, "Frame-rate independent phase integration")
	v.movement_speed = 0.0
	step(10)
	check(v.cycles_per_second == 0.0, "Cadence settles to zero within 0.16s")
	v.movement_speed = 4.25
	step(40)
	var changes: int = v.state_changes
	var before_phase: float = v.locomotion_phase
	step(1)
	check(v.state_changes == changes and v.locomotion_phase != before_phase, "Stable locomotion advances without state restart")
	for index in 9:
		var previous_phase: float = v.locomotion_phase
		v.equip_weapon(index % 3)
		check(v.locomotion_phase == previous_phase, "Weapon changes preserve phase")
		v.has_target = index % 2 == 0
		step(1)
	step(30)
	var leg: int = v.skeleton.find_bone("Leg.L")
	v.is_firing = false
	v._evaluate(0.0)
	var leg_before: Transform3D = v.skeleton.get_bone_global_pose(leg)
	v.is_firing = true
	v.recoil_time = 0.05
	v._evaluate(0.0)
	check(v.skeleton.get_bone_global_pose(leg).is_equal_approx(leg_before), "Recoil never moves feet")
	# Exercise actual SceneTree pause, rather than only direct method calls.
	v.set_process(true)
	paused = true
	var weapon_before: int = v.weapon_type
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1 + (weapon_before + 1) % 3
	key.pressed = true
	player.get_node("WeaponDebug")._unhandled_key_input(key)
	check(v.weapon_type == weapon_before, "Upgrade keys cannot switch weapon during pause")
	var paused_phase: float = v.locomotion_phase
	for i in 3: await process_frame
	check(v.locomotion_phase == paused_phase, "Level-up pause freezes animation phase")
	paused = false
	player.get_node("WeaponDebug")._unhandled_key_input(key)
	check(v.weapon_type == (weapon_before + 1) % 3, "Desktop debug adapter switches weapon")
	for i in 3: await process_frame
	check(v.locomotion_phase != paused_phase, "Resume continues animation phase")
	v.set_process(false)
	var benchmark_start := Time.get_ticks_usec()
	step(1000)
	var average_us := float(Time.get_ticks_usec() - benchmark_start) / 1000.0
	var phases: Array[float] = []
	for i in 5:
		var zombie := ZOMBIE.instantiate()
		zombie.position.x = i * 1.31
		world.add_child(zombie)
		zombie.set_physics_process(false)
		phases.append(zombie.visual.phase_offset)
		check(zombie.visual.rate_variation >= 0.95 and zombie.visual.rate_variation <= 1.05, "Crowd cadence range")
	check(phases[0] != phases[1] and phases[1] != phases[2], "Crowd phases differ")
	if "--capture" in OS.get_cmdline_user_args(): await capture_gallery()
	var phase_before: float = v.locomotion_phase
	v.freeze_animation()
	step(10)
	check(v.locomotion_phase == phase_before, "Defeat freezes gait")
	var result := {"checks": checks, "failures": failures, "max_contact_m": max_contact, "matrix_cpu_usec": elapsed, "player_update_average_usec": average_us, "zombie_phases": phases, "phone_tested": false}
	var file := FileAccess.open("res://tests/animation_v2_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func capture_gallery() -> void:
	for child in world.get_children():
		if child != player: child.queue_free()
	player.visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(7,7,12)
	camera.look_at(Vector3(0,0.8,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.0
	camera.current = true
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-45,-30,0)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263344")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	for weapon in 3:
		for aiming in 2:
			var actor := PLAYER.instantiate()
			world.add_child(actor)
			actor.set_physics_process(false)
			actor.position = Vector3((weapon-1)*3.0,0,(aiming-0.5)*3)
			var visual: Node3D = actor.visual
			visual.set_process(false)
			visual.equip_weapon(weapon)
			visual.has_target = aiming == 1
			visual.movement_speed = 4.25
			for i in 20: visual._process(1.0/60.0)
			var label := Label3D.new()
			actor.add_child(label)
			label.position.y = 2.2
			label.text = visual.WEAPON_NAMES[weapon] + (" Aim" if aiming else " LowReady")
			label.font_size = 40
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/animation_v2_gallery.png")
	camera.position = Vector3(11,4,5)
	camera.look_at(Vector3(0,0.8,0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/animation_v2_side.png")
