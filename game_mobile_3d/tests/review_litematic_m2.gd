extends SceneTree
## Independent real-renderer review: production input, collision, visible wind and exact-map views.
var level: Node3D
var player: CharacterBody3D
var failures: Array[String] = []
var observations := {}
var out := ProjectSettings.globalize_path("res://").path_join("../.validation/m2_litematic/rendered_review")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("M2 GPU REVIEW: "+label)

func tick(count: int) -> void:
	for i in range(count): await physics_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(),"Rendered capture "+label)
	if image != null: check(image.save_png(out+"/"+label+".png")==OK,"Saved capture "+label)
	print("M2_CAPTURE "+label)

func walk(label: String, start: Vector3, sprint: bool = false) -> void:
	player.global_position = start
	player.velocity = Vector3.ZERO
	level.motion = load("res://scripts/grassland_motion.gd").new()
	await tick(15)
	var before := player.global_position
	Input.action_press("move_forward")
	if sprint: Input.action_press("sprint")
	await tick(40)
	var travel := Vector2(before.x-player.position.x,before.z-player.position.z).length()
	check(travel > (2.8 if sprint else 1.8),label+" traverses source terrain")
	check(player.is_on_floor() and absf(player.position.y-2.0)<0.08,label+" retains source floor height")
	check(absf(player.current_speed-(6.25 if sprint else 4.25))<0.25,label+" retains production movement speed")
	check(level.motion.active_count>0,label+" publishes Player grass interaction")
	check(level.grass_material.get_shader_parameter("wind_phase")==level.tall_grass_material.get_shader_parameter("wind_phase"),label+" synchronized global wind")
	observations[label] = {"travel_m":travel,"speed_m_s":player.current_speed,"floor_y":player.position.y,"active_trail_samples":level.motion.active_count}
	await capture(label)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await tick(65)
	check(level.motion.active_count==0,label+" interaction recovers")

func profile() -> void:
	var frame_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var gpu_ms: Array[float] = []
	for i in range(90):
		await process_frame
		frame_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	frame_ms.sort(); draw_calls.sort(); gpu_ms.sort()
	observations.performance = {"samples":90,"cpu_process_median_ms":frame_ms[45],"cpu_process_p95_ms":frame_ms[85],"draw_calls_median":draw_calls[45],"gpu_render_median_ms":gpu_ms[45],"gpu_render_p95_ms":gpu_ms[85],"note":"Desktop real-time Mobile renderer; not a phone benchmark. Viewport captures excluded from samples."}

func run() -> void:
	if not ResourceLoader.exists("res://scenes/maps/m2_v1/LitematicMapPreview.tscn"):
		check(false,"M2 imported scene exists"); quit(1); return
	DirAccess.make_dir_recursive_absolute(out)
	level = load("res://scenes/maps/m2_v1/LitematicMapPreview.tscn").instantiate()
	root.add_child(level); current_scene = level
	player = level.get_node("Actors/Player")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await tick(60)
	check(get_nodes_in_group("zombies").is_empty(),"Peaceful startup")
	check(player.is_on_floor() and absf(player.position.y-2.0)<0.08,"Safe central production Player spawn")
	observations.map = level.get_map_summary()
	await capture("01_gameplay_spawn")
	await walk("02_walk_short_and_tall",Vector3(5.5,2.02,29.5))
	await walk("03_sprint",Vector3(18.5,2.02,31.5),true)
	# One-block source stone cliffs must stay solid; no controller/step-height changes.
	player.position = Vector3(23.8,2.02,12.5); player.velocity=Vector3.ZERO
	await tick(15)
	Input.action_press("move_right")
	await tick(35)
	Input.action_release("move_right")
	check(player.position.x<24.75 and player.position.x>24.3,"Authored elevated stone edge blocks the capsule")
	check(player.is_on_floor() and absf(player.position.y-2)<0.08,"Stone collision does not drop through terrain")
	observations.stone_edge_position = [player.position.x,player.position.y,player.position.z]
	await capture("04_stone_edge_collision")
	for index in range(3):
		player.equip_test_weapon(index)
		await tick(3)
		check(player.get_node("Pistol").weapon_type==index,"Production weapon selection "+str(index))
	level.reset_player(); await tick(20)
	await profile()
	level.set_review_view("overhead"); await tick(3)
	await capture("05_overhead_source_alignment")
	level.set_review_view("isometric"); await tick(3)
	await capture("06_isometric_map")
	# Compare vegetation alone at a fixed camera, using the actual shader/renderer.
	level.set_review_view("gameplay")
	player.position=Vector3(5.5,2.02,27.5); player.velocity=Vector3.ZERO
	await tick(5)
	player.hide(); player.set_physics_process(false); level.set_physics_process(false)
	var empty := PackedVector4Array(); empty.resize(8)
	for material in [level.grass_material,level.tall_grass_material]:
		material.set_shader_parameter("motion_start",empty)
		material.set_shader_parameter("motion_end",empty)
		material.set_shader_parameter("wind_phase",0.0)
	await capture("07_wind_phase_zero")
	for material in [level.grass_material,level.tall_grass_material]: material.set_shader_parameter("wind_phase",PI/2)
	await capture("08_wind_phase_quarter")
	for material in [level.grass_material,level.tall_grass_material]:
		material.set_shader_parameter("wind_strength",0.0)
		material.set_shader_parameter("motion_start",PackedVector4Array([Vector4(5.4,27.5,0.2,0.09),Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO]))
		material.set_shader_parameter("motion_end",PackedVector4Array([Vector4(5.6,27.5,0.0,0.07),Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO]))
	await capture("09_player_reaction")
	for material in [level.grass_material,level.tall_grass_material]:
		material.set_shader_parameter("motion_start",empty); material.set_shader_parameter("motion_end",empty)
	await capture("10_planted_rest")
	observations.renderer=RenderingServer.get_current_rendering_method()
	observations.device=RenderingServer.get_video_adapter_name()
	observations.resolution=[root.size.x,root.size.y]
	observations.failures=failures
	var report_file := FileAccess.open(out+"/review_report.json",FileAccess.WRITE)
	check(report_file!=null,"Writable review report")
	if report_file: report_file.store_string(JSON.stringify(observations,"\t"))
	print("M2_GPU_REVIEW "+JSON.stringify(observations))
	quit(0 if failures.is_empty() else 1)
