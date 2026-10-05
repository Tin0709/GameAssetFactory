extends SceneTree
## Runtime-only inspection: authored assets, fixed bones, standing/moving fire.
const PLAYER = preload("res://scenes/characters/CuboidPlayer.tscn")
const POSES = ["Idle / LowReady", "Walk / LowReady", "Run / LowReady", "Idle / Aim", "Standing fire", "Running fire"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i(1600, 1000)
	root.size = Vector2i(1600, 1000)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("354654")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.85
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.8
	var actors: Array[Node3D] = []
	var target := Node3D.new()
	world.add_child(target)
	for pose in POSES.size():
		var actor := PLAYER.instantiate() as Node3D
		world.add_child(actor)
		actor.set_physics_process(false)
		actor.get_node("Pistol").enabled = false
		actor.visual.set_process(false)
		actor.position = Vector3((pose % 3 - 1) * 2.6, 0, (pose / 3 - 0.5) * 3.0)
		var label := Label3D.new()
		label.position.y = 2.1
		label.text = POSES[pose]
		label.font_size = 30
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)
		actors.append(actor)
	for weapon in 3:
		for pose in POSES.size():
			var actor := actors[pose]
			var visual: Node3D = actor.visual
			actor.equip_test_weapon(weapon)
			target.position = actor.position + Vector3(0, 0, 5)
			var velocity := Vector3.ZERO
			if pose == 1: velocity = Vector3.BACK * 4.25
			if pose in [2, 5]: velocity = Vector3.BACK * 6.25
			for frame in 30:
				visual.update_motion(velocity, target if pose >= 3 else null, 1.0 / 60.0)
				visual._process(1.0 / 60.0)
			if pose >= 4:
				visual.shot_recoil(Vector3.BACK)
				visual._process(0.08)
		for angle in ["isometric", "close"]:
			camera.position = Vector3(9, 11, 12) if angle == "isometric" else Vector3(3, 4, 12)
			camera.look_at(Vector3(0, 0.9, 0))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/weapon_hold_%s_%s.png" % [actors[0].visual.WEAPON_NAMES[weapon].to_lower(), angle])
	world.queue_free()
	await process_frame
	quit()
