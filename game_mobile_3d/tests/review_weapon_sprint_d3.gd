extends SceneTree
## Loads actual gameplay; no forced weapon state or altered controller/camera.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled = false
	level.get_node("Progression").enabled = false
	root.add_child(level); current_scene = level; level.select_test_weapon(1)
	var enemy = preload("res://scenes/characters/CuboidZombie.tscn").instantiate()
	enemy.max_hp = 1000000
	level.get_node("Actors").add_child(enemy); enemy.current_hp = 1000000
	enemy.set_physics_process(false); level.combat.register_zombie(enemy)
	var controls = preload("res://tests/review_weapon_sprint_d3_controls.gd").new()
	controls.level = level; controls.enemy = enemy; root.add_child(controls)
	level.get_node("HUD/Help/Text").text = "D3 SPRINT / WEAPON REVIEW\nWASD + Shift: sprint/stow | release Shift: Draw\nT: threat on/off | 1/2/3: Pistol/M4A1/Shotgun\nDurable non-attacking review target follows at 3m."
	var behavior: Node = level.player.get_node("WeaponBehavior")
	await create_timer(1.1).timeout
	assert(behavior.is_ready())
	if "--smoke" in OS.get_cmdline_user_args():
		Input.action_press("move_right"); Input.action_press("sprint")
		for i in 50: await physics_frame
		assert(behavior.state == behavior.State.STOWED and behavior.threat_present)
		assert(level.player.visual.socket.current_attachment == &"back")
		Input.action_release("sprint")
		for i in 40: await physics_frame
		assert(behavior.is_ready())
		Input.action_release("move_right")
		print("D3 review: natural READY -> sprint/back -> release/READY passed")
		quit(); return
	DirAccess.make_dir_recursive_absolute("res://.validation/weapon_sprint_d3")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/weapon_sprint_d3/live_review.png")
