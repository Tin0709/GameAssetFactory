extends SceneTree

const LAB = preload("res://scenes/dev/MechanicLab.tscn")
const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")
const COUNT := 100
const FIXTURE_HP := 10000
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
var late_active_ragdolls := 0
var chase_dust_peak := 0
var checked_corpse_fade := false
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	lab = LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	root.size = Vector2i(960, 540)
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
	print("CROWD_RENDER_SETUP viewport=", root.size, " msaa_3d=", root.msaa_3d,
		" renderer=", RenderingServer.get_current_rendering_method())
	await measure("empty", 90)
	# Spawning is paced by rendered frames. On slow renderers the earliest
	# zombies can finish their spawn and attack before the last batch appears.
	lab.player_health = FIXTURE_HP
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
	await check_zombie_dust()
	await check_crowd_melee(group)
	await check_blocked_chase(group)
	await check_crowd_windup_occlusion(group)
	await check_crowd_windup_range(group)
	var packed := OS.get_cmdline_user_args().has("--packed-ragdolls")
	await launch_ragdolls(group, packed)
	var bars := group.get_node_or_null("../ZombieHealthBars") as MultiMeshInstance3D
	if bars != null and bars.multimesh.visible_instance_count != 0:
		failures.append("A lethal hit immediately removes the zombie's overhead bar")
	await measure("simultaneous_ragdolls", 120, group)
	if active_peak != COUNT or first_tick_ragdolls != COUNT:
		failures.append("Expected all 100 ragdolls to run together")
	if not checked_corpse_fade:
		failures.append("The crowd never reached the corpse fade sample")
	var numbers := lab.get_node_or_null("CombatEffects/ZombieDamageNumbers") as MultiMeshInstance3D
	if numbers == null or peak_damage_glyphs != COUNT * 3:
		failures.append("The batched numbers render all 300 glyphs of the simultaneous hits")
	elif numbers.multimesh.visible_instance_count != 0:
		failures.append("The batched damage numbers expire")
	await measure("corpse_cleanup", 200, group)
	if packed:
		print("CROWD_PACKED_LATE_ACTIVE ", late_active_ragdolls)
		if late_active_ragdolls > 0:
			failures.append("Packed ragdolls beside the wall settle before they despawn")
	if bars != null and bars.multimesh.visible_instance_count != 0:
		failures.append("The batch drops the bars of despawned zombies")
	var clean := group.get_child_count() == 0
	if not clean:
		failures.append("Corpses remain after the cleanup window")
	if not OS.get_cmdline_user_args().has("--sync-spawn"):
		await check_reset_during_spawn(group)
		if OS.get_cmdline_user_args().has("--roam"):
			await check_crowd_roam(group)
	print("CROWD_END failures=", failures, " renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name())
	lab.free()
	quit(0 if failures.is_empty() else 1)

func check_crowd_roam(group: Node) -> void:
	for child in group.get_children():
		child.free()
	lab.reset_player()
	lab.player.set_physics_process(false)
	lab.get_node("HUD/SpawnCrowd").pressed.emit()
	for frame in 180:
		await process_frame
		if group.get_child_count() == COUNT:
			break
	lab.player.global_position = Vector3(34.0, 0.02, 34.0)
	var starts: PackedVector3Array = []
	for zombie: ZOMBIE in group.get_children():
		starts.append(zombie.global_position)
	await measure("crowd_roam", 300)
	var moved := 0
	var peak_radius := 0.0
	var outside := 0
	for i in group.get_child_count():
		var zombie := group.get_child(i) as ZOMBIE
		moved += int(zombie.global_position.distance_to(starts[i]) > 0.5)
		peak_radius = maxf(peak_radius, zombie.global_position.distance_to(zombie._roam_origin))
		outside += int(zombie._target_aggressive or not zombie.is_on_floor())
	if group.get_child_count() != COUNT or moved < 90 or peak_radius > 10.05 or outside != 0:
		failures.append("The 100-zombie patrol stays on the floor and moves within its spawn radius")
	print("CROWD_ROAM moved=", moved, " max_radius=", peak_radius, " chasing_or_off_floor=", outside)

func check_zombie_dust() -> void:
	var dust := lab.get_node_or_null("ZombieStepDust") as MultiMeshInstance3D
	if dust == null:
		failures.append("The Lab has one batched zombie step-dust renderer")
		return
	if chase_dust_peak == 0:
		failures.append("Actual chasing zombies emit dust on the grass")
	print("CROWD_ZOMBIE_DUST chase_peak=", chase_dust_peak)
	dust.clear()
	lab._on_zombie_step(Vector3(0.0, 2.0, 0.0))
	lab._on_zombie_step(Vector3(51.0, 0.0, 0.0))
	for i in COUNT:
		lab._on_zombie_step(Vector3(i % 10 - 4.5, 0.0, floori(i / 10.0) - 4.5))
	dust._process(0.0)
	if dust.multimesh.visible_instance_count != COUNT or dust.multimesh.mesh.get_surface_count() != 1:
		failures.append("One batch draws 100 grounded steps and rejects unsupported steps")
	dust.clear()
	if dust.multimesh.visible_instance_count != 0 or dust.is_processing():
		failures.append("Clearing the crowd dust removes all instances and stops processing")

func launch_ragdolls(group: Node, packed: bool) -> void:
	if packed:
		var wall := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.30, 3.0, 18.0)
		collider.shape = box
		wall.add_child(collider)
		wall.position = Vector3(4.5, 1.5, 0)
		lab.add_child(wall)
		await physics_frame
		await physics_frame
	var spacing := 0.9 if packed else 4.0
	var start := spacing * 4.5
	for i in COUNT:
		var zombie = group.get_child(i)
		zombie.global_position = Vector3(i % 10 * spacing - start, 0.02, int(i / 10) * spacing - start)
		zombie.velocity = Vector3.ZERO
		zombie.reset_physics_interpolation()
		if packed:
			# Start from the known idle pose and remove teleport velocity.
			zombie.rotation.y = atan2(-zombie.position.x, -zombie.position.z)
			zombie.animation.stop()
			zombie.ragdoll.skeleton.reset_bone_poses()
			zombie.animation.play(ZOMBIE.IDLE, 0.0)
			zombie.animation.advance(0.0)
			zombie.ragdoll.sample(1.0 / 60.0)
			zombie.ragdoll.sample(1.0 / 60.0)
		zombie.take_hit(100, Vector3.RIGHT, Vector2.ZERO, 0.0, 1150.0, ZOMBIE.DeathStrike.SABRE_FINISHER)

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
	# The dummy renderer does not store the instance transforms or custom data.
	# Read the hit state before a slow render frame can advance the delayed fill.
	var headless := DisplayServer.get_name() == "headless"
	var first_bar: Color = batch._fills[first_slot] if headless else batch.multimesh.get_instance_custom_data(first_slot)
	var second_bar: Color = batch._fills[second_slot] if headless else batch.multimesh.get_instance_custom_data(second_slot)
	var expected := float(first.health) / float(first.max_health)
	if not is_equal_approx(first_bar.r, expected) or not is_equal_approx(first_bar.g, 1.0) \
			or not is_equal_approx(second_bar.r, 1.0):
		failures.append("Expected independent hit and delayed fills: got %s and %s" % [first_bar, second_bar])
	await process_frame
	await process_frame
	var position: Vector3 = batch._positions[first_slot] if headless else batch.multimesh.get_instance_transform(first_slot).origin
	var centre := batch.to_global(position)
	if centre.distance_to(first.global_position + Vector3.UP * 2.16) > 0.15:
		failures.append("Expected the bar to follow the zombie: got %s above %s" % [centre, first.global_position])
	# The delayed fill runs on elapsed time, so a high render rate must
	# get the same time to settle as a 60 Hz run.
	await create_timer(0.30).timeout
	first_bar = batch._fills[first_slot] if headless else batch.multimesh.get_instance_custom_data(first_slot)
	if not is_equal_approx(first_bar.g, expected):
		failures.append("The delayed fill catches up to the target's current health")
	first.take_hit(2, Vector3.RIGHT, Vector2.ZERO, 0.0)
	var feedback = first._feedback
	var next_health := float(first.health) / float(first.max_health)
	feedback._process(0.22)
	var first_display: Color = batch._fills[first_slot]
	if not is_equal_approx(first_display.r, next_health) or not is_equal_approx(first_display.g, expected):
		failures.append("A hitch at contact preserves the delayed fill on its first displayed frame")
	feedback._process(0.10)
	feedback._process(0.05)
	var after_delay: Color = batch._fills[first_slot]
	if not is_equal_approx(after_delay.g, maxf(next_health, expected - 0.03 * 1.9)):
		failures.append("The delayed fill drains only for the elapsed portion after the hold")
	feedback._process(0.22)
	var settled: Color = batch._fills[first_slot]
	if not is_equal_approx(settled.g, next_health) or feedback.is_processing():
		failures.append("The delayed fill settles after a later hitch and stops updating")
	if not headless and not batch.multimesh.get_instance_custom_data(first_slot).is_equal_approx(settled):
		failures.append("The renderer receives the settled fill of the hit zombie")

