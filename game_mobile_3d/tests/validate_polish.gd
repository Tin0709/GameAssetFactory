extends SceneTree
## Focused controller/feedback regression using actual physics frames.
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
var checks := 0
var failed := false
var level: Node3D
var player: CharacterBody3D
var combat: Node
var metrics := {}
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("POLISH TEST FAILED: " + message)
func tick(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	level = LEVEL.instantiate()
	level.get_node("Actors/Player/Pistol").enabled = false
	root.add_child(level)
	current_scene = level
	player = level.get_node("Actors/Player")
	combat = level.get_node("Combat")
	for enemy in combat.living_zombies: enemy.set_physics_process(false)
	player.position = Vector3(0, 0.01, 0)
	await tick(5)
	if "--capture" in OS.get_cmdline_user_args(): await create_timer(1.1).timeout
	var visual: Node3D = player.visual
	check(is_equal_approx(player.walk_speed, 4.25) and is_equal_approx(player.run_speed, 6.25), "Requested speed band")
	Input.action_press("move_left")
	await tick(4)
	check(player.current_speed > 1.8 and player.current_speed < player.walk_speed, "Quick gradual start")
	await tick(12)
	check(absf(player.current_speed - player.walk_speed) < 0.1, "Walk reaches 4.25m/s")
	check(visual.current_state == &"Walk", "Walk clip selected")
	var changes: int = visual.state_changes
	await tick(12)
	check(visual.state_changes == changes, "Sustained walk does not restart")
	check(visual.animation_player.speed_scale > 2.5 and visual.animation_player.speed_scale < 2.8, "Walk cadence tracks actual speed")
	metrics.walk_rate = visual.animation_player.speed_scale
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/polish_walk.png")
	Input.action_release("move_left")
	Input.action_press("move_right")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await tick(22)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - player.run_speed) < 0.1, "Normalized diagonal sprint")
	check(visual.current_state == &"Run", "Sprint transitions to Run")
	check(visual.animation_player.speed_scale > 1.8 and visual.animation_player.speed_scale < 2.5, "Run cadence synced")
	metrics.run_rate = visual.animation_player.speed_scale
	var facing := Vector3.BACK.rotated(Vector3.UP, visual.rotation.y)
	check(facing.dot(Vector3(1, 0, -1).normalized()) > 0.98, "Smooth rotation converges quickly")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var stop_position := player.position
	await tick(9)
	check(player.current_speed < 0.01 and visual.current_state == &"Idle", "Stop reaches Idle within 150ms")
	metrics.stopping_distance = player.position.distance_to(stop_position)
	check(metrics.stopping_distance < 0.35, "No excessive stopping drift")
	await tick(18)
	check(absf(visual.animation_player.speed_scale - 1.0) < 0.03, "Idle returns to natural cadence")
	# Shooting/recoil: short opaque flash and no leaked effects after repeated shots.
	player.position = Vector3(0, 0.01, 0)
	for i in range(8):
		combat.fire(Vector3(0, 3, 0), Vector3.RIGHT, 20, 1, 0.10)
		check(combat.effects.get_child_count() >= 1, "Muzzle flash spawned")
		await tick(2)
		check(visual.model.position.length() > 0.001, "Tiny rigid recoil visible")
		await tick(12)
	check(combat.projectiles.get_child_count() == 0 and combat.effects.get_child_count() == 0, "Repeated shots clean up")
	check(visual.model.position.length() < 0.001 and visual.model.scale == Vector3.ONE, "Recoil restores rigid model")
	# Asynchronous but stable spawn variation and staged attack.
	var speeds := []
	for enemy in combat.living_zombies: speeds.append(enemy.speed_multiplier)
	check(speeds[0] != speeds[1] or speeds[1] != speeds[2], "Zombie speeds vary per spawn")
	var enemy: CharacterBody3D = combat.living_zombies[0]
	enemy.position = Vector3(0, 0.01, 0.9)
	for other in combat.living_zombies:
		if other != enemy: other.position = Vector3(-5, 0.01, -5)
	enemy.set_physics_process(true)
	await tick(5)
	check(player.current_hp == 100 and enemy.pending_attack > 0, "Anticipation does not deal damage")
	check(enemy.visual.model.position.z < 0, "Anticipation retracts model")
	await tick(8)
	check(player.current_hp == 90, "Damage occurs at strike")
	check(enemy.visual.model.position.z > 0.08, "Strike reaches forward")
	await tick(17)
	check(enemy.visual.model.position.length() < 0.001, "Recovery restores model")
	enemy.take_damage(60, Vector3.RIGHT)
	await tick(4)
	check(enemy.is_dead and enemy.visual.rotation.z > 0, "Death starts with loss of balance")
	check(enemy.visual.model.position.length() < 0.001, "Death cancels attack tween")
	await tick(38)
	check(not is_instance_valid(enemy) and combat.pickups.get_child_count() == 1, "Death cleanup and drop")
	var pickup := combat.pickups.get_child(0) as Node3D
	player.position = Vector3(0, 0.01, 0.9)
	await tick(3)
	check(pickup.collected and player.experience == 0, "Collection uses brief travel rather than immediate disappearance")
	await tick(10)
	check(player.experience == 1 and combat.pickups.get_child_count() == 0, "Pickup pop awards exactly once")
	if "--capture" in OS.get_cmdline_user_args():
		level.queue_free()
		await process_frame
		level = LEVEL.instantiate()
		root.add_child(level)
		current_scene = level
		await create_timer(1.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/polish_combat.png")
		metrics.rendered_fps = Engine.get_frames_per_second()
		metrics.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		check(RenderingServer.get_current_rendering_method() == "mobile", "Actual Mobile rendered validation")
	metrics.checks = checks
	metrics.passed = not failed
	metrics.phone_tested = false
	var suffix := "rendered" if "--capture" in OS.get_cmdline_user_args() else "headless"
	var file := FileAccess.open("res://tests/polish_" + suffix + "_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t"))
	print("POLISH VALIDATION: %d checks; passed=%s; %s" % [checks, not failed, JSON.stringify(metrics)])
	quit(1 if failed else 0)

