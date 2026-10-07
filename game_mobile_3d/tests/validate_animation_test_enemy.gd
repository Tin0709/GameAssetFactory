extends SceneTree
var level: Node3D

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value

func ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func run() -> void:
	level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.select_test_weapon(0)
	var button = level.get_node_or_null("HUD/AnimationTestEnemyButton")
	if not check(button != null, "F5 gameplay needs an animation test enemy button"): return
	button.pressed.emit()
	await ticks(3)
	if not check(level.combat.living_zombies.size() == 1, "Review must have exactly one enemy"): return
	var enemy = level.combat.living_zombies[0]
	var origin = enemy.global_position
	if not check(Vector2(origin.x, origin.z).length() < 0.001, "Test enemy must stand at map center"): return
	if not check(not level.spawner.enabled, "Review must stop normal spawns"): return
	var hp = level.player.current_hp
	var kills = level.combat.kill_count
	enemy.take_damage(1000000, Vector3.RIGHT)
	level.player.global_position = origin + Vector3(0, 0, 0.75)
	await ticks(150)
	if not check(not enemy.is_dead and enemy.global_position.distance_to(origin) < 0.001, "Test enemy moved or died"): return
	if not check(level.player.current_hp == hp and enemy.pending_attack < 0.0, "Test enemy attacked player"): return
	if not check(level.combat.kill_count == kills, "Test enemy awarded a kill"): return
	if not check(level.player.get_node("Pistol").awareness_target(false) == enemy, "Test enemy must remain a real awareness target"): return
	# All weapon classes must complete the automatic Draw against this target.
	for weapon in 3:
		level.player.equip_test_weapon(weapon)
		await ticks(160)
		var behavior = level.player.get_node("WeaponBehavior")
		if not check(behavior.state == behavior.State.READY, "Test target did not allow automatic READY"): return
	button.pressed.emit()
	await ticks(240)
	if not check(not level.spawner.enabled, "Deleting review target must not immediately respawn threats"): return
	if not check(not is_instance_valid(enemy) and level.combat.living_zombies.is_empty(), "Test enemy was not removed cleanly"): return
	var behavior = level.player.get_node("WeaponBehavior")
	if not check(behavior.state == behavior.State.STOWED, "Deleting enemy must allow no-threat Holster to finish"): return
	# Normal enemies retain their usual damage/death behavior.
	level.spawner.enabled = true
	var normal = level.spawner.spawn_one()
	if not check(normal != null and normal.take_damage(1000000), "Normal enemy combat was changed"): return
	print("PASS: F5 button; one stationary immortal non-attacking center enemy; awareness all 3 weapons; clean toggle; normal combat intact")
	quit()
