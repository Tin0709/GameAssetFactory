extends SceneTree

const LAB = preload("res://scenes/dev/MechanicLab.tscn")
const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")
const COUNT := 100
var lab: Node3D
var tick_started := 0
var frame_started := 0
var physics_ms: Array[float] = []
var frame_ms: Array[float] = []
var render_gpu_ms: Array[float] = []
var draws: Array[float] = []
var active_peak := 0
var first_tick_ragdolls := 0
var peak_damage_glyphs := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	lab = LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	root.size = Vector2i(960, 540)
	root.msaa_3d = Viewport.MSAA_DISABLED
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	physics_frame.connect(func(): tick_started = Time.get_ticks_usec())
	process_frame.connect(func():
		var now := Time.get_ticks_usec()
		if frame_started > 0:
			frame_ms.append((now - frame_started) / 1000.0)
			if tick_started > frame_started:
				physics_ms.append((now - tick_started) / 1000.0)
		frame_started = now
		render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	await measure("empty", 90)
	var group := lab.get_node("Zombies")
	var verify_spawn := func(zombie: Node): check_spawn_spacing(group, zombie)
	group.child_entered_tree.connect(verify_spawn)
	if OS.get_cmdline_user_args().has("--sync-spawn"):
		spawn_synchronously(group)
	else:
		await spawn_crowd(group)
	group.child_entered_tree.disconnect(verify_spawn)
	if group.get_child_count() != COUNT:
		printerr("Could not spawn all ", COUNT, " zombies: ", failures)
		quit(1)
		return
	await measure("spawn_animation", 70)
	await check_health_bars(group)
	Input.action_press("move_backward")
	await measure("chase", 120)
	Input.action_release("move_backward")
	await check_crowd_melee(group)
	await check_blocked_chase(group)
	# Give each corpse clear room to complete its authored handoff and roll.
	for i in COUNT:
		var zombie = group.get_child(i)
		zombie.global_position = Vector3(i % 10 * 4.0 - 18.0, 0.02, int(i / 10) * 4.0 - 18.0)
		zombie.velocity = Vector3.ZERO
		zombie.reset_physics_interpolation()
		zombie.take_hit(100, Vector3.RIGHT, Vector2.ZERO, 0.0, 1150.0, ZOMBIE.DeathStrike.SABRE_FINISHER)
	var bars := group.get_node_or_null("../ZombieHealthBars") as MultiMeshInstance3D
	if bars != null and bars.multimesh.visible_instance_count != 0:
		failures.append("A lethal hit immediately removes the zombie's overhead bar")
	await measure("simultaneous_ragdolls", 120, group)
	if active_peak != COUNT or first_tick_ragdolls != COUNT:
		failures.append("Expected all 100 ragdolls to run together")
	var numbers := lab.get_node_or_null("CombatEffects/ZombieDamageNumbers") as MultiMeshInstance3D
	if numbers == null or peak_damage_glyphs != COUNT * 3:
		failures.append("The batched numbers render all 300 glyphs of the simultaneous hits")
	elif numbers.multimesh.visible_instance_count != 0:
		failures.append("The batched damage numbers expire")
	await measure("corpse_cleanup", 200, group)
	if bars != null and bars.multimesh.visible_instance_count != 0:
		failures.append("The batch drops the bars of despawned zombies")
	var clean := group.get_child_count() == 0
	if not clean:
		failures.append("Corpses remain after the cleanup window")
	if not OS.get_cmdline_user_args().has("--sync-spawn"):
		await check_reset_during_spawn(group)
	print("CROWD_END failures=", failures, " renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name())
	lab.free()
	quit(0 if failures.is_empty() else 1)

func spawn_synchronously(group: Node) -> void:
	var spawn := lab.get_node("HUD/SpawnZombie") as Button
	var started := Time.get_ticks_usec()
	for i in COUNT:
		spawn.pressed.emit()
	print("CROWD_SPAWN_SYNC ", JSON.stringify({"count": group.get_child_count(),
		"burst_ms": (Time.get_ticks_usec() - started) / 1000.0}))

func spawn_crowd(group: Node) -> void:
	var button := lab.get_node_or_null("HUD/SpawnCrowd") as Button
	if button == null or not button.is_visible_in_tree() or button.disabled:
		failures.append("The Lab provides an enabled crowd spawn control")
		return
	var base_health := lab.get_node("HUD/BaseZombieToggle") as CheckButton
	base_health.button_pressed = true
	frame_ms.clear()
	var started := Time.get_ticks_usec()
	button.pressed.emit()
	var immediate_count := group.get_child_count()
	base_health.button_pressed = false
	var previous_count := immediate_count
	var largest_batch := 0
	var frames := 0
	while group.get_child_count() < COUNT and frames < 120:
		await process_frame
		var count := group.get_child_count()
		largest_batch = maxi(largest_batch, count - previous_count)
		previous_count = count
		frames += 1
		if frames == 1:
			button.pressed.emit()
	if immediate_count != 0 or largest_batch < 1 or largest_batch > 5:
		failures.append("Crowd spawn should pace allocation over process frames")
	if button.disabled or group.get_child_count() != COUNT:
		failures.append("One crowd request should finish and reenable its button")
	if not group.get_children().all(func(zombie): return zombie.max_health == ZOMBIE.BASE_HEALTH):
		failures.append("The crowd uses the HP mode selected when the request began")
	for i in 3:
		await process_frame
	if group.get_child_count() != COUNT:
		failures.append("A repeated click during an active crowd should not queue another crowd")
	print("CROWD_SPAWN_PACED ", JSON.stringify({"count": group.get_child_count(),
		"frames": frames, "largest_batch": largest_batch, "wall_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"frame_ms": stats(frame_ms)}))

func check_health_bars(group: Node) -> void:
	var batch := group.get_node_or_null("../ZombieHealthBars") as MultiMeshInstance3D
	if batch == null:
		failures.append("MechanicLab batches its overhead health bars")
		return
	if batch.multimesh.visible_instance_count != COUNT:
		failures.append("All 100 living zombies have an overhead health bar")
	var first = group.get_child(0)
	var second = group.get_child(1)
	var first_slot: int = first._feedback.bar_slot
	var second_slot: int = second._feedback.bar_slot
	first.take_hit(1, Vector3.RIGHT, Vector2.ZERO, 0.0)
	await process_frame
	await process_frame
	# The dummy renderer does not store the instance transforms or custom data.
	var headless := DisplayServer.get_name() == "headless"
	var first_bar: Color = batch._fills[first_slot] if headless else batch.multimesh.get_instance_custom_data(first_slot)
	var second_bar: Color = batch._fills[second_slot] if headless else batch.multimesh.get_instance_custom_data(second_slot)
	var expected := float(first.health) / float(first.max_health)
	if not is_equal_approx(first_bar.r, expected) or not is_equal_approx(first_bar.g, 1.0) \
			or not is_equal_approx(second_bar.r, 1.0):
		failures.append("Expected independent hit and delayed fills: got %s and %s" % [first_bar, second_bar])
	var position: Vector3 = batch._positions[first_slot] if headless else batch.multimesh.get_instance_transform(first_slot).origin
	var centre := batch.to_global(position)
	if centre.distance_to(first.global_position + Vector3.UP * 2.16) > 0.15:
		failures.append("Expected the bar to follow the zombie: got %s above %s" % [centre, first.global_position])
	for i in 20:
		await process_frame
	first_bar = batch._fills[first_slot] if headless else batch.multimesh.get_instance_custom_data(first_slot)
	if not is_equal_approx(first_bar.g, expected):
		failures.append("The delayed fill catches up to the target's current health")

func check_crowd_melee(group: Node) -> void:
	# Let the crowd keep attacking over the entire measurement window.
	const FIXTURE_HP := 10000
	lab.player_health = FIXTURE_HP
	var attacks: Array[int] = []
	var record_hit := func(amount: int): attacks.append(amount)
	group.player_hit.connect(record_hit)
	await measure("crowd_melee", 300)
	group.player_hit.disconnect(record_hit)
	if group.get_child_count() != COUNT or attacks.size() < 20 or lab.player_health != FIXTURE_HP - attacks.size() * 6:
		failures.append("The packed crowd keeps attacking at the verified six HP per hit")
	print("CROWD_MELEE_HITS ", attacks.size())
	lab.reset_player()

func check_blocked_chase(group: Node) -> void:
	lab.reset_player()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 3.0, 0.2)
	collider.shape = shape
	wall.add_child(collider)
	lab.add_child(wall)
	wall.position = Vector3(0, 1, -2.0)
	var zombie = group.get_child(0)
	for i in group.get_child_count():
		var member = group.get_child(i)
		member.global_position = Vector3(12.0 + i % 10 * 2.0, 0.02, -15.0 + int(i / 10) * 2.0)
		member.velocity = Vector3.ZERO
		member.set_physics_process(i == 0)
	zombie.global_position = Vector3(0, 0.02, -3.5)
	zombie.animation.play(ZOMBIE.IDLE, 0.0)
	zombie.animation.advance(0.0)
	for i in 45:
		await physics_frame
	var samples: int = zombie.ragdoll.sample_count
	var last_position: Vector3 = zombie.global_position
	var skipped_ticks := 0
	for i in 30:
		await physics_frame
		if zombie.get("_skipped_blocked_step") == true:
			skipped_ticks += 1
	var pose_steps: int = zombie.ragdoll.sample_count - samples
	if skipped_ticks < 14 or skipped_ticks > 16 or pose_steps != 30 \
			or zombie.global_position.distance_to(last_position) > 0.02:
		failures.append("A blocked crowd zombie should alternate collision checks and retain every pose sample")
	wall.free()
	for i in 16:
		await physics_frame
	if zombie.global_position.z <= last_position.z + 0.4:
		failures.append("A blocked zombie did not resume when the wall was removed")
	var blocker := group.get_child(1) as ZOMBIE
	blocker.global_position = Vector3(0, 0.02, -2.0)
	zombie.global_position = Vector3(0, 0.02, -3.5)
	zombie.velocity = Vector3.ZERO
	for i in 45:
		await physics_frame
	samples = zombie.ragdoll.sample_count
	last_position = zombie.global_position
	var packed_skips := 0
	for i in 40:
		await physics_frame
		packed_skips += int(zombie.get("_skipped_blocked_step") == true)
	if packed_skips < 29 or packed_skips > 31 or zombie.ragdoll.sample_count - samples != 40:
		failures.append("A crowd zombie blocked by another zombie retries at 15 Hz and samples every tick")
	blocker.global_position.x += 3.0
	await physics_frame
	await process_frame
	if zombie.global_position.z <= last_position.z + 0.01:
		failures.append("Moving the blocking zombie wakes the chaser on the next tick")
	for member in group.get_children():
		member.set_physics_process(true)
	print("CROWD_BLOCKED wall_skips=", skipped_ticks, " samples=", pose_steps, " packed_skips=", packed_skips)

func check_reset_during_spawn(group: Node) -> void:
	var button := lab.get_node("HUD/SpawnCrowd") as Button
	button.pressed.emit()
	for i in 3:
		await process_frame
	var partial := group.get_child_count()
	lab.reset_player()
	for i in 5:
		await process_frame
	if partial <= 0 or partial >= COUNT or group.get_child_count() != partial or button.disabled:
		failures.append("Reset cancels pending spawns and preserves zombies already created")
	button.pressed.emit()
	for i in 3:
		await process_frame
	partial = group.get_child_count()
	lab._on_player_hit(100)
	for i in 5:
		await process_frame
	if group.get_child_count() != partial or not button.disabled:
		failures.append("Defeat stops the crowd and disables spawning another crowd")
	lab.reset_player()
	if button.disabled:
		failures.append("Retry re-enables crowd spawning")
	var single := lab.get_node("HUD/SpawnZombie") as Button
	single.pressed.emit()
	if group.get_child_count() != partial + 1:
		failures.append("The single-spawn button still creates exactly one zombie immediately")

func check_spawn_spacing(group: Node, zombie: Node3D) -> void:
	var point := zombie.position
	if absf(point.x) > 49.0 or absf(point.z) > 49.0:
		failures.append("Zombie spawned outside the lab bounds")
		return
	for other in group.get_children():
		if other == zombie or other.health <= 0:
			continue
		if point.distance_squared_to(other.position) < 1.25 * 1.25:
			failures.append("Zombie spawned too close to another living zombie")
			return

func measure(label: String, ticks: int, group: Node = null) -> void:
	frame_ms.clear()
	physics_ms.clear()
	render_gpu_ms.clear()
	draws.clear()
	active_peak = 0
	var numbers := lab.get_node_or_null("CombatEffects/ZombieDamageNumbers") as MultiMeshInstance3D
	for i in ticks:
		await physics_frame
		if group != null:
			var active := 0
			for zombie in group.get_children():
				if zombie.ragdoll.running:
					active += 1
			if label == "simultaneous_ragdolls" and i == 1:
				first_tick_ragdolls = active
			active_peak = maxi(active_peak, active)
			if label == "simultaneous_ragdolls" and numbers != null:
				peak_damage_glyphs = maxi(peak_damage_glyphs, numbers.multimesh.visible_instance_count)
	print("CROWD_PHASE ", JSON.stringify({"phase": label, "frame_ms": stats(frame_ms),
		"physics_to_process_ms": stats(physics_ms), "gpu_ms": stats(render_gpu_ms),
		"draws": stats(draws), "samples": frame_ms.size(), "active_ragdolls_peak": active_peak}))

func stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {}
	var sorted := samples.duplicate()
	sorted.sort()
	return {"p50": sorted[sorted.size() / 2], "p95": sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)],
		"max": sorted.back()}
