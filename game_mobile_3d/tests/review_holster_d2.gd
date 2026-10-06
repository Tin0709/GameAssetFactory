extends SceneTree
## Interactive review of the real gameplay state machine, M4 equipped.
## Review-only H: remove review enemies, then trigger the normal holster grace.
## K uses existing gameplay enemy spawning to request forward placeholder Draw.
var level: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	level.get_node("SpawnDirector").enabled=false
	level.get_node("Progression").enabled=false
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	var controls=preload("res://tests/review_holster_d2_controls.gd").new()
	controls.level=level;root.add_child(controls)
	var help: Label=level.get_node("HUD/Help/Text")
	help.text+="\nD2 review: K enemy/draw | H clear threats/holster"
	var behavior: Node=level.player.get_node("WeaponBehavior")
	behavior.weapon_attach_to_hand();behavior._set_state(behavior.State.READY)
	# Review starts READY and stays there until H or a real threat has occurred.
	# This affects only the standalone review harness, never production behavior.
	behavior.grace_elapsed=-100000.0
	if not "--smoke" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://.validation/holster_d2")
		for i in 60: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.validation/holster_d2/live_review.png")
	if "--smoke" in OS.get_cmdline_user_args():
		var key=InputEventKey.new();key.keycode=KEY_H;key.pressed=true
		controls._unhandled_input(key)
		for i in 55: await physics_frame
		assert(behavior.state==behavior.State.STOWED and level.player.visual.socket.current_attachment==&"back")
		print("D2 review H -> STOWED verified");quit()
