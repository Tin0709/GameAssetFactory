extends SceneTree
## Catch leaked resources, incomplete A/B restoration and controller interruptions.
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int) -> void:
	for i in range(count): await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://scenes/GrasslandLookDev.tscn"), "Dedicated look-dev scene is available")
	if not failures.is_empty():
		quit(1)
		return
	var original = load("res://scenes/Grassland.tscn").instantiate()
	root.add_child(original)
	await tick(8)
	root.remove_child(original)
	var level = load("res://scenes/GrasslandLookDev.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await tick(8)
	var environment: Environment = original.original_environment
	var prior_sun: Dictionary = original.original_sun
	var camera: Camera3D = level.get_node("Camera3D")
	var camera_rotation := camera.rotation
	var camera_size := camera.size
	var player: CharacterBody3D = level.get_node("Actors/Player")
	check(level.new_look and not level.high_quality, "Starts in new mobile appearance")
	check(level.cell_count == 1600 and level.grass_transforms.size() == 400, "Original map population retained")
	check(level.grass_transforms == original.grass_transforms, "Seeded source distribution retained")
	check(level.grass_mesh == original.grass_mesh, "Review and actual game share v4 imported geometry")
	check(player.get_script() == original.player.get_script(), "Production controller retained")
	check(level.get_node("WorldEnvironment").environment != environment, "New environment is scene-local")
	var count: int = level.find_children("*", "Node", true, false).size()
	Input.action_press("move_forward")
	await tick(30)
	var moving_position := player.global_position
	check(player.current_speed > 4.0 and level.motion.active_count > 0, "Walking and grass interaction work")
	for i in range(5):
		level.set_look(false)
		check(level.grass_material.shader == original.original_grass.shader, "Current uses actual original shader")
		check(level.get_node("WorldEnvironment").environment == level.original_environment and level.original_environment.background_color == environment.background_color and not level.original_environment.fog_enabled, "Current restores previous appearance with fog fully disabled")
		check(level.get_node("Sun").rotation == prior_sun.rotation and level.get_node("Sun").light_energy == prior_sun.light_energy, "Current restores original lighting")
		for chunk in level.get_node("Grass").get_children():
			check(chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Current restores grass shadow state")
			check(is_equal_approx(chunk.extra_cull_margin, 0.15), "Current restores original culling margin")
		for chunk in level.get_node("Terrain").get_children():
			check(chunk.material_override is StandardMaterial3D, "Current restores original terrain material")
		level.set_quality(true)
		level.set_look(true)
		for chunk in level.get_node("Grass").get_children():
			check(chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "High never casts grass shadows")
			check(chunk.extra_cull_margin >= 0.20, "New expanded bend stays within culling margin")
		level.set_quality(false)
	check(level.find_children("*", "Node", true, false).size() == count, "Repeated switching does not accumulate nodes")
	check(camera.rotation == camera_rotation and camera.size == camera_size, "Switching preserves gameplay camera")
	check(player.global_position == moving_position, "Switching never resets player")
	await tick(20)
	check(player.global_position.distance_to(moving_position) > 1.0, "Movement continues after switching")
	Input.action_press("sprint")
	await tick(30)
	check(player.fast_sprinting and player.current_speed > 6.0, "Sprint retained")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await tick(80)
	check(level.motion.active_count == 0, "Interaction history recovers")
	check(get_nodes_in_group("zombies").is_empty(), "No enemies")
	level.toggle_animation_test_enemy()
	await tick(2)
	check(get_nodes_in_group("zombies").is_empty(), "Inherited combat toggle cannot spawn an enemy in look-dev")
	var combat_key := InputEventKey.new()
	combat_key.physical_keycode = KEY_F7
	combat_key.pressed = true
	Input.parse_input_event(combat_key)
	await tick(2)
	check(get_nodes_in_group("zombies").is_empty(), "F7 cannot spawn an enemy in look-dev")
	check(is_equal_approx(environment.ambient_light_energy, 0.65) and is_equal_approx(prior_sun.light_energy, 1.25), "Production resources were not mutated")
	level.queue_free()
	await tick(2)
	check(original.grass_material.shader.resource_path == "res://materials/lookdev_grass.gdshader", "Actual game remains in v4 after review is freed")
	original.free()
	var report := {"checks": checks, "failures": failures}
	FileAccess.open("res://.validation/lookdev_contract.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
