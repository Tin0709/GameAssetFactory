extends SceneTree
const LAB = preload("res://scenes/PlayerPoseLab.tscn")
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
var lab: Node3D
var v: Node3D
var target: Node3D
var checks := 0
var failures: Array[String] = []
var peak_stop_degrees := 0.0
var peak_stop_sweep := 0.0
var peak_pattern_degrees := 0.0
var gameplay_stops := 0
var rendered := false
var dt := 1.0 / 60.0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
func advance(velocity: Vector3, aiming: bool = true) -> void:
	v.update_motion(velocity, target if aiming else null, dt)
	v._process(dt)
func legs() -> Array[Quaternion]:
	return [v.skeleton.get_bone_global_pose(v.leg_left).basis.get_rotation_quaternion(), v.skeleton.get_bone_global_pose(v.leg_right).basis.get_rotation_quaternion()]
func capture(label: String) -> void:
	if not rendered: return
	lab._update_status()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/locomotion_stop_%s.png" % label)
func stop(aiming: bool, label: String) -> void:
	var previous := legs()
	var yaw: float = v.lower_yaw
	var sign_before: float = v.stride_sign
	var phase: float = v.locomotion_phase
	var sweep := Vector2.ZERO
	var maximum := 0.0
	var previous_chest: Quaternion = v.skeleton.get_bone_global_pose(v.chest).basis.get_rotation_quaternion()
	for frame in 20:
		advance(Vector3.ZERO, aiming)
		var current := legs()
		for i in 2:
			var angle := previous[i].angle_to(current[i])
			maximum = maxf(maximum, angle)
			sweep[i] += angle
			previous[i] = current[i]
		check(v.lower_yaw == yaw and v.stride_sign == sign_before, "Stop preserves direction and reverse stride: " + label)
		var phase_delta: float = wrapf(v.locomotion_phase - phase, -0.5, 0.5)
		check(absf(phase_delta) <= dt * v.run_cadence + 0.00001 and phase_delta * sign_before >= -0.00001, "Continuous decaying gait, no reset or reversal: " + label)
		phase = v.locomotion_phase
		var chest: Quaternion = v.skeleton.get_bone_global_pose(v.chest).basis.get_rotation_quaternion()
		check(previous_chest.angle_to(chest) < deg_to_rad(20), "Torso does not inherit lower-body unwind: " + label)
		previous_chest = chest
		if frame >= ceili(0.13 / dt): check(v.move_weight == 0.0 and v.cycles_per_second == 0.0, "Idle blend settles within 0.15s: " + label)
		if frame >= ceili(0.18 / dt): check(v.lower_rotation.angle_to(Quaternion.IDENTITY) < 0.001, "Directional offset reaches neutral Idle within 0.18s")
		for bone in [v.leg_left, v.leg_right]:
			check(v.skeleton.get_bone_pose_scale(bone) == Vector3.ONE, "Leg remains rigid")
	peak_stop_degrees = maxf(peak_stop_degrees, rad_to_deg(maximum))
	peak_stop_sweep = maxf(peak_stop_sweep, rad_to_deg(maxf(sweep.x, sweep.y)))
	check(maximum / dt < deg_to_rad(1900), "No rapid leg flip: " + label)
	check(maxf(sweep.x, sweep.y) < deg_to_rad(200), "No full leg rotational sweep: " + label)
	# Sole pose writer, no accumulated offsets; spring layer keeps sampled anchors.
	var before: Transform3D = v.skeleton.get_bone_global_pose(v.leg_left)
	v._evaluate(0)
	check(before.is_equal_approx(v.skeleton.get_bone_global_pose(v.leg_left)), "Repeated evaluation does not accumulate rotation")
	v.bounce_enabled = false
	v._evaluate(0)
	check(before.is_equal_approx(v.skeleton.get_bone_global_pose(v.leg_left)), "Bounce preserves feet after stopping")
	v.bounce_enabled = true
	v._evaluate(0)

