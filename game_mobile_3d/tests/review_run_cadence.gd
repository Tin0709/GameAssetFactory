extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level := preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false
	level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(0)
	var player: CharacterBody3D = level.player
	player.get_node("Pistol").enabled=false
	for scale in [1.0,1.5,1.6,1.65,1.94159658]:
		player.visual.run_animation_speed_scale=scale
		player.position=Vector3(0,0.02,-4);player.velocity=Vector3.ZERO
		Input.action_press("move_backward");Input.action_press("sprint")
		for f in 25:await physics_frame
		for i in 20:
			for f in 3:await physics_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/cadence_%03d_%02d.png" % [roundi(scale*100),i])
		Input.action_release("move_backward");Input.action_release("sprint")
		for f in 25:await physics_frame
	quit()
