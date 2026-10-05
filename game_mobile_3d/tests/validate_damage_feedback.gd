extends SceneTree
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
const FIXTURE = preload("res://tests/legacy_fixture.gd")
const NUMBER = preload("res://scripts/damage_number.gd")
const SMOKE = preload("res://scripts/zombie_death_smoke.gd")
var checks := 0
var failures: Array[String] = []
var level: Node3D
var combat: Node
var player: CharacterBody3D
var rendered := false
var benchmark := {}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int) -> void:
	for i in count: await physics_frame

func effects(script: Script) -> Array:
	return combat.effects.get_children().filter(func(node): return node.get_script() == script and not node.is_queued_for_deletion())

func fresh() -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = LEVEL.instantiate()
	FIXTURE.prepare(level)
	level.get_node("Actors/Player/Pistol").enabled = false
	root.add_child(level)
	current_scene = level
	combat = level.get_node("Combat")
	player = combat.player
	for zombie in combat.living_zombies: zombie.set_physics_process(false)
	await tick(2)

func capture(label: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://tests/damage_feedback_%s.png" % label) == OK, "Capture " + label)

func measure_frames(active_feedback: bool) -> Dictionary:
	var cpu_ms := 0.0
	var physics_ms := 0.0
	var draws := 0.0
	var started := Time.get_ticks_usec()
	for frame in 90:
		if active_feedback and frame % 15 == 0:
			for enemy in combat.living_zombies: enemy.take_damage(1)
		await RenderingServer.frame_post_draw
		cpu_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return {"process_ms": cpu_ms / 90, "physics_ms": physics_ms / 90, "draw_calls": draws / 90,
		"wall_fps": 90000000.0 / (Time.get_ticks_usec() - started)}

func performance_sample() -> void:
	await fresh()
	for enemy in combat.living_zombies.duplicate():
		combat.living_zombies.erase(enemy)
		enemy.queue_free()
	await process_frame
	for i in 40:
		var enemy := ZOMBIE.instantiate()
		enemy.max_hp = 10000 # Test-only longevity; runtime stats are untouched.
		enemy.position = Vector3(float(i % 8) - 3.5, 0.02, float(i / 8) - 2)
		level.get_node("Actors").add_child(enemy)
		enemy.set_physics_process(false)
		combat.register_zombie(enemy)
		# Warm shader compilation and font glyphs before measurements.
		enemy.take_damage(1)
	await tick(120)
	# Isolate visual cost from repeated compressed-audio playback in this stress sample.
	combat.audio.minimum_event_interval = 1000000.0
	benchmark = {"actors": 40, "frames_per_sample": 90, "gpu": RenderingServer.get_video_adapter_name()}
	benchmark["baseline"] = await measure_frames(false)
	benchmark["rapid_hits"] = await measure_frames(true)
	await tick(120)
	benchmark["recovered"] = await measure_frames(false)
	check(effects(NUMBER).is_empty() and combat.living_zombies.all(func(enemy): return not enemy.damage_feedback.bar.visible), "40-actor benchmark recovers without orphaned UI")

func _run() -> void:
	rendered = "--capture" in OS.get_cmdline_user_args()
	await fresh()
	var first: CharacterBody3D = combat.living_zombies[0]
	var second: CharacterBody3D = combat.living_zombies[1]
	check(first.damage_feedback.bar == null and player.damage_feedback.bar == null, "Bars allocated only on first damage")
	var material = first.visual.meshes[0].mesh.surface_get_material(0)
	check(not first.take_damage(0) and effects(NUMBER).is_empty(), "Rejected damage emits no number")
	first.take_damage(20, Vector3.RIGHT)
	check(first.current_hp == 40 and effects(NUMBER).size() == 1, "One accepted hit emits exactly one number")
	check(effects(NUMBER)[0].text == "20", "Integer damage label")
	check(first.knockback.length() > 0 and (not rendered or combat.audio.players[&"zombie_hit"].playing), "Knockback/audio retained (audio intentionally disabled headless)")
	check(first.damage_feedback.bar.get_instance_shader_parameter("health_ratio") == float(40) / 60, "Fill responds immediately")
	check(first.damage_feedback.bar.visible and first.damage_feedback.bar.global_position.y > first.global_position.y + 1.8, "Bar above head")
	for mesh in first.visual.meshes:
		check(mesh.material_overlay != null and mesh.get_instance_shader_parameter("hit_strength") == 1.0, "Whole actor flashes")
	check(second.visual.meshes[0].material_overlay == null and second.damage_feedback.bar == null, "Unhit actor independent")
	await tick(4)
	var strength: float = first.visual.meshes[0].get_instance_shader_parameter("hit_strength")
	check(strength > 0.0 and strength < 1.0, "Flash fades smoothly")
	await tick(5)
	check(first.visual.meshes[0].material_overlay == null and first.visual.meshes[0].mesh.surface_get_material(0) == material, "Original textured material restored")
	await tick(40)
	check(effects(NUMBER).is_empty(), "Numbers clean up by 0.8s")
	await tick(25)
	first.take_damage(5)
	check(first.damage_feedback.remaining > 1.49, "Repeated hit refreshes timeout")
	var bar_id: int = first.damage_feedback.bar.get_instance_id()
	first.take_damage(5)
	check(first.damage_feedback.bar.get_instance_id() == bar_id and effects(NUMBER).size() == 2, "Rapid hits reuse bar and emit once each")
	await tick(82)
	check(first.damage_feedback.bar.visible and float(first.damage_feedback.bar.get_instance_shader_parameter("bar_opacity")) < 1.0, "Bar fades near end of 1.5s")
	await tick(12)
	check(not first.damage_feedback.bar.visible and not first.damage_feedback.is_processing(), "Timeout hides UI and stops processing")

	# Shared real swept projectile path with each selected model/recoil category.
	for weapon in 3:
		await fresh()
		player.equip_test_weapon(weapon)
		first = combat.living_zombies[0]
		first.position = Vector3(1.0, 0.01, 0)
		for other in combat.living_zombies.slice(1): other.position = Vector3(-6, 0.01, -4)
		await tick(2)
		combat.fire(Vector3(0, 1.02, 0), Vector3.RIGHT, player.get_node("Pistol").damage, 120, 0.9)
		await tick(2)
		check(first.current_hp == 40 and effects(NUMBER).size() == 1, "Weapon %d projectile produces one feedback event" % weapon)
		check(player.visual.recoil_time < 0.2, "Weapon %d recoil retained" % weapon)

	await fresh()
	player.equip_test_weapon(1)
	first = combat.living_zombies[0]
	first.position = Vector3(2, 0.01, 0)
	for other in combat.living_zombies.slice(1): other.position = Vector3(-9, 0.01, -5)
	var pistol: Node = player.get_node("Pistol")
	pistol.enabled = true
	await tick(92)
	check(first.is_dead and combat.kill_count == 1, "M4A1 automatic shared cadence kills once")
	pistol.enabled = false
	await tick(40)
	check(not is_instance_valid(first) and combat.pickups.get_child_count() == 1, "Automatic death/drop retained")
	await tick(45)
	check(effects(SMOKE).is_empty() and effects(NUMBER).is_empty(), "Automatic-fire transient cleanup")

	await fresh()
	player.take_damage(10)
	check(player.current_hp == 90 and effects(NUMBER).size() == 1 and effects(NUMBER)[0].player_hit, "Player warm number and overhead UI")
	check(level.get_node("HUD/Status").text.contains("HP 90/100") and (not rendered or combat.audio.players[&"player_hurt"].playing), "HUD and hurt audio retained (audio intentionally disabled headless)")
	check(not player.take_damage(10) and effects(NUMBER).size() == 1, "Grace-period rejected hit creates no duplicate")
	await tick(24)
	player.take_damage(10)
	check(player.current_hp == 80 and effects(NUMBER).size() == 2, "Repeated accepted player damage")
	check(not player.visual.frozen and player.damage_feedback.remaining > 1.49, "Feedback does not interrupt animation")
	# Pause through the actual level-up overlay; all feedback clocks freeze.
	level.get_node("Progression").debug_grant_level()
	var before: float = player.damage_feedback.remaining
	var number_time: float = effects(NUMBER)[0].elapsed
	for i in 12: await process_frame
	check(paused and player.damage_feedback.remaining == before and effects(NUMBER)[0].elapsed == number_time, "Level-up pause freezes effect clocks")
	level.get_node("Progression").select_upgrade(0)
	await tick(12)
	check(not paused and player.damage_feedback.remaining < before, "Level-up resumes effects")
	await tick(100)
	check(not player.damage_feedback.bar.visible and effects(NUMBER).is_empty(), "Player feedback finishes cleanly")

	await fresh()
	var camera: Camera3D = level.get_node("Camera3D")
	# Real isometric orientation; tighter framing for feedback inspection only.
	camera.size = 9.0
	player.position = Vector3(-2, 0.02, 0.8)
	for i in combat.living_zombies.size(): combat.living_zombies[i].position = Vector3(i * 1.7 - 0.4, 0.02, -0.5)
	for enemy in combat.living_zombies: enemy.take_damage(20)
	player.take_damage(10)
	await tick(1)
	check(effects(NUMBER).size() == 4, "Simultaneous hits belong to four distinct actors")
	await capture("hits")
	await tick(10)
	await capture("bars")
	camera.size = 14.5
	await capture("gameplay_scale")
	camera.size = 9.0
	var saved_transform := camera.transform
	camera.position = Vector3(-10, 10, 12)
	camera.look_at(Vector3(0, 1, 0))
	await capture("alternate_view")
	camera.transform = saved_transform
	first = combat.living_zombies[0]
	var death_position := first.global_position
	first.take_damage(40)
	check(first.is_dead and first.visual.flash_remaining > 0, "Final hit flash precedes collapse")
	check(not first.take_damage(10), "Dead actor rejects duplicate feedback")
	await tick(39)
	check(not is_instance_valid(first) and effects(SMOKE).size() == 1, "Smoke begins when existing death completes")
	if not effects(SMOKE).is_empty():
		var smoke = effects(SMOKE)[0]
		check(smoke.multimesh.instance_count == 8 and smoke.global_position.distance_to(death_position) < 1.2, "Eight cubes at captured fallen torso")
	check(combat.pickups.get_child_count() == 1 and combat.pickups.get_child(0).global_position.distance_to(death_position) < 0.3, "EXP remains at original death location")
	await tick(7)
	await capture("smoke")
	await tick(40)
	check(effects(SMOKE).is_empty(), "Smoke frees after 0.7s")

	# Many actors share geometry/materials, but retain independent state.
	await fresh()
	for enemy in combat.living_zombies.duplicate(): enemy.take_damage(60)
	await tick(90)
	var pickup_count: int = combat.pickups.get_child_count()
	var baseline_start := Time.get_ticks_usec()
	await tick(60)
	var baseline_usec := Time.get_ticks_usec() - baseline_start
	for i in 24:
		var enemy := ZOMBIE.instantiate()
		enemy.position = Vector3(float(i % 6) * 0.85 - 2, 0.02, float(i / 6) * 0.8 - 1.5)
		level.get_node("Actors").add_child(enemy)
		enemy.set_physics_process(false)
		combat.register_zombie(enemy)
		enemy.take_damage(20)
		enemy.take_damage(40)
	check(effects(NUMBER).size() == 48 and combat.living_zombies.is_empty(), "24 simultaneous deaths emit exactly 48 accepted-hit numbers")
	await tick(40)
	check(effects(SMOKE).size() == 24, "One smoke burst per death")
	await capture("many_deaths")
	var peak_draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	await tick(50)
	check(effects(NUMBER).is_empty() and effects(SMOKE).is_empty(), "Many consecutive deaths leave no transient effects")
	check(combat.pickups.get_child_count() == pickup_count + 24 and get_nodes_in_group("zombies").is_empty(), "All EXP drops and corpse cleanup retained")
	# Reset while feedback is active, exercising scene-owned cleanup.
	player.hurt_remaining = 0
	player.take_damage(10)
	var old_effects: Node = combat.effects
	level.reset_run()
	await process_frame
	await tick(3)
	level = current_scene
	combat = level.get_node("Combat")
	player = combat.player
	check(not is_instance_valid(old_effects) and effects(NUMBER).is_empty() and effects(SMOKE).is_empty(), "Reset removes previous feedback container")
	check(player.current_hp == 100 and player.damage_feedback.bar == null, "Reset restores clean HP and hidden overhead bar")
	if rendered and "--benchmark" in OS.get_cmdline_user_args(): await performance_sample()
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"renderer": RenderingServer.get_current_rendering_method(), "rendered": rendered,
		"stress_deaths": 24, "stress_smoke_pieces": 192, "peak_draw_calls": peak_draws,
		"baseline_60_physics_frames_usec": baseline_usec, "phone_tested": false,
		"desktop_benchmark": benchmark,
		"weapon_note": "All models retain existing shared automatic firing cadence/stats; no new rifle rate or shotgun pellet mechanics."}
	var output := FileAccess.open("res://tests/damage_feedback_%s_validation.json" % ("rendered" if rendered else "headless"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("DAMAGE FEEDBACK: %d checks, %d failures" % [checks, failures.size()])
	level.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
