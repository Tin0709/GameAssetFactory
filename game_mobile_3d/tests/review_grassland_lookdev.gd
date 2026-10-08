extends SceneTree
## Paired actual renderer captures. Freeze simulation only across each paired view.
var level: Node3D
var player: CharacterBody3D
const OUT := "res://.validation/grassland_lookdev"

func _initialize() -> void:
	call_deferred("run")

func tick(count: int) -> void:
	for i in range(count): await physics_frame

func capture(label: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")
	print("LOOKDEV_CAPTURE " + label)

func paired(label: String) -> void:
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for mode in ["current", "mobile", "high"]:
		level.set_quality(mode == "high")
		level.set_look(mode != "current")
		await capture(label + "_" + mode)
	level.process_mode = Node.PROCESS_MODE_INHERIT

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	level = load("res://scenes/GrasslandLookDev.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Actors/Player")
	# Startup/capture readback FPS is unsuitable performance evidence.
	level.get_node("HUD/Status").visible = false
	await tick(60)
	await paired("01_standing")
	Input.action_press("move_forward")
	await tick(60)
	await paired("02_walking")
	Input.action_press("sprint")
	Input.action_press("move_right")
	await tick(35)
	await paired("03_sprinting")
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("sprint")
	await tick(90)
	player.global_position = Vector3(17, 1.02, 17)
	player.velocity = Vector3.ZERO
	await tick(15)
	await paired("04_boundary")
	level.get_node("HUD").visible = false
	level.set_process(false)
	var camera: Camera3D = level.get_node("Camera3D")
	camera.size = 3.6
	var patch: Transform3D = level.grass_transforms[0]
	player.global_position = patch.origin + Vector3(0.0, 0.02, 0.7)
	player.velocity = Vector3.ZERO
	camera.position = patch.origin + level.camera_offset
	await tick(15)
	await paired("05_detail")
	# Show a real production-controller passage close to the same grass patch.
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await tick(9)
	await paired("06_detail_splay")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await tick(10)
	await paired("07_detail_wind_next")
	player.global_position = patch.origin + Vector3(3, 0.02, 3)
	player.velocity = Vector3.ZERO
	await tick(60)
	await paired("08_detail_wind_only")
	await tick(60)
	await paired("09_detail_wind_next_phase")
	print("LOOKDEV_CAPTURE_COMPLETE enemies=" + str(get_nodes_in_group("zombies").size()))
	quit()
