extends SceneTree
## Actual Mobile-renderer traversal, shared vegetation motion, manual enemy controls, warm profile.
var level: Node3D
var player: CharacterBody3D
var failures: Array[String] = []
var observations := {}
var samples: Array[Dictionary] = []
var out := "res://.validation/grassland_e2_review"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("E2 REVIEW: " + label)

func tick(count: int) -> void:
	for i in range(count): await physics_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "Actual rendered image " + label)
	if image != null: image.save_png(out + "/" + label + ".png")
	print("E2_CAPTURE " + label)

func traverse(label: String, start: Vector3, sprinting: bool = false, near_rocks: bool = false) -> void:
	player.global_position = start
	player.velocity = Vector3.ZERO
	level.motion = load("res://scripts/grassland_motion.gd").new()
	await tick(12)
	var before := player.global_position
	Input.action_press("move_forward")
	if sprinting: Input.action_press("sprint")
	await tick(40)
	var travelled := Vector2(before.x - player.global_position.x, before.z - player.global_position.z).length()
	var speed: float = player.current_speed
	check(travelled > (2.5 if sprinting else 1.8), label + " advances through terrain")
	check(absf(player.global_position.y - 1.0) < 0.08 and player.is_on_floor(), label + " stays on terrain")
	if not near_rocks:
		check(absf(speed - (6.25 if sprinting else 4.25)) < 0.2, label + " preserves production movement speed")
	else:
		check(speed <= player.walk_speed + 0.2, label + " respects collision-limited walking speed")
	check(level.motion.active_count > 0, label + " publishes player-reactive trail")
	observations[label] = {"distance_m": travelled, "speed_m_s": speed, "floor_y": player.global_position.y, "trail_samples": level.motion.active_count}
	await capture(label)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await tick(70)
	check(level.motion.active_count == 0, label + " trail smoothly expires after recovery")

func profile(label: String) -> void:
	await create_timer(2.5).timeout
	samples.clear()
	for i in range(180):
		await process_frame
		var rid := root.get_viewport_rid()
		samples.append({"frame_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid),
			"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var metrics := {}
	for key in samples[0]:
		var values: Array[float] = []
		var total := 0.0
		for sample in samples:
			values.append(float(sample[key]))
			total += float(sample[key])
		values.sort()
		metrics[key] = {"mean": total / values.size(), "median": values[values.size() / 2], "p95": values[int(values.size() * 0.95)]}
	observations[label] = metrics

func run() -> void:
	if not ResourceLoader.exists("res://scenes/Grassland_50x50.tscn"):
		check(false, "New 50x50 scene is available")
		print(JSON.stringify({"failures": failures}))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	level = load("res://scenes/Grassland_50x50.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Actors/Player")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await tick(45)
	check(get_nodes_in_group("zombies").is_empty(), "No enemies at startup")
	check(is_equal_approx(player.walk_speed, 4.25) and is_equal_approx(player.run_speed, 6.25), "Production movement configuration retained")
	observations["environment"] = level.get_environment_summary()
	await capture("01_spawn_clearing")
	await tick(60)
	await capture("02_wind_next_phase")
	var landmarks: Dictionary = level.get_review_landmarks()
	observations["landmarks"] = landmarks
	await traverse("03_open_walk", Vector3(0, 1.02, 1))
	for pair in [["04_dense_grass_sprint", "dense_grass", true], ["05_rock_cluster_walk", "rocks", false], ["06_flower_patch_walk", "flowers", false], ["07_dirt_path_walk", "dirt", false]]:
		if landmarks.has(pair[1]):
			var start: Vector3 = landmarks[pair[1]]
			await traverse(pair[0], start, pair[2], pair[1] == "rocks")
		else: check(false, "Review traversal landmark " + str(pair[1]))
	# Test existing production player weapon selection, not a new debug equip path.
	for index in range(3):
		var key := InputEventKey.new()
		key.physical_keycode = KEY_1 + index
		key.pressed = true
		Input.parse_input_event(key)
		await tick(2)
		check(player.get_node("Pistol").weapon_type == index, "Existing weapon shortcut " + str(index + 1))
	# Enemy controls exercise the reused real spawn/combat pipeline. Avoid kills
	# during the short count check; production gun behavior is restored immediately.
	var gun: Node = player.get_node("Pistol")
	var was_enabled: bool = gun.enabled
	gun.enabled = false
	player.global_position = Vector3(0, 1.02, 0)
	player.velocity = Vector3.ZERO
	await tick(10)
	check(level.spawn_review_enemies(1) == 0, "OFF rejects manual spawning")
	level.set_enemies_enabled(true)
	gun.enabled = false
	await tick(35)
	check(get_nodes_in_group("zombies").is_empty(), "ON does not automatically spawn enemies")
	check(level.spawn_review_enemies(1) == 1, "Spawn 1 uses the real enemy scene")
	check(level.spawn_review_enemies(5) == 5, "Spawn 5 uses the real enemy scene")
	await tick(3)
	check(get_nodes_in_group("zombies").size() == 6, "Six manually spawned enemies registered")
	await capture("08_manual_enemy_controls")
	level.set_enemies_enabled(false)
	await tick(4)
	check(get_nodes_in_group("zombies").is_empty(), "OFF clears review-session enemies")
	check(level.spawn_review_enemies(5) == 0, "OFF prevents further spawning")
	gun.enabled = was_enabled
	player.equip_test_weapon(0)
	level.reset_player()
	await tick(60)
	await profile("gameplay_mobile_profile")
	# Whole-map camera is only a test view; the delivered gameplay camera remains unchanged.
	level.set_process(false)
	var camera: Camera3D = level.get_node("Camera3D")
	camera.size = 72
	camera.far = 180
	camera.position = Vector3(45, 61, 60)
	for node in level.vegetation: node.visibility_range_end = 0.0
	await tick(12)
	await capture("09_whole_map_overview")
	await profile("whole_map_mobile_profile")
	level.set_graphics_quality(true)
	for node in level.vegetation: node.visibility_range_end = 0.0
	await tick(12)
	await capture("10_detail_quality_overview")
	level.set_graphics_quality(false)
	observations["failures"] = failures
	observations["renderer"] = RenderingServer.get_current_rendering_method()
	observations["device"] = RenderingServer.get_video_adapter_name()
	observations["resolution"] = root.size
	observations["note"] = "Warm desktop Mobile-renderer samples at real-time playback, no fixed-fps acceleration or capture readback during sample windows; overview culling limits disabled to include all vegetation. Physical phone performance remains unmeasured."
	FileAccess.open(out + "/review_report.json", FileAccess.WRITE).store_string(JSON.stringify(observations, "\t"))
	print("E2_RENDERED_REVIEW " + JSON.stringify(observations))
	quit(0 if failures.is_empty() else 1)
