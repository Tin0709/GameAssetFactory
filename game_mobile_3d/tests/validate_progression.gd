extends SceneTree
## Real pickup, paused gameplay, input routing, stacked stats and reset integration.
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
const CATALOG = preload("res://scripts/upgrade_catalog.gd")
var level: Node3D
var player: CharacterBody3D
var progression: Node
var combat: Node
var pistol: Node3D
var ui: Control
var checks := 0
var failed := false
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("PROGRESSION TEST FAILED: " + message)
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
	progression = level.get_node("Progression")
	combat = level.get_node("Combat")
	pistol = player.get_node("Pistol")
	ui = level.get_node("HUD/UpgradeSelection")
	for enemy in combat.living_zombies: enemy.set_physics_process(false)
	player.position = Vector3(0, 0.01, 0)
	await tick(4)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func wait_choice() -> void:
	await create_timer(0.16, true).timeout
func offer(id: StringName) -> void:
	progression.gain_exp(progression.required_exp() - player.experience)
	var chosen: Dictionary
	for entry: Dictionary in CATALOG.UPGRADES:
		if entry.id == id: chosen = entry
	var forced: Array[Dictionary] = [chosen]
	for entry: Dictionary in CATALOG.UPGRADES:
		if entry.id != id and forced.size() < 3: forced.append(entry)
	progression.choices = forced
	ui.show_choices(forced, player.level, 1)
func choose(id: StringName) -> void:
	offer(id)
	check(progression.select_upgrade(0), "Selection accepted: " + String(id))
	check(not progression.select_upgrade(0), "Rapid duplicate input rejected")
	await wait_choice()
	check(not paused and not ui.visible, "Selection resumes gameplay")
