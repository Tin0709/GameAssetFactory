extends SceneTree
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
var level: Node3D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func tick(count: int) -> void:
	for i in count: await physics_frame
func key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame
func click(index: int, touch: bool = false) -> void:
	var center: Vector2 = level.weapon_selector.buttons[index].get_global_rect().get_center()
	for down in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = center
			event.pressed = down
			root.push_input(event, true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = center
			event.pressed = down
			root.push_input(event, true)
		await process_frame

func run() -> void:
	level = LEVEL.instantiate()
	root.add_child(level)
	current_scene = level
	var player: CharacterBody3D = level.player
	var visual: Node3D = player.visual
	var combat: Node = level.combat
	var spawner: Node = level.spawner
	var pistol: Node = player.get_node("Pistol")
	check(paused and level.weapon_selector.visible, "Startup selector pauses immediately")
	var start_position := player.position
	var elapsed: float = spawner.elapsed_survival
	var spawn_clock: float = spawner.spawn_remaining
	var enemy: Node3D = combat.living_zombies[0]
	var enemy_position := enemy.position
	Input.action_press("move_right")
	await tick(10)
	Input.action_release("move_right")
	check(player.position == start_position and enemy.position == enemy_position, "Startup player and zombie frozen")
	check(spawner.elapsed_survival == elapsed and spawner.spawn_remaining == spawn_clock, "Startup survival and spawn clocks frozen")
	check(combat.projectiles.get_child_count() == 0 and not combat.can_fight(), "Startup cannot fire")
	await key(KEY_L)
	check(player.level == 1 and not level.progression.selection_open, "Level-up shortcut cannot steal startup selection")
	await key(KEY_1)
	check(not paused and not level.weapon_selector.visible and visual.weapon_type == 0, "Keyboard pistol selection resumes")
	# Keep a real target available, while isolating movement/animation checks.
	spawner.enabled = false
	for zombie in combat.living_zombies: zombie.set_physics_process(false)
	enemy.position = player.position + Vector3(0, 0, 4)
	for weapon in 3:
		await key(KEY_F2)
		check(paused and level.weapon_selector.visible, "F2 opens paused selector")
		visual.shot_recoil(Vector3.BACK)
		pistol.cooldown = 8.0
		if weapon == 1: await click(weapon)
		elif weapon == 2: await click(weapon, true)
		else: await key(KEY_1)
		check(not paused and visual.weapon_type == weapon and visual.socket.equipped == weapon, "Selection feeds existing runtime and socket %d" % weapon)
		check(not visual.queued_recoil and visual.recoil_gain == 1.0 and pistol.cooldown < 0.2, "Selection clears stale recoil and firing cooldown")
		var visible_count := 0
		for model in visual.socket.instances:
			if model.visible: visible_count += 1
		check(visible_count == 1, "Exactly one weapon visible")
		check(visual.recoil_pose.clip == visual.samples[visual.RECOILS[weapon]].clip, "Weapon-specific recoil clip")
		check(pistol.nearest_target() != null, "Target acquired")
		pistol.cooldown = 0.0
		pistol._physics_process(0.01)
		check(combat.projectiles.get_child_count() > 0 and visual.recoil_time < 1.0, "Selected weapon fires and starts recoil")
		var shot: Node3D = combat.projectiles.get_child(combat.projectiles.get_child_count() - 1)
		check(shot.global_position.distance_to(visual.socket.muzzle_position()) < 0.0001, "Shot originates at transformed weapon muzzle")
		pistol.enabled = false
		for aiming in [false, true]:
			for velocity in [Vector3.ZERO, Vector3.BACK * 4.25, Vector3.BACK * 6.25, Vector3.LEFT * 4.25, Vector3.RIGHT * 4.25, Vector3.FORWARD * 4.25]:
				for i in 12:
					visual.update_motion(velocity, enemy if aiming else null, 1.0 / 60.0)
					visual._process(1.0 / 60.0)
				var phase: float = visual.locomotion_phase
				visual.shot_recoil(Vector3.BACK)
				visual._process(1.0 / 60.0)
				check(visual.aim_weight == (1.0 if aiming else 0.0), "LowReady / Aim settles")
				check(velocity == Vector3.ZERO or visual.locomotion_phase != phase, "Firing while moving preserves gait")
		pistol.enabled = true
		check(level.get_node("HUD/AnimationDebug").text.contains("Weapon: " + visual.WEAPON_NAMES[weapon]), "HUD names selected weapon")
	# In-flight simulation freezes during reopened selector, then continues.
	combat.fire(Vector3(0, 3, 0), Vector3.RIGHT, 20, 1, 10)
	combat.spawn_impact(Vector3(0, 1, 0))
	await tick(1)
	var bullet: Node3D = combat.projectiles.get_child(combat.projectiles.get_child_count() - 1)
	await key(KEY_F2)
	var age: float = bullet.age
	var bullet_position := bullet.position
	var effect: Node3D = combat.effects.get_child(combat.effects.get_child_count() - 1)
	var effect_scale := effect.scale
	elapsed = spawner.elapsed_survival
	var cooldown: float = pistol.cooldown
	var phase: float = visual.locomotion_phase
	await tick(10)
	check(bullet.age == age and bullet.position == bullet_position and effect.scale == effect_scale, "Projectiles and effect tweens frozen")
	check(spawner.elapsed_survival == elapsed and pistol.cooldown == cooldown and visual.locomotion_phase == phase, "Timers and animation frozen")
	await key(KEY_3)
	await tick(2)
	check(bullet.age > age, "In-flight projectile resumes")
	await key(KEY_L)
	check(paused and level.progression.selection_open, "Level-up still pauses")
	await key(KEY_F2)
	check(not level.weapon_selector.visible, "F2 cannot overlap level-up selection")
	await key(KEY_2)
	await create_timer(0.16, true).timeout
	check(not paused and visual.weapon_type == 2, "Upgrade selection resumes without switching weapon")
	for i in 9:
		await key(KEY_1 + i % 3)
		check(visual.weapon_type == i % 3, "Repeated in-game debug weapon change")
	await key(KEY_R)
	await tick(3)
	level = current_scene
	check(not paused and not level.weapon_selector.visible and level.player.visual.weapon_type == 2, "R retains shotgun without reopening selector")
	check(level.player.level == 1 and level.player.current_hp == 100, "R resets run stats")
	await key(KEY_L)
	await key(KEY_R)
	await tick(3)
	level = current_scene
	check(not paused and not level.weapon_selector.visible and level.player.visual.weapon_type == 2, "R during level-up retains weapon")
	await key(KEY_F2)
	await key(KEY_R)
	await tick(3)
	level = current_scene
	check(not paused and not level.weapon_selector.visible and level.player.visual.weapon_type == 2, "R during weapon selection retains weapon")
	if "--capture" in OS.get_cmdline_user_args():
		await key(KEY_F2)
		for dimensions in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(720, 1280)]:
			root.content_scale_size = dimensions
			root.size = dimensions
			await create_timer(0.1, true).timeout
			await RenderingServer.frame_post_draw
			for button in level.weapon_selector.buttons:
				var rect: Rect2 = button.get_global_rect()
				check(rect.size.y >= 100 and rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= dimensions.x and rect.end.y <= dimensions.y, "Touch card fits %s" % dimensions)
			root.get_texture().get_image().save_png("res://tests/weapon_select_%dx%d.png" % [dimensions.x, dimensions.y])
		await capture_weapon_poses()
	var result := {"checks": checks, "failures": failures, "phone_tested": false, "touch_events_tested": true, "capture": "--capture" in OS.get_cmdline_user_args()}
	var suffix := "rendered" if result.capture else "headless"
	FileAccess.open("res://tests/weapon_select_" + suffix + "_validation.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture_weapon_poses() -> void:
	# Inspect unchanged assets at a closer scale, including a recoil sample.
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	level.visible = false
	level.get_node("HUD").hide()
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.position = Vector3(3, 3, 9)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(sun)
	var actors: Array[Node3D] = []
	for pose in 3:
		var actor: Node3D = preload("res://scenes/characters/CuboidPlayer.tscn").instantiate()
		world.add_child(actor)
		actor.position.x = (pose - 1) * 2.4
		actor.set_physics_process(false)
		actor.visual.set_process(false)
		actors.append(actor)
		var label := Label3D.new()
		label.text = ["LowReady", "Aim", "Aim + recoil (80ms)"][pose]
		label.position.y = 2.2
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)
	for weapon in 3:
		for pose in 3:
			var actor: Node3D = actors[pose]
			actor.equip_test_weapon(weapon)
			actor.visual.has_target = pose > 0
			for frame in 20: actor.visual._process(1.0 / 60.0)
			if pose == 2:
				actor.visual.shot_recoil(Vector3.BACK)
				actor.visual._process(0.08)
		for side in [false, true]:
			camera.position = Vector3(3, 3, 9) if not side else Vector3(8, 3, 7)
			camera.look_at(Vector3(0, 1, 0))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/weapon_select_%s_%s.png" % [actors[0].visual.WEAPON_NAMES[weapon].to_lower(), "side" if side else "front"])
	world.queue_free()
	await process_frame
