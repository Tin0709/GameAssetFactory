extends SceneTree
const LAB = preload("res://scenes/PlayerPoseLab.tscn")
var lab: Node3D
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame
func step(count: int) -> void:
	for frame in count: lab._process(1.0 / 60.0)
func run() -> void:
	lab = LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.set_process(false)
	var visual: Node3D = lab.visual
	check(not visual.is_processing() and not visual.animation_player.is_playing(), "Lab owns one production pose clock")
	check(lab.get_node("Player").get_script() == null, "No gameplay player/damage controller")
	check(lab.find_children("*", "CharacterBody3D", true, false).is_empty(), "No moving gameplay actors")
	check(get_nodes_in_group("zombies").is_empty(), "No zombies")
	for service in ["Combat", "SpawnDirector", "Progression", "Pistol", "WeaponDebug"]:
		check(lab.find_child(service, true, false) == null, "No gameplay service " + service)
	var origin: Vector3 = lab.get_node("Player").position
	for weapon in 3:
		await key(KEY_1 + weapon)
		step(20)
		check(visual.weapon_type == weapon and visual.socket.equipped == weapon, "Weapon selection %d" % weapon)
		var visible_count := 0
		for model in visual.socket.instances:
			if model.visible: visible_count += 1
		check(visible_count == 1, "One weapon visible")
		check(lab.status.text.contains(visual.WEAPON_NAMES[weapon]), "HUD displays weapon")
		for state in 3:
			await key([KEY_I, KEY_W, KEY_R][state])
			step(30)
			check(visual.current_state == lab.STATES[state], "Forced locomotion state")
			var phase: float = visual.locomotion_phase
			step(2)
			check(state == 0 or visual.locomotion_phase != phase, "Locomotion advances in place")
			check(lab.get_node("Player").position == origin and visual.position == Vector3.ZERO, "Player stays physically in place")
			for aiming in [false, true]:
				await key(KEY_A if aiming else KEY_L)
				step(12)
				check(visual.has_target == aiming and visual.aim_weight == (1.0 if aiming else 0.0), "Aim override without enemy")
				await key(KEY_F)
				step(2)
				check(visual.is_firing and visual.recoil_amount > 0.0, "Production standing/moving recoil")
				check(visual.recoil_pose.clip == visual.samples[visual.RECOILS[weapon]].clip, "Selected weapon recoil layer")
				step(40)
				check(not visual.is_firing, "Recoil settles")
	# Playback affects the real controller clock, not just its HUD value.
	for speed_key in [KEY_N, KEY_H, KEY_Q]:
		await key(speed_key)
		await key(KEY_F)
		step(4)
		check(absf(visual.recoil_time - 4.0 / 60.0 * lab.playback_speed) < 0.0001, "Playback scales production recoil time")
		step(100)
	step(400)
	await key(KEY_SPACE)
	check(lab.animation_paused and not paused, "Pose freeze leaves SceneTree interactive")
	var phase: float = visual.locomotion_phase
	var aim_weight: float = visual.aim_weight
	var bone_poses: Array[Transform3D] = []
	for bone in visual.skeleton.get_bone_count(): bone_poses.append(visual.skeleton.get_bone_pose(bone))
	step(30)
	check(visual.locomotion_phase == phase and visual.aim_weight == aim_weight, "Frozen animation clocks")
	for bone in visual.skeleton.get_bone_count():
		check(visual.skeleton.get_bone_pose(bone).is_equal_approx(bone_poses[bone]), "Frozen bone pose")
	var camera_before: Transform3D = lab.camera.transform
	await key(KEY_V)
	check(not lab.camera.transform.is_equal_approx(camera_before), "Camera preset works during freeze")
	var mouse := InputEventMouseButton.new()
	mouse.position = Vector2(1000, 600)
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	mouse.pressed = true
	var old_distance: float = lab.distance
	root.push_input(mouse, true)
	check(lab.distance < old_distance, "Mouse zoom works during freeze")
	mouse = InputEventMouseButton.new()
	mouse.position = Vector2(1000, 600)
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	root.push_input(mouse, true)
	var motion := InputEventMouseMotion.new()
	motion.position = mouse.position
	motion.relative = Vector2(40, 15)
	var old_yaw: float = lab.yaw
	root.push_input(motion, true)
	check(lab.yaw != old_yaw and lab.camera_mode == "Orbit", "Mouse orbit works during freeze")
	mouse.pressed = false
	root.push_input(mouse, true)
	check(not lab.orbiting, "Mouse orbit ends on release")
	await key(KEY_C)
	check(lab.camera_mode == "3/4" and lab.distance == 3.8, "Camera reset")
	await key(KEY_F)
	step(10)
	check(visual.recoil_time == 0.0, "Frozen recoil queues until step/resume")
	await key(KEY_PERIOD)
	check(visual.recoil_time > 0.0 and visual.is_firing and lab.animation_paused, "Single-frame step evaluates frozen recoil")
	await key(KEY_SPACE)
	step(3)
	check(not lab.animation_paused and visual.recoil_time > 1.0 / 60.0 * lab.playback_speed, "Resume continues pose")
	# Verify actual GUI click routing, not only the keyboard adapter.
	await process_frame
	var button: Button = lab.get_node("HUD/Panel/Stack/Controls").get_child(0).get_child(0)
	for down in [true, false]:
		mouse = InputEventMouseButton.new()
		mouse.position = button.get_global_rect().get_center()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		root.push_input(mouse, true)
		await process_frame
	check(visual.weapon_type == 0, "Clickable lab weapon button")
	check(lab.find_children("*", "Area3D", true, false).is_empty(), "No projectile/pickup/damage areas appear")
	if "--capture" in OS.get_cmdline_user_args():
		lab.set_speed(1.0)
		lab.set_locomotion(0)
		lab.set_aim(true)
		step(30)
		for weapon in 3:
			lab.equip(weapon)
			step(20)
			lab.set_view(3)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/pose_lab_%s.png" % visual.WEAPON_NAMES[weapon].to_lower())
	var result := {"checks": checks, "failures": failures, "capture": "--capture" in OS.get_cmdline_user_args(), "phone_tested": false}
	var suffix := "rendered" if result.capture else "headless"
	FileAccess.open("res://tests/pose_lab_" + suffix + "_validation.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