func check_crowd_melee(group: Node) -> void:
	var starting_health: int = lab.player_health
	var attacks: Array[int] = []
	var record_hit := func(amount: int): attacks.append(amount)
	group.player_hit.connect(record_hit)
	await measure("crowd_melee", 300)
	group.player_hit.disconnect(record_hit)
	if group.get_child_count() != COUNT or attacks.size() < 20 or lab.player_health != starting_health - attacks.size() * 6:
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
	# Put a screen behind the blocker. Movement behind it should never
	# change the chaser's destination or wake its packed collision retries.
	var screen := StaticBody3D.new()
	var screen_shape := CollisionShape3D.new()
	screen_shape.shape = shape
	screen.add_child(screen_shape)
	screen.position = Vector3(0, 1, -1.0)
	lab.add_child(screen)
	var player: CharacterBody3D = lab.player
	var player_origin := player.global_position
	player.set_physics_process(false)
	for i in 8:
		await physics_frame
	var last_seen: Vector3 = zombie._last_seen_position
	var hidden_pose_start: int = zombie.ragdoll.sample_count
	var hidden_skips := 0
	for i in 32:
		player.global_position.x += -0.15 if i < 16 else 0.15
		await physics_frame
		hidden_skips += int(zombie._skipped_blocked_step)
	var hidden_poses: int = zombie.ragdoll.sample_count - hidden_pose_start
	if zombie._target_visible or not zombie._target_aggressive \
			or zombie._last_seen_position != last_seen or hidden_skips != 24 or hidden_poses != 32:
		failures.append("Hidden player movement keeps the last-seen destination, 15 Hz collision retries and every pose sample")
	print("CROWD_BLOCKED_HIDDEN skips=", hidden_skips, " samples=", hidden_poses, " last_seen=", zombie._last_seen_position)
	screen.free()
	player.global_position = player_origin
	player.set_physics_process(true)
	for i in 8:
		await physics_frame
	blocker.global_position.x += 3.0
	await physics_frame
	await physics_frame
	if zombie.get("_skipped_blocked_step") == true:
		failures.append("Moving the blocking zombie causes an immediate collision retry")
	await physics_frame
	if zombie.global_position.z <= last_position.z + 0.01:
		failures.append("The chaser resumes as soon as the physics space clears the blocker")
	for member in group.get_children():
		member.set_physics_process(true)
	print("CROWD_BLOCKED wall_skips=", skipped_ticks, " samples=", pose_steps, " packed_skips=", packed_skips)

