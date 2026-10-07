extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var lab=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate()
	root.add_child(lab);current_scene=lab
	for i in 30:await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/locomotion_r4g/lab_open.png")
	print("R4G_MANUAL_WINDOW_OPEN: WASD/Shift ready; B turning blend; no auto movement")
