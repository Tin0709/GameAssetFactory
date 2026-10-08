extends SceneTree
## One appearance per process; real wall-clock warmup and no readbacks while sampling.
var level: Node3D
var mode := "mobile"
var values: Array[Dictionary] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look="): mode = arg.trim_prefix("--look=")
	call_deferred("run")

func sample_window(seconds: float, moving := false) -> void:
	var started := Time.get_ticks_msec()
	var direction := 1
	while Time.get_ticks_msec() - started < seconds * 1000.0:
		await process_frame
		if moving:
			if level.player.position.x > 6.0: direction = -1
			elif level.player.position.x < -6.0: direction = 1
			Input.action_release("move_left" if direction == 1 else "move_right")
			Input.action_press("move_right" if direction == 1 else "move_left")
		var rid := root.get_viewport_rid()
		values.append({"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid),
			"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})

func summarize() -> Dictionary:
	var result := {}
	for key in ["process_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls", "primitives"]:
		var ordered: Array[float] = []
		var total := 0.0
		for sample in values:
			ordered.append(float(sample[key]))
			total += float(sample[key])
		ordered.sort()
		result[key] = {"mean": total / ordered.size(), "median": ordered[ordered.size() / 2], "p95": ordered[int(ordered.size() * 0.95)]}
	values.clear()
	return result

func run() -> void:
	if mode not in ["current", "mobile", "high"]:
		push_error("Use --look=current|mobile|high")
		quit(1)
		return
	level = load("res://scenes/Grassland.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.set_quality(mode == "high")
	level.set_look(mode != "current")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await create_timer(3.0).timeout
	await sample_window(3.0)
	var idle := summarize()
	Input.action_press("move_right")
	Input.action_press("sprint")
	await create_timer(1.2).timeout
	await sample_window(3.0, true)
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("sprint")
	var sprint := summarize()
	level.reset_player()
	level.set_process(false)
	var camera: Camera3D = level.get_node("Camera3D")
	camera.size = 64
	camera.position = Vector3(40, 51, 54)
	camera.far = 160
	await create_timer(2.1).timeout
	await sample_window(3.0)
	var overview := summarize()
	var report := {"appearance": mode, "idle": idle, "sprinting": sprint, "whole_map": overview,
		"device": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"resolution": root.size, "grass_patches": level.grass_transforms.size(), "terrain_triangles": level.terrain_triangles,
		"note": "Warm desktop, one appearance per process, serial runs, uncapped, no screenshot readback. CPU monitor updates once per second. Target-phone measurements required."}
	FileAccess.open("res://.validation/v4_profile_" + mode + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
