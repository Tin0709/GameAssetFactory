extends "res://tests/review_quality_slice.gd"
func run() -> void:
	default_profile_stage = 2
	out = "res://.validation/forest_quality"
	DirAccess.make_dir_recursive_absolute(out)
	level = load("res://scenes/ForestQualitySlice.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.set_enemies_enabled(false)
	await tick(3)
	stats = {"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[root.size.x,root.size.y],"target_fps":30,"phone_verified":false,"art_approved":false}
	if "--profile" in OS.get_cmdline_user_args():
		await profile()
	elif "--clip" in OS.get_cmdline_user_args():
		await movie()
	else:
		await matched()
	level.set_enemies_enabled(false)
	level.queue_free()
	for i in 3: await process_frame
	if "--profile" in OS.get_cmdline_user_args(): await create_timer(0.25).timeout
	quit()

func matched() -> void:
	level.player.equip_test_weapon(1)
	var zombie = level.add_review_zombie(Vector3(3,1.02,-2))
	zombie.set_physics_process(false)
	await tick(35)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.review_label.hide()
	stats["camera"] = {"projection":"orthographic","size":level.get_node("Camera3D").size,"position":str(level.get_node("Camera3D").position),"rotation":str(level.get_node("Camera3D").rotation_degrees)}
	for stage in 3:
		level.set_forest_stage(stage)
		await capture("stage_%d" % stage)
	level.set_forest_stage(2)
	var camera: Camera3D = level.get_node("Camera3D")
	camera.size = 8.0
	await capture("detail")
	camera.size = 14.5
	camera.position = level.camera_offset+Vector3(-3.5,1,-4.5)
	await capture("grove")
	camera.position = level.camera_offset+Vector3(3.5,1,-4.0)
	await capture("courtyard")
	stats["note"] = "Matched frozen camera/actor/wind for stage0(previous QualitySlice), stage1(new assets/terrain, previous light), stage2(new light). Other views diagnostic only."
	write_report("captures")
