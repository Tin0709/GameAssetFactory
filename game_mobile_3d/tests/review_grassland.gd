extends SceneTree
## Render actual scene with real controller inputs; save review captures and metrics.
var level: Node3D
var player: CharacterBody3D
var samples: Array[Dictionary] = []
var out := "res://.validation/grassland_review"

func _initialize() -> void:
	call_deferred("run")

func tick(count: int) -> void:
	for i in range(count):
		await physics_frame
		if i > 3:
			samples.append({"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out + "/" + label + ".png")
	print("GRASSLAND_CAPTURE " + label + " speed=" + str(player.current_speed) + " trail=" + str(level.motion.active_count))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	level = load("res://scenes/Grassland.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Actors/Player")
	await tick(30)
	await capture("01_standing_wind")
	await tick(60)
	await capture("02_wind_next_phase")
	Input.action_press("move_forward")
	await tick(90)
	await capture("03_walking_forward")
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await tick(65)
	await capture("04_walking_sideways")
	Input.action_press("sprint")
	await tick(65)
	await capture("05_sprinting")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await tick(20)
	await capture("06_fast_reversal")
	Input.action_release("move_left")
	Input.action_release("sprint")
	await tick(15)
	await capture("07_stopping_followthrough")
	await tick(90)
	await capture("08_recovered_wind")
	player.global_position = Vector3(17, 1.02, 17)
	player.velocity = Vector3.ZERO
	await tick(15)
	await capture("09_boundary_dirt_sides")
	# Detailed crop from the same assets/material, close to the real player's path.
	level.get_node("HUD").visible = false
	var camera: Camera3D = level.get_node("Camera3D")
	level.set_process(false)
	camera.size = 3.6
	var patch: Transform3D = level.grass_transforms[0]
	camera.position = patch.origin + level.camera_offset
	await tick(10)
	await capture("10_grass_detail")
	var process_sum := 0.0
	var draw_max := 0.0
	var primitives_max := 0.0
	for sample in samples:
		process_sum += float(sample.process_ms)
		draw_max = maxf(draw_max, float(sample.draw_calls))
		primitives_max = maxf(primitives_max, float(sample.primitives))
	var report := {"frames": samples.size(), "mean_process_ms": process_sum / samples.size(), "max_draw_calls": draw_max,
		"max_rendered_primitives": primitives_max, "terrain_triangles": level.terrain_triangles,
		"grass_patches": level.grass_transforms.size(), "grass_triangles_all_map": level.grass_transforms.size() * 294,
		"enemies": get_nodes_in_group("zombies").size(), "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "note": "Desktop scripted render, fixed 60fps; process time is CPU frame time, not a mobile GPU benchmark."}
	FileAccess.open(out + "/performance.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	# Capture-loop CPU monitor includes initial loading/readback. The separate warm
	# profile_grassland.gd is the performance evidence for this map.
	report["note"] = "Scripted visual captures, fixed 60fps. Capture/loading costs make CPU means unsuitable for performance claims; see grassland_profile.json."
	print(JSON.stringify(report))
	quit()
