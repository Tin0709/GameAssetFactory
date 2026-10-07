extends SceneTree
## Actual main game; --capture produces short clips using real WASD/targeting.
var level: Node3D
func _initialize() -> void: call_deferred("run")
func release_movement() -> void:
	for action in ["move_left","move_right","move_forward","move_backward","sprint"]:Input.action_release(action)
func ticks(count: int) -> void:
	for i in count:await physics_frame
	await process_frame
func run() -> void:
	level=preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	root.add_child(level);current_scene=level;level.select_test_weapon(1)
	level.toggle_animation_test_enemy()
	if not "--capture" in OS.get_cmdline_user_args():return
	DirAccess.make_dir_recursive_absolute("res://.validation/r15/frames")
	root.size=Vector2i(900,700)
	var player: CharacterBody3D=level.player
	var camera: Camera3D=level.get_node("Camera3D")
	level.get_node("HUD").visible=false
	var evidence: Array[Dictionary]=[]
	for weapon in 3:
		for direction in ["right","left"]:
			release_movement();player.position=Vector3(0,.02,3);player.velocity=Vector3.ZERO
			player.equip_test_weapon(weapon);player.get_node("Pistol").cooldown=100000
			await ticks(60)
			Input.action_press("move_"+direction)
			await ticks(20)
			for frame in 25:
				await ticks(2)
				var visual: Node3D=player.visual
				camera.position=player.position+visual.global_basis*Vector3(3,2.5,5)
				camera.look_at(player.position+Vector3(0,1,0));camera.size=2.65
				await process_frame;await RenderingServer.frame_post_draw
				var path:="res://.validation/r15/frames/%d_%s_%02d.png"%[weapon,direction,frame]
				root.get_texture().get_image().save_png(path)
				evidence.append({"weapon":weapon,"direction":direction,"frame":frame,"strafe_direction":visual.combat_strafe_direction,"weight":visual.combat_strafe_weight,"twist_deg":rad_to_deg(visual.combat_torso_twist()),"phase":visual.combat_strafe_phase})
			print("R15 captured weapon ",weapon," ",direction)
	release_movement()
	FileAccess.open("res://.validation/r15/render_evidence.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	quit()
