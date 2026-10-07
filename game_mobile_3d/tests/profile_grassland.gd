extends SceneTree
## Warm full-scene desktop profile, without screenshot readback in the sample window.
var level: Node3D
var values: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func tick(count: int, record := false) -> void:
	for i in range(count):
		await process_frame
		if record:
			var rid := root.get_viewport_rid()
			values.append({"frame_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
				"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid),
				"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid),
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})

func summarize() -> Dictionary:
	var result := {}
	for key in ["frame_process_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls", "primitives"]:
		var ordered: Array[float] = []
		for sample in values: ordered.append(float(sample[key]))
		ordered.sort()
		var sum := 0.0
		for number in ordered: sum += number
		result[key] = {"mean": sum / ordered.size(), "median": ordered[ordered.size() / 2], "p95": ordered[int(ordered.size() * 0.95)]}
	values.clear()
	return result

func run() -> void:
	level = load("res://scenes/Grassland.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# Performance.TIME_PROCESS refreshes once a second. Let cold loading/compile samples expire.
	await create_timer(2.5).timeout
	await tick(60)
	await tick(240, true)
	var idle := summarize()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await create_timer(1.2).timeout
	await tick(140, true)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var sprint := summarize()
	# Worst-case overview: all chunks/patches visible in the same scene.
	level.set_process(false)
	var camera: Camera3D = level.get_node("Camera3D")
	camera.size = 64
	camera.position = Vector3(40, 51, 54)
	camera.far = 160
	await create_timer(1.2).timeout
	await tick(240, true)
	var overview := summarize()
	var report := {"idle": idle, "sprinting": sprint, "whole_map": overview,
		"device": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"resolution": root.size, "note": "Warm desktop profile, uncapped rendering, no capture readback. Phone measurements remain pending."}
	FileAccess.open("res://.validation/grassland_profile.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