func run() -> void:
	await fresh()
	check(player.level == 1 and player.experience == 0, "Starts Level 1 EXP 0")
	check(progression.required_exp() == 3 and progression.required_exp(2) == 5 and progression.required_exp(4) == 9, "Central EXP formula")
	check(level.get_node("HUD/ExpText").text == "EXP 0 / 3", "Progress HUD initialized")
	check(ui.buttons.size() == 3 and not ui.visible, "One reused hidden overlay with three cards")
	for i in range(3):
		combat.spawn_exp(player.global_position)
		await tick(16)
		if i < 2:
			check(player.experience == i + 1 and player.level == 1, "Real pickup increments progress")
	check(player.level == 2 and player.experience == 0 and paused and ui.visible, "Third real pickup levels up and pauses")
	check(combat.pickups.get_child_count() == 0 and player.total_experience == 3, "Triggering pickup finishes award and cleanup")
	check(level.get_node("HUD/ExpBar").max_value == 5, "HUD updates next threshold")
	check(progression.choices.size() == 3 and progression.choices[0].id != progression.choices[1].id and progression.choices[0].id != progression.choices[2].id and progression.choices[1].id != progression.choices[2].id, "Exactly three unique random choices")
	await key(KEY_1)
	await wait_choice()
	check(not paused and not progression.selection_open, "Keyboard 1 resumes gameplay")
	await fresh()
	for enemy in combat.living_zombies.duplicate():
		enemy.position = Vector3(2, 0.01, 0)
		enemy.take_damage(60)
	await tick(42)
	check(combat.living_zombies.is_empty() and combat.pickups.get_child_count() == 3, "Actual three zombie kills produce three drops")
	player.position = Vector3(2, 0.01, 0)
	await tick(16)
	check(paused and player.level == 2 and player.total_experience == 3 and combat.pickups.get_child_count() == 0, "Complete kill to pickup to level-up loop")
	progression.select_upgrade(0)
	await wait_choice()
	check(not paused and not ui.visible, "Kill-earned upgrade resumes cleared arena")
	await fresh()
	player.collect_exp(2)
	player.collect_exp(3)
	check(player.level == 2 and player.experience == 2 and player.total_experience == 5, "2 plus 3 EXP preserves overflow 2")
	progression.select_upgrade(0)
	await wait_choice()
	check(player.experience == 2 and level.get_node("HUD/ExpText").text == "EXP 2 / 5", "Overflow survives selection")
	await fresh()
	player.collect_exp(17)
	check(player.level == 4 and player.experience == 2 and progression.pending_levels == 3, "Whole grant processes three thresholds")
	var button_ids := []
	for button in ui.buttons: button_ids.append(button.get_instance_id())
	for code in [KEY_1, KEY_2, KEY_3]:
		check(paused and ui.visible, "Pending selection stays paused")
		var ids := {}
		for choice: Dictionary in progression.choices: ids[choice.id] = true
		check(ids.size() == 3, "Every pending offer stays unique")
		await key(code)
		await wait_choice()
		check(ui.buttons[0].get_instance_id() == button_ids[0], "Card nodes reused across pending choices")
	check(not paused and progression.pending_levels == 0 and player.level == 4 and player.experience == 2, "Only final selection resumes")
	await fresh()
	await choose(&"power_shot")
	await choose(&"power_shot")
	check(pistol.damage == 30, "Power Shot stacks additively")
	await choose(&"rapid_fire")
	check(is_equal_approx(pistol.fire_interval, 0.45), "Rapid Fire reduces interval by 10 percent")
	for i in range(30): CATALOG.apply(CATALOG.UPGRADES[1], player, pistol)
	check(is_equal_approx(pistol.fire_interval, 0.18), "Rapid Fire cannot pass 0.18s floor")
	check(CATALOG.available(player, pistol).size() == 4, "Capped Rapid Fire leaves four useful options")
	await choose(&"runner")
	check(is_equal_approx(player.walk_speed, 4.25 * 1.08) and is_equal_approx(player.run_speed, 6.25 * 1.08), "Runner increases both speeds")
	Input.action_press("move_right")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await tick(26)
	check(absf(Vector2(player.velocity.x, player.velocity.z).length() - player.run_speed) < 0.01, "Upgraded diagonal sprint remains normalized")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await tick(10)
	player.current_hp = 50
	await choose(&"toughness")
	check(player.current_hp == 70 and player.max_hp == 120, "Toughness heals missing HP correctly")
	await choose(&"toughness")
	check(player.current_hp == 90 and player.max_hp == 140, "Toughness stacks")
	player.current_hp = player.max_hp
	await choose(&"toughness")
	check(player.current_hp == 160 and player.max_hp == 160, "Full-health Toughness respects new maximum")
	await choose(&"ballistics")
	await choose(&"ballistics")
	check(is_equal_approx(pistol.projectile_speed, 14 * 1.21) and is_equal_approx(pistol.projectile_range, 12.6 * 1.21) and is_equal_approx(pistol.attack_range, 8 * 1.21), "Ballistics stacks speed, travel and acquisition range")
	combat.fire(Vector3(0, 3, 0), Vector3.RIGHT, pistol.damage, pistol.projectile_speed, pistol.projectile_lifetime, pistol.projectile_range)
	var bullet: Node3D = combat.projectiles.get_child(0)
	check(is_equal_approx(bullet.speed, pistol.projectile_speed) and is_equal_approx(bullet.travel_range, pistol.projectile_range), "Shot snapshots upgraded weapon stats")
	await tick(60)
	combat.fire(Vector3(0, 3, 0), Vector3.RIGHT, 20, 1, 10, 0.05)
	await tick(8)
	check(combat.projectiles.get_child_count() == 0, "Explicit travel range expires a missed bullet")
	await key(KEY_R)
	await tick(4)
	var reset_player: CharacterBody3D = current_scene.get_node("Actors/Player")
	var reset_pistol: Node = reset_player.get_node("Pistol")
	check(reset_player.walk_speed == 4.25 and reset_player.run_speed == 6.25 and reset_player.max_hp == 100 and reset_player.current_hp == 100 and reset_player.level == 1, "R clears stacked player upgrades")
	check(reset_pistol.damage == 20 and reset_pistol.fire_interval == 0.5 and reset_pistol.projectile_speed == 14 and reset_pistol.projectile_range == 12.6 and reset_pistol.attack_range == 8, "R clears all stacked weapon upgrades")
	level = current_scene
	# All gameplay presentation and physics stop, including in-flight effects/tweens.
	await fresh()
	var enemy: CharacterBody3D = combat.living_zombies[0]
	enemy.position = Vector3(0, 0.01, 0.85)
	enemy.set_physics_process(true)
	pistol.enabled = true
	combat.fire(Vector3(0, 3, 0), Vector3.RIGHT, 20, 1, 0.9)
	combat.spawn_impact(Vector3(0, 1, 0))
	combat.spawn_exp(Vector3(3, 0, 3))
	var corpse: CharacterBody3D = combat.living_zombies[1]
	corpse.take_damage(60)
	await tick(2)
	player.collect_exp(3)
	bullet = combat.projectiles.get_child(0)
	var bullet_position: Vector3 = bullet.position
	var bullet_age: float = bullet.age
	var enemy_position := enemy.position
	var player_position := player.position
	var lunge_position: Vector3 = enemy.visual.model.position
	var animation_time: float = enemy.visual.animation_player.current_animation_position
	var corpse_rotation: Vector3 = corpse.visual.rotation
	var effect_scale: Vector3 = combat.effects.get_child(0).scale
	var pickup_elapsed: float = combat.pickups.get_child(0).elapsed
	var hp: int = player.current_hp
	var cooldown: float = pistol.cooldown
	Input.action_press("move_forward")
	await tick(30)
	Input.action_release("move_forward")
	check(paused and not combat.can_fight(), "Tree pause blocks combat services")
	check(player.position.is_equal_approx(player_position) and enemy.position.is_equal_approx(enemy_position), "Player and chasing zombie frozen")
	check(bullet.position.is_equal_approx(bullet_position) and bullet.age == bullet_age, "Projectile position and lifetime frozen")
	check(enemy.visual.model.position.is_equal_approx(lunge_position) and enemy.visual.animation_player.current_animation_position == animation_time, "Attack tween and skeletal playback frozen")
	check(corpse.visual.rotation.is_equal_approx(corpse_rotation) and combat.effects.get_child(0).scale == effect_scale, "Corpse and effect tweens frozen")
	check(combat.pickups.get_child(0).elapsed == pickup_elapsed and player.current_hp == hp and pistol.cooldown == cooldown, "Pickup, damage and shooting timers frozen")
	var before: int = combat.projectiles.get_child_count()
	combat.fire(Vector3(0, 3, 0), Vector3.RIGHT, 20, 1, 1)
	check(combat.projectiles.get_child_count() == before, "Direct fire rejected during selection")
	check(combat.audio.players[&"level_up"].process_mode == Node.PROCESS_MODE_ALWAYS and combat.audio.players[&"upgrade_selected"].process_mode == Node.PROCESS_MODE_ALWAYS, "Menu sounds remain playable during pause")
	check(combat.audio.players[&"level_up"].max_polyphony == 1 and combat.audio.players[&"upgrade_selected"].max_polyphony == 1, "Menu sounds cannot stack identical voices")
	# Actual mouse routing through the viewport, not manually emitting pressed.
	await process_frame
	var center: Vector2 = ui.buttons[1].get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = center
		click.pressed = pressed
		root.push_input(click, true)
		await process_frame
	await wait_choice()
	check(not paused and not ui.visible, "Mouse click applies and resumes while paused")
	await tick(6)
	check(bullet.age > bullet_age, "Bullet advances again after resume")
	await fresh()
	await key(KEY_L)
	check(paused and player.level == 2, "Debug L shortcut triggers level-up")
	check(not progression.debug_grant_level(), "Debug grant blocked while selecting")
	var old := level
	await key(KEY_R)
	await tick(4)
	level = current_scene
	player = level.get_node("Actors/Player")
	progression = level.get_node("Progression")
	combat = level.get_node("Combat")
	ui = level.get_node("HUD/UpgradeSelection")
	pistol = player.get_node("Pistol")
	check(level != old and not paused and player.level == 1 and player.experience == 0, "R resets level and pause while overlay open")
	check(player.walk_speed == 4.25 and player.max_hp == 100 and pistol.damage == 20 and pistol.fire_interval == 0.5, "Reset restores all baseline stats")
	check(combat.living_zombies.size() == 3 and not ui.visible and ui.buttons.size() == 3, "Reset restores one UI and three zombies")
	check(ui.grid.get_child_count() == 3 and level.find_children("UpgradeSelection", "Control", true, false).size() == 1, "No duplicated UI nodes")
	# Rendered captures at landscape, wide landscape and portrait logical sizes.
	if "--capture" in OS.get_cmdline_user_args():
		await fresh()
		progression.rng.seed = 12
		player.collect_exp(3)
		for dimensions in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(720, 1280)]:
			root.content_scale_size = dimensions
			root.size = dimensions
			await create_timer(0.15, true).timeout
			await RenderingServer.frame_post_draw
			for button in ui.buttons:
				var rect: Rect2 = button.get_global_rect()
				check(rect.size.y >= 120 and rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= dimensions.x + 1 and rect.end.y <= dimensions.y + 1, "Touch card fits aspect ratio %s" % dimensions)
			root.get_texture().get_image().save_png("res://tests/level_up_%dx%d.png" % [dimensions.x, dimensions.y])
		check(RenderingServer.get_current_rendering_method() == "mobile", "Rendered Mobile validation")
	var report := {"passed": not failed, "checks": checks, "engine": Engine.get_version_info().string, "phone_tested": false, "renderer": RenderingServer.get_current_rendering_method(), "capture": "--capture" in OS.get_cmdline_user_args()}
	var suffix := "rendered" if report.capture else "headless"
	FileAccess.open("res://tests/progression_" + suffix + "_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("PROGRESSION VALIDATION: %d checks; passed=%s" % [checks, not failed])
	paused = false
	level.queue_free()
	current_scene = null
	await process_frame
	await create_timer(0.15, true).timeout
	quit(1 if failed else 0)