func check_crowd_windup_occlusion(group: Node) -> void:
	var player: CharacterBody3D = lab.player
	player.set_physics_process(false)
	for member in group.get_children():
		member.set_physics_process(false)
	var zombie := group.get_child(0) as ZOMBIE
	zombie.global_position = player.global_position + Vector3.FORWARD * 1.34
	zombie.velocity = Vector3.ZERO
	zombie.rotation.y = 0.0
	zombie.animation.play(ZOMBIE.IDLE, 0.0)
	zombie.animation.advance(0.0)
	zombie._attack_cooldown = 1.0
	zombie.set_physics_process(true)
	for i in 5:
		await physics_frame
	if not zombie._target_visible or not zombie._target_aggressive:
		failures.append("The crowd windup fixture starts with a visible aggressive target")
	zombie.set_physics_process(false)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.15)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(player.global_position.x, 1.5, player.global_position.z - 0.67)
	lab.add_child(wall)
	for i in 3:
		await physics_frame
	var windups: Array[Vector3] = []
	var listen := func(point: Vector3, contact: bool):
		if not contact:
			windups.append(point)
	zombie.melee_audio.connect(listen)
	# Give the zombie one physics tick before its next scheduled sight ray.
	var stride := roundi(Engine.physics_ticks_per_second / ZOMBIE.LAB_CROWD_SIGHT_HZ)
	zombie._crowd_slot = (Engine.get_physics_frames() + 2) % stride
	zombie._attack_cooldown = 0.0
	zombie.set_physics_process(true)
	await physics_frame
	var hidden_windups := windups.size()
	if hidden_windups != 0 or zombie.animation.current_animation == ZOMBIE.ATTACK or zombie._attack_cooldown > 0.0:
		failures.append("A wall inserted between crowd sight checks prevents the windup and its sound")
	wall.free()
	for i in 12:
		await physics_frame
		if windups.size() > hidden_windups:
			break
	if windups.size() - hidden_windups != 1 or zombie.animation.current_animation != ZOMBIE.ATTACK:
		failures.append("The zombie starts one windup when the player's path is clear again")
	print("CROWD_OCCLUDED_WINDUP hidden=", hidden_windups, " visible=", windups.size() - hidden_windups)
	zombie.melee_audio.disconnect(listen)
	player.set_physics_process(true)
	for member in group.get_children():
		member.set_physics_process(true)

