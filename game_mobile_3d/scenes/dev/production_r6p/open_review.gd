extends SceneTree
## Leave the normal production game playable in its Reference default.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var level=load("res://scenes/CuboidGameplayTest.tscn").instantiate()
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	assert(level.player.visual.locomotion_mode==1)
	await create_timer(1.0).timeout;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.validation/locomotion_r6p")
	root.get_texture().get_image().save_png("res://.validation/locomotion_r6p/production_open_reference.png")
	print("R6P_REAL_GAME_OPEN_REFERENCE — WASD / Shift; F6 Legacy/Reference; 1/2/3 weapons; R reset")