func run() -> void:
	rendered = "--capture" in OS.get_cmdline_user_args()
	lab = LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.set_process(false)
	v = lab.visual
	target = Node3D.new()
	lab.add_child(target)
	target.position = Vector3(0, 0, 5)
	var directions := [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT, Vector3(1,0,1).normalized(), Vector3(-1,0,1).normalized(), Vector3(1,0,-1).normalized(), Vector3(-1,0,-1).normalized()]
	for weapon in 3:
		lab.equip(weapon)
		for aiming in [false, true]:
			for speed in [4.25, 6.25]:
				for direction in directions:
					for repetition in 4:
						for frame in 35: advance(direction * speed, aiming)
						stop(aiming, "weapon %d / %.2f / %s / %s" % [weapon, speed, direction, aiming])
		# Exact previously failing reproduction, including multiple heading laps.
		for bounce in [false, true]:
			v.set_bounce(bounce)
			for frame in 720:
				var angle := frame * TAU / 120.0
				advance(Vector3(sin(angle),0,cos(angle)) * 2.6)
			check(absf(v.lower_yaw) <= PI, "Multiple direction laps never accumulate Euler turns")
			stop(true, "six circles, bounce %s" % bounce)
		v.set_bounce(true)
		for pattern in ["taps", "circle_taps", "opposites", "walk_run", "run_walk", "run_combat"]:
			for repetition in 6:
				for frame in 90:
					var previous := legs()
					var velocity := Vector3.BACK * 4.25
					match pattern:
						"taps": velocity = directions[(frame / 8) % 8] * (4.25 if frame % 8 < 4 else 0.0)
						"circle_taps": velocity = Vector3(sin((frame + repetition * 90) * TAU / 240.0), 0, cos((frame + repetition * 90) * TAU / 240.0)) * (2.6 if frame % 8 < 4 else 0.0)
						"opposites": velocity = Vector3.BACK * (6.25 if (frame / 6) % 2 == 0 else -6.25)
						"walk_run": velocity *= 1.0 if frame < 45 else 6.25 / 4.25
						"run_walk": velocity *= 6.25 / 4.25 if frame < 45 else 1.0
						"run_combat": velocity *= 6.25 / 4.25 if frame < 45 else 2.6 / 4.25
					advance(velocity, pattern != "run_combat" or frame >= 45)
					var current := legs()
					var angle := maxf(previous[0].angle_to(current[0]), previous[1].angle_to(current[1]))
					peak_pattern_degrees = maxf(peak_pattern_degrees, rad_to_deg(angle))
					check(angle < deg_to_rad(32), "No frame flip during rapid input / angle-seam pattern: " + pattern)
				stop(true, pattern)
		for fps in [30, 60, 120]:
			dt = 1.0 / fps
			for frame in fps: advance(Vector3.FORWARD * 2.6)
			for frame in ceili(0.16 * fps): advance(Vector3.ZERO)
			var yaw: float = v.lower_yaw
			var sign_before: float = v.stride_sign
			var phase: float = v.locomotion_phase
			for frame in fps * 2: advance(directions[frame % 8] * 0.03)
			check(v.lower_yaw == yaw and v.stride_sign == sign_before and v.locomotion_phase == phase and v.move_weight == 0.0, "Near-zero jitter freezes direction/stride/phase at %d FPS" % fps)
			dt = 1.0 / 60.0
	# Quaternion weighting also handles a legacy unwrapped heading safely.
	v.lower_yaw = TAU * 6 + 0.4
	v.move_weight = 1.0
	v._evaluate(0)
	stop(true, "legacy unwrapped yaw")
	lab.set_view(1)
	lab.locomotion = 2
	lab.aiming = true
	for frame in 60: advance(Vector3.RIGHT * 6.25)
	await capture("run")
	for frame in 4: advance(Vector3.ZERO)
	lab.locomotion = 0
	await capture("blending")
	for frame in 12: advance(Vector3.ZERO)
	await capture("idle")
	await gameplay(directions)
	var report := {"checks": checks, "failures": failures, "peak_stop_frame_degrees_60fps": peak_stop_degrees, "peak_pattern_frame_degrees_60fps": peak_pattern_degrees, "peak_stop_sweep_degrees": peak_stop_sweep, "actual_gameplay_stops": gameplay_stops, "dead_zone_mps": v.LOCOMOTION_DEAD_ZONE, "transition_seconds": 0.13, "rendered": rendered}
	FileAccess.open("res://tests/locomotion_stop_%s_validation.json" % ("rendered" if rendered else "headless"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	lab.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func gameplay(directions: Array) -> void:
	lab.hide()
	lab.get_node("HUD").hide()
	var level := LEVEL.instantiate()
	level.get_node("SpawnDirector").enabled = false
	level.get_node("Progression").enabled = false
	root.add_child(level)
	current_scene = level
	level.select_test_weapon(0)
	var player: CharacterBody3D = level.player
	var visual: Node3D = player.visual
	var gun: Node3D = player.get_node("Pistol")
	gun.set_physics_process(false)
	var enemy := ZOMBIE.instantiate()
	enemy.position = Vector3(0,0.02,3.5)
	level.get_node("Actors").add_child(enemy)
	enemy.set_physics_process(false)
	level.combat.register_zombie(enemy)
	for weapon in 3:
		player.equip_test_weapon(weapon)
		for sprinting in [false, true]:
			for direction: Vector3 in directions:
				for repetition in 2:
					player.position = Vector3(0,0.02,0)
					player.velocity = Vector3.ZERO
					gun.enabled = repetition == 1
					var actions: Array[String] = []
					if direction.x < -0.01: actions.append("move_left")
					if direction.x > 0.01: actions.append("move_right")
					if direction.z < -0.01: actions.append("move_forward")
					if direction.z > 0.01: actions.append("move_backward")
					for action in actions: Input.action_press(action)
					if sprinting: Input.action_press("sprint")
					for frame in 12: await physics_frame
					for action in actions: Input.action_release(action)
					Input.action_release("sprint")
					var previous: Quaternion = visual.skeleton.get_bone_global_pose(visual.leg_left).basis.get_rotation_quaternion()
					for frame in 24:
						await physics_frame
						var current: Quaternion = visual.skeleton.get_bone_global_pose(visual.leg_left).basis.get_rotation_quaternion()
						check(previous.angle_to(current) < deg_to_rad(35), "Actual gameplay input release has no leg flip: %.2f deg, weapon %d sprint %s frame %d"%[rad_to_deg(previous.angle_to(current)),weapon,sprinting,frame])
						previous = current
					check(player.current_speed < 0.001 and visual.move_weight == 0.0 and visual.lower_rotation.angle_to(Quaternion.IDENTITY) < 0.001, "Actual gameplay stop reaches neutral Idle")
					gameplay_stops += 1
	# Actual gameplay camera: sustained sprint, release, settling and final Idle.
	player.position = Vector3(0,0.02,0)
	Input.action_press("move_right")
	Input.action_press("sprint")
	for frame in 14: await physics_frame
	await capture("game_run")
	Input.action_release("move_right")
	Input.action_release("sprint")
	for frame in 10: await physics_frame
	await capture("game_blending")
	for frame in 18: await physics_frame
	await capture("game_idle")
	level.queue_free()
	await process_frame
	await process_frame
