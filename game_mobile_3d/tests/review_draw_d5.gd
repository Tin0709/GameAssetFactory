extends SceneTree
## Actual gameplay controller/camera. Initially M4A1 STOWED; T brings in a threat.
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
	controls.level = level; controls.enemy = enemy; controls.threat_enabled = false
	enemy.position = level.player.position + Vector3(0,0,40)
	root.add_child(controls)
	level.get_node("HUD/Help/Text").text = "D5 AUTHORED DRAW REVIEW\nT: bring enemy in/out -> real Draw\nWASD: move | Shift: sprint/stow | release: Draw\n1/2/3: Pistol/M4A1/Shotgun | M4A1 starts STOWED"
	for i in 5: await physics_frame
	var behavior: Node = level.player.get_node("WeaponBehavior")
	assert(behavior.state==behavior.State.STOWED and level.player.visual.socket.current_attachment==&"back")
	print("D5 review ready: M4A1 STOWED; T activates the review enemy")
	if "--smoke" in OS.get_cmdline_user_args():
		controls.threat_enabled = true
		for i in 4: await physics_frame
		assert(behavior.state==behavior.State.DRAWING and behavior.authored_draw)
		for i in 40: await physics_frame
		assert(behavior.is_ready())
		print("D5 review smoke: natural STOWED -> authored DRAWING -> READY passed")
		quit(); return
	DirAccess.make_dir_recursive_absolute("res://.validation/draw_d5")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/draw_d5/review_open.png")
