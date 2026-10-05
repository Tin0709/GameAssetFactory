extends SceneTree
## Real spawning/physics/progression integration and rendered 5-vs-40 stress sample.
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
var level: Node3D
var player: CharacterBody3D
var combat: Node
var spawner: Node
var progression: Node
var checks := 0
var failed := false
var metrics := {}
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("SPAWN TEST FAILED: " + message)
func tick(count: int) -> void:
	for i in range(count): await physics_frame
func fresh() -> void:
	paused = false
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = LEVEL.instantiate()
	level.get_node("Actors/Player/Pistol").enabled = false
	root.add_child(level)
	current_scene = level
	player = level.get_node("Actors/Player")
	combat = level.get_node("Combat")
	spawner = level.get_node("SpawnDirector")
	progression = level.get_node("Progression")
	for enemy in combat.living_zombies: enemy.set_physics_process(false)
	await tick(3)
func freeze_enemies() -> void:
	for enemy in combat.living_zombies: enemy.set_physics_process(false)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	await fresh()
	check(combat.living_zombies.size() == 5 and spawner.total_spawned == 5, "Director seeds five, no fixed zombie instances")
	check(combat.kill_count == 0 and player.level == 1 and player.experience == 0, "Initial kill/progression state")
	check(spawner.elapsed_survival > 0 and spawner.elapsed_survival < 0.10, "Survival clock starts from zero")
	var space := player.get_world_3d().direct_space_state
	for enemy in combat.living_zombies:
		var point: Vector3 = enemy.position
		check(absf(point.x) <= 7.151 and absf(point.z) <= 5.351 and (is_equal_approx(absf(point.x), 7.15) or is_equal_approx(absf(point.z), 5.35)), "Perimeter spawn inside safe floor")
		check(point.distance_to(player.position) >= spawner.player_clearance, "Spawn clears player")
		check(enemy.chasing and enemy.persistent_chase and enemy.target == player and enemy.current_hp == enemy.max_hp, "Spawn ready to chase with full scaled HP")
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = enemy.get_node("CollisionShape3D").shape
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 0.9, 0))
		query.collision_mask = 1
		check(space.intersect_shape(query, 4).is_empty(), "Spawn capsule does not intersect arena walls/floor")
	spawner.rng.seed = 77
	var point_a: Vector3 = spawner.find_spawn_position()
	var interval_a: float = spawner.next_interval()
	spawner.rng.seed = 77
	check(spawner.find_spawn_position().is_equal_approx(point_a) and is_equal_approx(spawner.next_interval(), interval_a), "Seed reproduces candidate and timing")
	spawner.elapsed_survival = 0
	check(is_equal_approx(spawner.current_interval(), 1.6) and spawner.initial_active_target == 5, "Initial curve tuning")
	spawner.elapsed_survival = 150
	check(is_equal_approx(spawner.current_interval(), 1.05), "Interval halfway through ramp")
	spawner.elapsed_survival = 300
	var stats: Dictionary = spawner.difficulty_stats()
	check(is_equal_approx(spawner.current_interval(), 0.5) and spawner.max_active_zombies == 40, "Five-minute pressure plateau")
	check(stats.hp == 84 and stats.damage == 13 and is_equal_approx(stats.speed, 2.3575), "Five-minute modest stat scaling")
	spawner.elapsed_survival = 1200
	check(spawner.difficulty_stats().speed == 2.75 and spawner.current_interval() == 0.5, "Normal speed and interval clamp")
	var scaled: CharacterBody3D = spawner.spawn_one()
	check(scaled.max_hp == 156 and scaled.current_hp == 156 and scaled.attack_damage == 20 and scaled.move_speed == 2.75, "Stats applied before ready to newly spawned zombie")
	check(minf(scaled.speed_limit, scaled.move_speed * scaled.speed_multiplier) <= 2.75, "Variation cannot exceed actual speed limit")
	scaled.set_physics_process(false)
	spawner.elapsed_survival = 0
	var first: CharacterBody3D = combat.living_zombies[0]
	check(first.max_hp == 60 and first.attack_damage == 10, "Existing enemies keep their spawn-time stats")
	# Persistent pursuit even beyond the old detection/loss radius.
	player.position = Vector3(-7, 0.01, -5)
	first.position = Vector3(7.15, 0.02, 5.35)
	first.set_physics_process(true)
	var distance := first.position.distance_to(player.position)
	await tick(20)
	check(first.chasing and first.position.distance_to(player.position) < distance - 0.3, "Perimeter enemies pursue across whole arena")
	await fresh()
	# Initial pressure refills deaths at the regular scheduled beat.
	first = combat.living_zombies[0]
	first.take_damage(60)
	check(combat.kill_count == 1 and combat.living_zombies.size() == 4, "Death increments kill count and releases active slot immediately")
	combat.enemy_death_started(first)
	check(combat.kill_count == 1, "Repeated death notification does not duplicate kill")
	await tick(190)
	check(spawner.total_spawned > 5 and combat.living_zombies.size() >= 5, "Continuous spawning refills killed enemy")
	freeze_enemies()
	spawner.pair_chance = 1.0
	spawner.spawn_remaining = 0
	var before_pair: int = combat.living_zombies.size()
	await tick(1)
	check(combat.living_zombies.size() == before_pair + 2, "Scheduled pair adds two enemies")
	check(combat.living_zombies[-1].position.distance_to(combat.living_zombies[-2].position) < 2.1, "Pair spawns near each other")
	freeze_enemies()
	spawner.pair_chance = 0.18
	spawner.calm_gap_chance = 1.0
	check(spawner.next_interval() >= spawner.current_interval() * (1.0 - spawner.timing_variance) * spawner.calm_gap_multiplier - 0.001, "Calmer gap extends scheduled interval")
	spawner.calm_gap_chance = 0.10
	# Player moving near four corners never causes unsafe spawn placement.
	for corner in [Vector3(7.2, 0.01, 5.4), Vector3(-7.2, 0.01, 5.4), Vector3(-7.2, 0.01, -5.4), Vector3(7.2, 0.01, -5.4)]:
		player.position = corner
		var enemy: CharacterBody3D = spawner.spawn_one()
		check(enemy != null and enemy.position.distance_to(player.position) >= spawner.player_clearance, "Spawn excludes moving player's corner")
		enemy.set_physics_process(false)
	# Hard cap is enforced even on manual batches/pairs and at high difficulty.
	player.position = Vector3.ZERO
	for i in range(50):
		var enemy: Node3D = spawner.spawn_one()
		if enemy != null: enemy.set_physics_process(false)
	check(combat.living_zombies.size() == 40, "Forty-enemy hard cap reached")
	check(spawner.spawn_one() == null and spawner.debug_spawn(10) == 0, "Normal and debug paths obey cap")
	spawner.elapsed_survival = 300
	spawner.spawn_remaining = 0
	var spawned_before: int = spawner.total_spawned
	await tick(10)
	check(combat.living_zombies.size() == 40 and spawner.total_spawned == spawned_before, "Cap prevents scheduled over-spawn")
	var victim: CharacterBody3D = combat.living_zombies[0]
	victim.take_damage(victim.current_hp)
	check(combat.living_zombies.size() == 39, "Killing at cap frees a slot")
	spawner.spawn_remaining = 0
	await tick(2)
	check(combat.living_zombies.size() == 40, "Scheduled spawn resumes immediately on next beat after cap slot opens")
	freeze_enemies()
	# Disappearing actors must not leave stale registry references or count as kills.
	var kills: int = combat.kill_count
	victim = combat.living_zombies[0]
	victim.queue_free()
	await process_frame
	check(combat.living_zombies.size() == 39 and combat.kill_count == kills, "Tree-exit cleanup removes reference without false kill")
	# Saturation or bad tuning returns failure safely, never an origin spawn.
	var clearance: float = spawner.player_clearance
	spawner.player_clearance = 100
	check(spawner.spawn_one() == null and spawner.failed_spawn_attempts > 0, "Bounded rejection handles no valid candidates")
	spawner.player_clearance = clearance
	await fresh()
	# Three real kills and pickups trigger upgrade while spawning is enabled.
	var victims: Array = combat.living_zombies.slice(0, 3)
	for enemy in victims:
		enemy.position = Vector3(2, 0.02, 0)
		enemy.take_damage(60)
	await tick(42)
	player.position = Vector3(2, 0.01, 0)
	await tick(16)
	check(paused and progression.selection_open and player.level == 2 and combat.kill_count == 3, "EXP/level-up integrates with continuous director")
	var elapsed: float = spawner.elapsed_survival
	var remaining: float = spawner.spawn_remaining
	spawned_before = spawner.total_spawned
	await tick(45)
	check(spawner.elapsed_survival == elapsed and spawner.spawn_remaining == remaining and spawner.total_spawned == spawned_before, "Upgrade freezes time, spawn countdown and counts")
	check(spawner.debug_spawn(10) == 0, "Debug spawn cannot bypass upgrade pause")
	progression.select_upgrade(0)
	await create_timer(0.16, true).timeout
	await tick(190)
	freeze_enemies()
	check(not paused and spawner.elapsed_survival > elapsed + 2 and spawner.total_spawned > spawned_before, "Selection resumes timer and spawning without catch-up burst")
	# Otherwise paused and defeated states stop director independently.
	paused = true
	elapsed = spawner.elapsed_survival
	await tick(10)
	check(spawner.elapsed_survival == elapsed and spawner.spawn_one() == null, "External pause honored")
	paused = false
	player.hurt_remaining = 0.0
	player.take_damage(10000)
	elapsed = spawner.elapsed_survival
	spawned_before = spawner.total_spawned
	await tick(90)
	check(player.is_dead and spawner.elapsed_survival == elapsed and spawner.total_spawned == spawned_before and spawner.debug_spawn(10) == 0, "Defeat stops time, scheduled and debug spawning")
	await key(KEY_R)
	await tick(3)
	level = current_scene
	player = level.get_node("Actors/Player")
	combat = level.get_node("Combat")
	spawner = level.get_node("SpawnDirector")
	progression = level.get_node("Progression")
	check(not paused and player.current_hp == 100 and player.level == 1 and player.experience == 0 and combat.kill_count == 0, "Reset restores player/progression/kill state")
	check(spawner.elapsed_survival < 0.2 and spawner.total_spawned == 5 and combat.living_zombies.size() == 5 and spawner.current_interval() > 1.59, "Reset restores clock, initial enemies and difficulty")
	check(combat.projectiles.get_child_count() == 0 and combat.effects.get_child_count() == 0 and combat.pickups.get_child_count() == 0, "Reset clears projectiles/effects/drops")
	player.get_node("Pistol").enabled = false
	freeze_enemies()
	await key(KEY_K)
	check(combat.living_zombies.size() == 6, "Debug K spawns one")
	await key(KEY_J)
	check(combat.living_zombies.size() == 16, "Debug J spawns ten")
	freeze_enemies()
	# Multiple spawn/death rounds verify registry and actor cleanup.
	spawner.set_physics_process(false)
	var total_killed := 0
	for round_index in range(3):
		for enemy in combat.living_zombies.duplicate():
			enemy.take_damage(enemy.current_hp)
			total_killed += 1
		await tick(42)
		check(combat.living_zombies.is_empty() and get_nodes_in_group("zombies").is_empty(), "Repeated deaths leave no stale registry/actor references")
		if round_index < 2:
			spawner.debug_spawn(10)
			freeze_enemies()
	check(combat.kill_count == total_killed and combat.pickups.get_child_count() == total_killed, "Repeated deaths count kills and exactly one EXP each")
	metrics.repeated_kills = total_killed
	# Actual rendered combat stress, with a high-HP fixture player and no damage suppression.
	if "--capture" in OS.get_cmdline_user_args():
		await fresh()
		player.max_hp = 1000000
		player.current_hp = player.max_hp
		for enemy in combat.living_zombies: enemy.set_physics_process(true)
		spawner.spawn_remaining = 100.0
		await create_timer(2.0).timeout
		metrics.baseline_fps = Engine.get_frames_per_second()
		metrics.baseline_draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		spawner.spawn_remaining = 0.0
		spawner.debug_spawn(35)
		check(combat.living_zombies.size() == 40, "Rendered stress has forty live zombies")
		await create_timer(2.0).timeout
		metrics.stress_fps_samples = []
		metrics.stress_process_ms = []
		metrics.stress_physics_ms = []
		for i in range(6):
			await create_timer(1.0).timeout
			metrics.stress_fps_samples.append(Engine.get_frames_per_second())
			metrics.stress_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			metrics.stress_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		check(metrics.stress_fps_samples.min() >= metrics.baseline_fps * 0.8, "Forty enemies avoid major desktop FPS regression")
		metrics.stress_draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		metrics.stress_alive = combat.living_zombies.size()
		check(combat.living_zombies.size() == 40 and not player.is_dead, "Stress keeps all forty pursuing/attacking")
		check(RenderingServer.get_current_rendering_method() == "mobile", "Stress uses actual Mobile renderer")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/spawn_stress_40.png")
		# Real movement/autofire with pressure and upgrades after the stress fixture.
		await fresh()
		player.get_node("Pistol").enabled = true
		for enemy in combat.living_zombies: enemy.set_physics_process(true)
		Input.action_press("move_left")
		await tick(35)
		Input.action_release("move_left")
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/spawn_gameplay.png")
	metrics.passed = not failed
	metrics.checks = checks
	metrics.phone_tested = false
	metrics.engine = Engine.get_version_info().string
	metrics.renderer = RenderingServer.get_current_rendering_method()
	var suffix := "rendered" if "--capture" in OS.get_cmdline_user_args() else "headless"
	FileAccess.open("res://tests/spawn_" + suffix + "_validation.json", FileAccess.WRITE).store_string(JSON.stringify(metrics, "\t"))
	print("SPAWN VALIDATION: %d checks; passed=%s; %s" % [checks, not failed, JSON.stringify(metrics)])
	paused = false
	level.queue_free()
	current_scene = null
	await process_frame
	await create_timer(0.15, true).timeout
	quit(1 if failed else 0)
