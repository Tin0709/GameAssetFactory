extends SceneTree
## Real gameplay scene and state machine; startup selection only.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	root.add_child(level);current_scene=level
	level.select_test_weapon(1)
	level.toggle_animation_test_enemy()
	if "--capture" in OS.get_cmdline_user_args():
		for i in 150: await physics_frame
		paused=true
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.validation/r13/gameplay_button.png")
		paused=false;quit()
