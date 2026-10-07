extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab=load("res://scenes/dev/LocomotionTurningLab.tscn").instantiate();root.add_child(lab);current_scene=lab
	lab.actor.set_review_mode(2);lab.automated=true;lab.auto_sprint=true;lab.path_index=1;lab.circle_radius=6.0
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/locomotion_r5/lab_open_C.png")
	print("R5_LEFT_OPEN_C: V3 + calibrated mapping; Sprint 6m CW; F1 hides HUD; Tab cycles A/B/C")