func check_crowd_windup_range(group: Node) -> void:
	var player: CharacterBody3D = lab.player
	var player_origin := player.global_position
	player.set_physics_process(false)
	for member in group.get_children():
		member.set_physics_process(false)
	var zombie := group.get_child(0) as ZOMBIE
	var windups: Array[Vector3] = []
	var listen := func(point: Vector3, contact: bool):
		if not contact:
			windups.append(point)
	zombie.melee_audio.connect(listen)
	var stride := roundi(Engine.physics_ticks_per_second / ZOMBIE.LAB_CROWD_SIGHT_HZ)
	for escape in [Vector3.BACK * 1.0, Vector3.UP * 2.05, Vector3.RIGHT * 0.75]:
		player.global_position = player_origin
		zombie.global_position = player_origin + Vector3.FORWARD * 1.34
		zombie.velocity = Vector3.ZERO
		zombie.rotation.y = 0.0
		zombie.animation.play(ZOMBIE.IDLE, 0.0)
		zombie.animation.advance(0.0)
		zombie._attack_cooldown = 1.0
		zombie.set_physics_process(true)
		for i in 5:
			await physics_frame
		var remembered := zombie._last_seen_position
		if not zombie._target_aggressive or not zombie._target_visible or not remembered.is_equal_approx(player_origin):
			failures.append("The zombie sees the player in reach before the crowd range fixture moves them")
		windups.clear()
		player.global_position += escape
		zombie._crowd_slot = (Engine.get_physics_frames() + 2) % stride
		zombie._attack_cooldown = 0.0
		await physics_frame
		var escaped_windups := windups.size()
		if escaped_windups != 0 or zombie._attack_cooldown > 0.0:
			failures.append("A target escaping reach or facing between sight samples prevents a windup: %s" % escape)
		player.global_position = player_origin
		for i in 8:
			await physics_frame
			if windups.size() > escaped_windups:
				break
		if windups.size() - escaped_windups != 1 or zombie.animation.current_animation != ZOMBIE.ATTACK:
			failures.append("The zombie starts one windup when the target is back in reach: %s" % escape)
		print("CROWD_WINDUP_RANGE escape=", escape, " invalid=", escaped_windups,
			" valid=", windups.size() - escaped_windups)
	zombie.melee_audio.disconnect(listen)
	player.set_physics_process(true)
	for member in group.get_children():
		member.set_physics_process(true)

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
	var dust := lab.get_node_or_null("ZombieStepDust") as MultiMeshInstance3D
	for i in ticks:
		await physics_frame
		if label == "chase" and dust != null:
			chase_dust_peak = maxi(chase_dust_peak, dust.multimesh.visible_instance_count)
		if group != null:
			var active := 0
			for zombie in group.get_children():
				if zombie.ragdoll.running:
					active += 1
			if label == "simultaneous_ragdolls" and i == 30:
				check_crowd_corpse_fade(group)
			if label == "simultaneous_ragdolls" and i == 1:
				first_tick_ragdolls = active
			if label == "corpse_cleanup" and i == 149:
				late_active_ragdolls = active
			active_peak = maxi(active_peak, active)
			if label == "simultaneous_ragdolls" and numbers != null:
				peak_damage_glyphs = maxi(peak_damage_glyphs, numbers.multimesh.visible_instance_count)
	print("CROWD_PHASE ", JSON.stringify({"phase": label, "frame_ms": stats(frame_ms),
		"physics_to_process_ms": stats(physics_ms), "gpu_ms": stats(render_gpu_ms),
		"draws": stats(draws), "samples": frame_ms.size(), "active_ragdolls_peak": active_peak}))

func check_crowd_corpse_fade(group: Node) -> void:
	checked_corpse_fade = true
	var shared: Material
	var fading := 0
	for zombie: ZOMBIE in group.get_children():
		var mesh: MeshInstance3D = zombie._mesh
		var material := mesh.material_override
		if shared == null:
			shared = material
		var fade: Variant = mesh.get_instance_shader_parameter("desaturation")
		if material is ShaderMaterial and material == shared and fade is float and fade > 0.0:
			fading += 1
	if fading != COUNT:
		failures.append("All 100 corpses fade with one shared material before their first second")
	print("CROWD_CORPSE_FADE shared_material_instances=", fading)

func stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {}
	var sorted := samples.duplicate()
	sorted.sort()
	return {"p50": sorted[sorted.size() / 2], "p95": sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)],
		"max": sorted.back()}
