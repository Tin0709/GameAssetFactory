extends SceneTree
## Real physics/collision/timing tests, plus optional Mobile-rendered capture.

const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
var checks: int = 0
var failed: bool = false
var level: Node3D
var player: CharacterBody3D
var combat: Node
var pistol: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("COMBAT TEST FAILED: " + message)
		quit(1)

func tick(count: int) -> void:
	for i in range(count): await physics_frame

func fresh(auto_fire: bool = false) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = LEVEL.instantiate()
	# Isolate combat accounting; progression has its own integration suite.
	level.get_node("Progression").enabled = false
	level.get_node("Actors/Player/Pistol").enabled = auto_fire
	root.add_child(level)
	current_scene = level
	player = level.get_node("Actors/Player")
	combat = level.get_node("Combat")
	pistol = player.get_node("Pistol")
	player.position = Vector3(0, 0.01, 0)
	for zombie in combat.living_zombies: zombie.set_physics_process(false)
	await tick(2)

func _run() -> void:
	await fresh()
	check(player.current_hp == 100 and player.experience == 0, "Initial player HP/EXP")
	check(combat.living_zombies.size() == 3, "Three living zombies registered")
	check(level.get_node("HUD/Status").text.contains("HP 100/100"), "HUD displays initial HP")
	check(pistol.damage == 20 and pistol.fire_interval == 0.5 and pistol.projectile_speed == 14, "Tuning accessible")
	check(combat.audio.players.size() == 10, "Ten audio hooks loaded")
	for voice in combat.audio.players.values():
		check(voice.stream != null and voice.stream.get_length() > 0, "Audio resource usable")
	check(combat.audio.players[&"bullet_impact"].stream.get_length() < 0.30, "Multi-impact recording reduced to a short clip")
	var first: CharacterBody3D = combat.living_zombies[0]
	var second: CharacterBody3D = combat.living_zombies[1]
	var third: CharacterBody3D = combat.living_zombies[2]
	first.position = Vector3(4, 0.01, 0)
	second.position = Vector3(2, 0.01, 0)
	third.position = Vector3(9, 0.01, 0)
	check(pistol.nearest_target() == second, "Nearest living target wins")
	second.take_damage(60, Vector3.RIGHT)
	check(second.is_dead and pistol.nearest_target() == first, "Dying enemy immediately excluded")
	first.position.x = 9
	check(pistol.nearest_target() == null, "Out-of-range targets ignored")
	if failed: return

	# Swept ray catches even a bullet that crosses the full collider in one tick.
	await fresh()
	first = combat.living_zombies[0]
	first.position = Vector3(0.9, 0.01, 0)
	combat.living_zombies[1].position = Vector3(-4, 0.01, -4)
	combat.living_zombies[2].position = Vector3(-5, 0.01, -4)
	await tick(2)
	combat.fire(Vector3(0, 1.02, 0), Vector3.RIGHT, 20, 120, 0.9)
	await tick(2)
	check(first.current_hp == 40, "Swept projectile hits once without tunneling")
	check(combat.projectiles.get_child_count() == 0, "Hit projectile removed")
	check(first.knockback.length() > 0, "Hit adds rigid-body translation feedback")
	var hit_mesh := first.visual.meshes[0] as MeshInstance3D
	check(hit_mesh.material_overlay != null, "Brief hit flash active")
	check(combat.living_zombies[1].visual.meshes[0].material_overlay == null, "Shared atlas does not flash other zombies")
	await tick(14)
	check(hit_mesh.material_overlay == null and combat.effects.get_child_count() == 0, "Flash/burst clean up")
	# Empty-air lifetime and world-wall collision cleanup are separate paths.
	combat.fire(Vector3(0, 3, 0), Vector3.RIGHT, 20, 1, 0.05)
	await tick(8)
	check(combat.projectiles.get_child_count() == 0, "Miss expires safely")
	combat.fire(Vector3(7, 1, 0), Vector3.RIGHT, 20, 14, 0.9)
	await tick(8)
	check(combat.projectiles.get_child_count() == 0, "Projectile stops at arena wall")
	if failed: return

	# Actual automatic cadence: three shots kill a stationary 60 HP target.
	await fresh(true)
	first = combat.living_zombies[0]
	first.position = Vector3(4, 0.01, 0)
	combat.living_zombies[1].position = Vector3(9, 0.01, -4)
	combat.living_zombies[2].position = Vector3(-9, 0.01, -4)
	await tick(30)
	check(first.current_hp == 40, "First auto-shot deals 20")
	await tick(30)
	check(first.current_hp == 20, "Second auto-shot deals 20")
	await tick(30)
	check(first.is_dead and first.current_hp == 0, "Third auto-shot kills")
	check(not first.take_damage(20), "Dead enemy rejects further damage")
	check(combat.living_zombies.size() == 2, "Living count updates at death start")
	check(first.visual.scale.is_equal_approx(Vector3.ONE), "Death keeps whole-body scale unchanged")
	await tick(40)
	check(not is_instance_valid(first), "Corpse removed after collapse")
	check(combat.pickups.get_child_count() == 1, "Exactly one EXP drop per zombie")
	check(combat.projectiles.get_child_count() == 0, "No bullets accumulate after target dies")
	player.position = Vector3(4, 0.01, 0)
	await tick(14)
	check(player.experience == 1 and combat.pickups.get_child_count() == 0, "Move close collects one EXP")
	await tick(14)
	check(player.experience == 1, "Pickup cannot award twice")
	if failed: return

	# Close-range windup/cooldown, then chase resumes as the target moves away.
	await fresh()
	first = combat.living_zombies[0]
	first.position = Vector3(0.85, 0.01, 0)
	first.set_physics_process(true)
	await tick(14)
	check(player.current_hp == 90, "First melee attack deals 10 after windup")
	check(first.holding_distance and first.visual.current_state == &"Idle", "Attack holds chase and uses idle/lunge fallback")
	await tick(45)
	check(player.current_hp == 90, "Cooldown prevents per-frame damage")
	await tick(25)
	check(player.current_hp == 80, "Next attack occurs after cooldown")
	player.position = Vector3(3, 0.01, 0)
	var before := first.position.x
	await tick(20)
	check(first.position.x > before + 0.1 and first.visual.current_state == &"Walk", "Moving away resumes chase/walk")
	check(player.current_hp == 80, "No melee damage outside range")
	await fresh()
	first = combat.living_zombies[0]
	first.position = Vector3(0.85, 0.01, 0)
	first.set_physics_process(true)
	await tick(2)
	player.position = Vector3(5, 0.01, 0)
	await tick(12)
	check(player.current_hp == 100, "Escaping during windup cancels damage")
	if failed: return

	# HP clamp, hurt grace, defeat freeze, bullet cleanup, and R reset.
	await fresh()
	check(not player.take_damage(-10), "Invalid damage ignored")
	check(player.take_damage(10) and player.current_hp == 90, "Player HP decreases")
	check(not player.take_damage(10) and player.current_hp == 90, "Short grace blocks stacked hits")
	await tick(24)
	combat.fire(Vector3(0, 3, 0), Vector3.RIGHT, 20, 1, 0.9)
	combat.spawn_exp(player.global_position)
	check(player.take_damage(500), "Lethal player damage accepted")
	check(player.current_hp == 0 and player.is_dead and not combat.active, "Zero HP clamps and stops combat")
	check(level.get_node("HUD/Defeated").visible, "Defeated panel shown")
	check(not player.take_damage(10), "Defeated player ignores further damage")
	var defeat_position := player.position
	Input.action_press("move_forward")
	await tick(8)
	Input.action_release("move_forward")
	check(player.position.is_equal_approx(defeat_position), "Movement disabled after defeat")
	check(combat.projectiles.get_child_count() == 0, "Defeat removes remaining bullets")
	check(player.experience == 0, "Defeat prevents pickup collection")
	for zombie in combat.living_zombies: check(not zombie.is_physics_processing(), "Zombie simulation stops on defeat")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://tests/defeated_preview.png") == OK, "Defeated capture saved")
	var old := level
	var reset := InputEventAction.new()
	reset.action = "reset_test"
	reset.pressed = true
	level._unhandled_input(reset)
	await process_frame
	await tick(2)
	level = current_scene
	player = level.get_node("Actors/Player")
	combat = level.get_node("Combat")
	pistol = player.get_node("Pistol")
	check(level != old and player.current_hp == 100 and player.experience == 0, "R creates clean player state")
	check(combat.active and combat.living_zombies.size() == 3, "Reset restores three living zombies")
	check(combat.pickups.get_child_count() == 0 and combat.projectiles.get_child_count() == 0, "Reset clears transient nodes")
	if failed: return

	# Repeated kills exercise cleanup, registry updates and one-drop accounting.
	await fresh()
	for enemy in combat.living_zombies.duplicate(): enemy.take_damage(60)
	await tick(42)
	check(combat.living_zombies.is_empty() and get_nodes_in_group("zombies").is_empty(), "Initial three deaths clean up")
	for i in range(12):
		var enemy := ZOMBIE.instantiate()
		enemy.position = Vector3(2, 0.01, 0)
		level.get_node("Actors").add_child(enemy)
		enemy.set_physics_process(false)
		combat.register_zombie(enemy)
		enemy.take_damage(20)
		enemy.take_damage(20)
		enemy.take_damage(20)
		check(enemy.is_dead and not enemy.take_damage(20), "Repeated lethal damage stays single-use")
	await tick(42)
	check(combat.living_zombies.is_empty() and get_nodes_in_group("zombies").is_empty(), "Twelve repeated deaths leave no enemies")
	check(combat.pickups.get_child_count() == 15, "Fifteen kills produce fifteen drops")
	for pickup in combat.pickups.get_children(): pickup.global_position = Vector3(0, 0.24, 0)
	await tick(14)
	check(player.experience == 15 and combat.pickups.get_child_count() == 0, "Repeated EXP collection has exact accounting")
	if failed: return

	if "--capture" in OS.get_cmdline_user_args():
		await fresh(true)
		player.position = Vector3(0, 0.02, 1.8)
		# Keep normal scene logic running for the real combat screenshot.
		for zombie in combat.living_zombies: zombie.set_physics_process(true)
		await create_timer(2.3).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://tests/combat_preview.png") == OK, "Mobile combat capture saved")
	var report := {"passed": not failed, "checks": checks, "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "repeated_kills": 15,
		"capture": "--capture" in OS.get_cmdline_user_args(), "phone_tested": false}
	var report_path := "res://tests/combat_validation.json" if report.capture else "res://tests/combat_headless_validation.json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("COMBAT VALIDATION PASS: %d checks; targeting, swept hits, expiry/walls, damage, death/drop, cooldown, grace/defeat, EXP, reset, 15 repeated kills." % checks)
	quit(1 if failed else 0)
