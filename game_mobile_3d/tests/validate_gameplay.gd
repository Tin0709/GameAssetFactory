extends SceneTree
const FIXTURE = preload("res://tests/legacy_fixture.gd")
## Exercise actual physics/input/animations. Run headless, or add -- --capture.

var checks: int = 0
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("GAMEPLAY TEST FAILED: " + message)
		quit(1)

func tick(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	var packed := load("res://scenes/CuboidGameplayTest.tscn") as PackedScene
	check(packed != null, "Test level loads")
	if failed: return
	var level := packed.instantiate()
	FIXTURE.prepare(level)
	# Keep this movement/import regression suite independent of the combat suite.
	level.get_node("Combat").combat_enabled = false
	root.add_child(level)
	current_scene = level
	await tick(4)
	# Let the native window finish its initial focus change before injected keys.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout
	var player: CharacterBody3D = level.get_node("Actors/Player")
	var zombies := get_nodes_in_group("zombies")
	check(zombies.size() == 3, "Three zombies spawned")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile", "Mobile renderer retained")
	check(level.get_node("Camera3D").current, "Isometric camera active")
	check(level.get_node("WorldEnvironment").environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "Inexpensive ambient color fill")
	check(level.find_children("*", "Light3D", true, false).size() == 1, "Single sun lighting")
	for actor in [player] + zombies:
		var visual: Node3D = actor.get_node("Visual")
		var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
		check(skeleton != null and skeleton.get_bone_count() == (11 if actor == player else 10), "Original bones plus player weapon socket")
		check(visual.meshes.size() == 1, "Single character mesh per actor, excluding attachments")
		for mesh: MeshInstance3D in visual.meshes:
			check(mesh.mesh.get_faces().size() / 3 == 72, "72 triangles per imported actor")
			var material := mesh.mesh.surface_get_material(0) as BaseMaterial3D
			check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Nearest pixel sampling")
			check(material.albedo_texture.get_width() == 64 and material.albedo_texture.get_height() == 64, "64x64 embedded atlas")
			check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Opaque mobile material")
		for state in (["Idle", "Walk", "Run"] if actor == player else ["Idle", "Walk"]):
			var clip: String = visual.animation_prefix + "_" + state
			check(visual.animation_player.has_animation(clip), "Named animation preserved: " + clip)
			check(visual.animation_player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "Loop configured: " + clip)
		for i in range(skeleton.get_bone_count()):
			check(skeleton.get_bone_pose_scale(i).is_equal_approx(Vector3.ONE), "No block scaling")
	if failed: return
	# Isolate movement from enemies so collision does not mask controller assertions.
	for zombie in zombies: zombie.set_physics_process(false)
	var keyboard_start := player.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await tick(8)
	check(player.position.z < keyboard_start.z - 0.08, "Physical W keyboard binding works")
	key.pressed = false
	Input.parse_input_event(key)
	await tick(2)
	var start := player.position
	Input.action_press("move_left")
	await tick(30)
	check(player.position.x < start.x - 0.4, "WASD moves in world space")
	check(player.get_node("Visual").current_state == &"Walk", "Moving selects Player_Walk")
	var facing := Vector3.FORWARD * -1.0
	facing = facing.rotated(Vector3.UP, player.get_node("Visual").rotation.y)
	check(facing.dot(Vector3.LEFT) > 0.95, "Imported +Z face turns toward movement")
	Input.action_release("move_left")
	Input.action_press("move_forward")
	Input.action_press("move_right")
	Input.action_press("sprint")
	await tick(24)
	check(player.get_node("Visual").current_state == &"Run", "Shift selects Player_Run")
	check(Vector2(player.velocity.x, player.velocity.z).length() <= player.run_speed + 0.001, "Diagonal movement normalized")
	check(Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed, "Run is faster than walk")
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("sprint")
	await tick(8)
	check(player.get_node("Visual").current_state == &"Idle", "Stopped selects Player_Idle")
	check(player.is_on_floor(), "Floor collision holds player")
	# Physical bounds prevent walking off the platform.
	player.position = Vector3(7.3, 0.01, 0.0)
	Input.action_press("move_right")
	await tick(40)
	check(player.position.x <= 7.71, "Arena boundary blocks movement")
	Input.action_release("move_right")
	player.set_physics_process(false)
	player.position = Vector3.ZERO
	var zombie: CharacterBody3D = zombies[0]
	zombie.position = Vector3(4, 0.01, 0)
	zombie.set_physics_process(true)
	var before := zombie.position.distance_to(player.position)
	await tick(50)
	check(zombie.position.distance_to(player.position) < before - 0.35, "Zombie approaches player within range")
	check(zombie.get_node("Visual").current_state == &"Walk", "Chase selects Zombie_Walk")
	player.position = Vector3(-8, 0, -5)
	await tick(8)
	check(not zombie.chasing and zombie.get_node("Visual").current_state == &"Idle", "Outside lose range selects Zombie_Idle")
	player.position = Vector3.ZERO
	zombie.position = Vector3(0.85, 0.01, 0)
	await tick(8)
	check(zombie.get_node("Visual").current_state == &"Idle", "Zombie stops near player without attacking")
	player.position = Vector3(3, 0, 0)
	await tick(8)
	check(zombie.get_node("Visual").current_state == &"Walk", "Chase resumes after player leaves stop distance")
	if failed: return
	# Check every imported clip at both endpoints and intermediate poses.
	for actor in [player, zombie]:
		actor.set_physics_process(false)
		var visual: Node3D = actor.get_node("Visual")
		var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
		for clip in visual.animation_player.get_animation_list():
			if not String(clip).begins_with(visual.animation_prefix + "_"): continue
			var animation: Animation = visual.animation_player.get_animation(clip)
			visual.animation_player.play(clip, 0)
			visual.animation_player.seek(0, true)
			var first: Array[Transform3D] = []
			for i in range(skeleton.get_bone_count()): first.append(skeleton.get_bone_global_pose(i))
			for t in [0.25, 0.5, 0.75, 1.0]:
				visual.animation_player.seek(animation.length * t, true)
				for i in range(skeleton.get_bone_count()):
					check(skeleton.get_bone_global_pose(i).basis.get_scale().is_equal_approx(Vector3.ONE), "Rigid animation basis: " + clip)
			visual.animation_player.seek(animation.length, true)
			for i in range(skeleton.get_bone_count()):
				check(skeleton.get_bone_global_pose(i).is_equal_approx(first[i]), "Imported loop endpoints match: " + clip)
	if failed: return
	var reset_event := InputEventAction.new()
	reset_event.action = "reset_test"
	reset_event.pressed = true
	level._unhandled_input(reset_event)
	await process_frame
	await tick(5)
	check(current_scene != level, "R resets the test scene")
	FIXTURE.after_reset(current_scene)
	current_scene.get_node("Combat").combat_enabled = false
	if failed: return
	if "--capture" in OS.get_cmdline_user_args():
		check(DisplayServer.get_name() != "headless", "Capture needs a rendered run")
		check(RenderingServer.get_current_rendering_method() == "mobile", "GPU capture uses Mobile")
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://tests/gameplay_preview.png") == OK, "Gameplay screenshot saved")
	var meshes := current_scene.find_children("*", "MeshInstance3D", true, false)
	var triangles := 0
	var casters := 0
	for mesh: MeshInstance3D in meshes:
		triangles += mesh.mesh.get_faces().size() / 3
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: casters += 1
	var file := FileAccess.open("res://tests/gameplay_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "checks": checks,
		"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"mesh_instances": meshes.size(), "triangles": triangles, "shadow_casters": casters,
		"phone_tested": false, "capture": "--capture" in OS.get_cmdline_user_args()}, "\t"))
	print("GAMEPLAY VALIDATION PASS: %d checks; input, run/idle/walk, collisions, chase/range/stop, rigid imported loops, reset." % checks)
	quit(1 if failed else 0)
