extends Node
## Optional visual check with a real renderer, not headless.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := load("res://scenes/main.tscn").instantiate() as Node2D
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await get_tree().create_timer(2.25).timeout
	# Keep an actor in view for visual QA regardless of the random spawn angle.
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.global_position = world.player.global_position + Vector2(250, 80)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.validation/preview.png")
	world.queue_free()
	for player in get_tree().root.get_node("Sound").get_children():
		player.stop()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
