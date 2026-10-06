extends SceneTree
## Review-only setup; production movement/camera/awareness remain active.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false;level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	# Show the back to the unchanged elevated gameplay camera at startup.
	level.player.visual.rotation.y=PI
	level.get_node("HUD/Help/Text").text="D3.1 BACK CARRY REVIEW\nWASD move | Shift sprint | 1/2/3 weapons\nK: spawn enemy to review Draw/Holster\nStarts M4A1 STOWED, no enemy."
	await create_timer(.6).timeout
	var behavior:Node=level.player.get_node("WeaponBehavior")
	assert(behavior.state==behavior.State.STOWED and level.player.visual.socket.current_attachment==&"back")
	DirAccess.make_dir_recursive_absolute("res://.validation/back_carry_d31")
	if "--smoke" in OS.get_cmdline_user_args():print("D31 review M4 STOWED ready");quit();return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/back_carry_d31/live_review.png")
