extends SceneTree
## Actual current-main pixels. Offline capture is never a performance measurement.
const OUT := "res://.validation/flower_patch_v1"
var level: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func tick(count: int) -> void:
	for i in count: await physics_frame

func capture(label: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
	print("FLOWER_CAPTURE "+label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	level=load("res://scenes/ForestMeadowV3.tscn").instantiate()
	root.add_child(level); current_scene=level
	level.set_enemies_enabled(false)
	player=level.player
	await tick(4)
	if "--clip" in OS.get_cmdline_user_args():
		await movie()
	else:
		await matched()
	level.queue_free()
	await tick(3)
	quit()

func matched() -> void:
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var prefix := "before" if baseline else "after"
	player.global_position=Vector3(-2.5,level.ground_height(-2.5,-2.5)+.02,-2.5)
	player.velocity=Vector3.ZERO
	await tick(30)
	level.process_mode=Node.PROCESS_MODE_DISABLED
	level.review_label.hide()
	level.get_node("HUD").hide()
	for material in [level.grass_material,level.forest_blade_material,level.flower_material]:
		material.set_shader_parameter("wind_phase",1.3)
	for property in level.get_property_list():
		if property.name=="meadow_flower_material":
			level.get("meadow_flower_material").set_shader_parameter("wind_phase",1.3)
	var camera: Camera3D=level.get_node("Camera3D")
	camera.position=player.global_position+level.camera_offset
	await capture(prefix+"_gameplay")
	camera.size=4.5
	camera.position=Vector3(-3.7,level.ground_height(-3.7,-2.5),-2.5)+level.camera_offset
	await capture(prefix+"_detail")
	FileAccess.open(OUT+"/"+prefix+"_capture.json",FileAccess.WRITE).store_string(JSON.stringify({"scene":"ForestMeadowV3","renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"player":str(player.global_position),"camera_detail":str(camera.position),"size_detail":camera.size,"phase":1.3,"grass_shadows":level.review_grass_shadows,"haze":level.review_atmosphere,"warmth":level.review_warmth,"art_approved":false},"\t"))

func movie() -> void:
	level.get_node("HUD").hide()
	level.review_label.text="GODOT · FLOWER PASSAGE / RETURN / RECOVERY\n30 FPS OFFLINE CAPTURE · NOT A PERFORMANCE MEASUREMENT"
	player.global_position=Vector3(-2.5,level.ground_height(-2.5,-2.5)+.02,-2.5)
	player.velocity=Vector3.ZERO
	level.set_process(false)
	var camera: Camera3D=level.get_node("Camera3D")
	camera.size=5.5
	camera.position=Vector3(-3.7,1.0,-2.5)+level.camera_offset
	await tick(35)
	Input.action_press("move_left")
	await tick(35)
	Input.action_release("move_left")
	await tick(20)
	Input.action_press("move_right")
	await tick(35)
	Input.action_release("move_right")
	await tick(55)
	Input.action_press("sprint");Input.action_press("move_left")
	await tick(21)
	Input.action_release("move_left");Input.action_release("sprint")
	await tick(65)
	FileAccess.open(OUT+"/movie.json",FileAccess.WRITE).store_string(JSON.stringify({"last_content_frame":Engine.get_frames_drawn(),"scene":"ForestMeadowV3","offline_fps":30,"performance_measurement":false,"art_approved":false,"sequence":"idle, walk left, stop, return right, recover, sprint left, recover","final_player":str(player.global_position)},"\t"))
	print("FLOWER_MOVIE_COMPLETE "+str(player.global_position))
