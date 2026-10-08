extends SceneTree
## Separate matched captures, fixed-timestep movie, and uncapped real-time profiling.
var level: Node3D
var out := "res://.validation/quality_slice"
var stats := {}
var default_profile_stage := 3
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")
func tick(n: int) -> void:
	for i in n: await physics_frame
func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.save_png(out + "/" + label + ".png")
	print("QUALITY_CAPTURE " + label)
func write_report(name: String) -> void:
	FileAccess.open(out + "/" + name + ".json",FileAccess.WRITE).store_string(JSON.stringify(stats,"\t"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	level = load("res://scenes/QualitySlice.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.set_enemies_enabled(false)
	await tick(3)
	stats = {"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[root.size.x,root.size.y],"target_fps":30,"phone_verified":false}
	if "--profile" in OS.get_cmdline_user_args():
		await profile()
	elif "--clip" in OS.get_cmdline_user_args():
		await movie()
	elif "--shadow-probe" in OS.get_cmdline_user_args():
		level.process_mode = Node.PROCESS_MODE_DISABLED
		level.review_label.hide()
		level.get_node("Sun").shadow_bias = level.baseline_sun.shadow_bias
		level.get_node("Sun").shadow_normal_bias = level.baseline_sun.shadow_normal_bias
		await capture("probe_original")
		level.get_node("Sun").shadow_enabled = false
		await capture("probe_no_shadow")
		level.get_node("Sun").shadow_enabled = true
		level.get_node("Sun").shadow_bias = 0.10
		level.get_node("Sun").shadow_normal_bias = 1.5
		await capture("probe_bias")
	else:
		await matched()
	level.set_enemies_enabled(false)
	level.queue_free()
	for i in 3: await process_frame
	# Uncapped frames can finish before the audio thread releases stopped voices.
	if "--profile" in OS.get_cmdline_user_args():
		await create_timer(0.25).timeout
	quit()

func matched() -> void:
	level.player.equip_test_weapon(1)
	var zombie = level.add_review_zombie(Vector3(3,1.02,-2))
	zombie.set_physics_process(false)
	await tick(35)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.review_label.hide()
	stats["camera"] = {"projection":"orthographic","size":level.get_node("Camera3D").size,"position":str(level.get_node("Camera3D").position),"rotation":str(level.get_node("Camera3D").rotation_degrees)}
	for stage in 4:
		level.set_review_stage(stage)
		await capture("stage_%d" % stage)
	level.set_review_stage(3)
	var camera: Camera3D = level.get_node("Camera3D")
	camera.size = 7.5
	await capture("detail")
	stats["note"] = "Same frozen actors, camera and wind phase across stage_0..3. Detail camera is diagnostic only. PNGs are direct Godot viewport readbacks."
	write_report("captures")

func movie() -> void:
	level.player.equip_test_weapon(1)
	level.review_label.text = "GODOT MOBILE · 30 FPS OFFLINE CAPTURE · NOT A PERFORMANCE MEASUREMENT\nWalk / turn / stop → real draw, fire, hit and death → movement under threat"
	level.review_label.show()
	await tick(30)
	Input.action_press("move_forward")
	await tick(40)
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await tick(40)
	Input.action_release("move_right")
	Input.action_press("move_backward")
	await tick(40)
	Input.action_release("move_backward")
	await tick(30)
	level.set_enemies_enabled(true)
	level.add_review_zombie(level.player.position + Vector3(3.2,0,-2.0))
	var max_effects := 0
	var max_projectiles := 0
	for i in 360:
		if i == 100: Input.action_press("move_left")
		if i == 145: Input.action_release("move_left")
		if i == 155: level.add_review_zombie(level.player.position + Vector3(3.0,0,-2.2))
		if i == 160: Input.action_press("move_backward")
		if i == 205: Input.action_release("move_backward")
		max_effects = maxi(max_effects,level.combat.effects.get_child_count())
		max_projectiles = maxi(max_projectiles,level.combat.projectiles.get_child_count())
		await physics_frame
	stats["kills"] = level.combat.kill_count
	stats["peak_effect_nodes"] = max_effects
	stats["peak_projectiles"] = max_projectiles
	stats["last_content_frame"] = Engine.get_frames_drawn()
	stats["note"] = "Offline Movie Maker at 30 FPS; real production controller/animation/combat. Not a speed measurement."
	write_report("movie")
	print("QUALITY_MOVIE " + JSON.stringify(stats))

func summarize(samples: Array, key: String) -> Dictionary:
	var values: Array[float] = []
	for sample in samples: values.append(float(sample[key]))
	values.sort()
	return {"median":values[values.size()/2],"p95":values[int(values.size()*0.95)],"max":values.back()}

func sample_window(seconds: float) -> Dictionary:
	# Snapshot before allocating this window's sample buffer. Do not interpret
	# a growing per-frame dictionary array as game memory growth.
	var static_memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var samples: Array = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var rid := root.get_viewport_rid()
		samples.append({"frame_interval_ms":(now-previous)/1000.0,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"living_zombies":level.combat.living_zombies.size()})
		previous = now
	var summary := {"samples":samples.size(),"seconds":(Time.get_ticks_usec()-start)/1000000.0,"static_memory_before_sampling_bytes":static_memory_before}
	for key in samples[0]: summary[key] = summarize(samples,key)
	return summary

func profile() -> void:
	var stage := default_profile_stage
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = int(arg.trim_prefix("--stage="))
	level.set_review_stage(stage)
	level.review_label.hide()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await create_timer(3.0).timeout
	stats["stage"] = stage
	stats["idle"] = await sample_window(5.0)
	level.set_enemies_enabled(true)
	level.player.current_hp = 100000
	# A reproducible stress fixture, not a recommended mobile enemy budget.
	for i in 12:
		var angle := i * TAU/12.0
		var enemy = level.add_review_zombie(Vector3(cos(angle)*4.5,1.02,sin(angle)*4.5))
		enemy.current_hp = 100000
		enemy.max_hp = 100000
	await create_timer(3.0).timeout
	stats["combat_12_fixture"] = await sample_window(8.0)
	stats["note"] = "Serial desktop uncapped wall-clock sampling; no image readback or movie. 3s warmups, 5s idle, 8s combat. Frame interval includes scheduling; GPU timing is Godot viewport timing, not full device instrumentation. No thermal/mobile inference."
	write_report("profile_stage_%d" % stage)
	print("QUALITY_PROFILE " + JSON.stringify(stats))
