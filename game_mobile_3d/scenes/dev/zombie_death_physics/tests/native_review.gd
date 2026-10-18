extends SceneTree
## Native Mobile-renderer visual/desktop observations. No project-setting writes.
var lab: Node3D
var results: Array[Dictionary] = []
var failures: Array[String] = []
var output_directory := "user://zombie_lab_review"
func _initialize() -> void: call_deferred("run")
func seconds(duration: float) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000)
	while Time.get_ticks_msec() < until: await process_frame
func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_directory.path_join(filename))
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func run() -> void:
	var requested := OS.get_environment("ZOMBIE_LAB_REVIEW_DIR")
	if not requested.is_empty(): output_directory = requested
	DirAccess.make_dir_recursive_absolute(output_directory)
	root.size = Vector2i(1440,900)
	lab = load("res://scenes/dev/ZombieDeathPhysicsLab.tscn").instantiate()
	root.add_child(lab)
	await seconds(0.5)
	await capture("lab_ready.png")
	# Exercise the same selectors/buttons the UI uses, including actual view key path.
	for index in 3:
		lab.animation_choice.select(index)
		lab.animation_choice.item_selected.emit(index)
		lab.weapon_choice.select(index)
		lab.weapon_choice.item_selected.emit(index)
		await seconds(0.15 if index == 2 else 0.5)
		var key := InputEventKey.new()
		key.pressed = true
		key.physical_keycode = [KEY_F1, KEY_F2, KEY_F3][index]
		lab._unhandled_input(key)
		lab.trigger_death()
		await seconds(0.02)
		check(lab.actor.dead, "Native UI-selected handoff")
		for stage in 6:
			await seconds(0.18)
			await capture("%s_%d.png" % [["idle_pistol_front", "walk_rifle_side", "attack_shotgun_threequarter"][index], stage])
		check(lab.actor.maximum_skin_position_error < 0.0002, "Native rendered skin follows physics")
	# A scrolled control-panel screenshot proves the lower controls fit and remain reachable.
	var scroll: ScrollContainer = lab.find_child("ExperimentControls", true, false) as ScrollContainer
	check(scroll != null, "Lower UI scroll container exists")
	if scroll:
		scroll.set_deferred("scroll_vertical", int(scroll.get_v_scroll_bar().max_value))
		await seconds(0.1)
		print("SCROLL ", scroll.scroll_vertical, " / ", scroll.get_v_scroll_bar().max_value)
		check(scroll.scroll_vertical > 0, "Lower controls can be reached")
		await capture("lab_controls.png")
		scroll.set_deferred("scroll_vertical", 0)
	# Record actual native performance monitor samples at a 30 FPS display cap.
	for count in [0,1,4,8]:
		lab.animation_choice.select(0)
		if count == 0:
			lab.reset_zombie()
		else:
			lab.maximum_active_ragdolls = count
			lab.stress_test()
		await seconds(0.9)
		var values: Array[float] = []
		var fps: Array[float] = []
		var until := Time.get_ticks_msec() + 2400
		while Time.get_ticks_msec() < until:
			await process_frame
			values.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			fps.append(Performance.get_monitor(Performance.TIME_FPS))
		values.sort()
		fps.sort()
		var mean := 0.0
		for value in values: mean += value
		mean /= values.size()
		results.append({"ragdolls": count, "bodies": count * 7, "joints": count * 6, "monitor_samples": values.size(), "physics_monitor_mean_ms": mean, "physics_monitor_p95_ms": values[int(values.size()*.95)], "physics_monitor_max_ms": values.back(), "display_fps_median": fps[fps.size()/2]})
		if count == 8: await capture("lab_stress8.png")
	var info := {"engine": Engine.get_version_info().string, "physics_hz": Engine.physics_ticks_per_second, "display_cap": Engine.max_fps, "renderer": RenderingServer.get_video_adapter_name(), "measurements": results, "failures": failures}
	FileAccess.open(output_directory.path_join("native_results.json"), FileAccess.WRITE).store_string(JSON.stringify(info,"  "))
	print("NATIVE_REVIEW ", JSON.stringify(info))
	quit(0 if failures.is_empty() else 1)
