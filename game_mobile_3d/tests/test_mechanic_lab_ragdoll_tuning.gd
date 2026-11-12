extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	var launch := lab.get_node_or_null("HUD/RagdollTuning/Launch/Slider") as HSlider
	var gravity := lab.get_node_or_null("HUD/RagdollTuning/Gravity/Slider") as HSlider
	check(launch != null and gravity != null and launch.is_visible_in_tree() and gravity.is_visible_in_tree(),
		"Both tuning sliders are visible in MechanicLab")
	if launch != null and gravity != null:
		check(launch.value == 100.0 and gravity.value == 100.0, "Sliders start at the reference settings")
		var baseline := await replay_combo(lab)
		click_slider(launch, true)
		check(launch.value == 200.0, "A pointer click can increase ragdoll launch to 200%")
		var stronger := await replay_combo(lab)
		launch.value = 100.0
		click_slider(gravity, false)
		check(gravity.value == 25.0, "A pointer click can reduce ragdoll gravity to 25%")
		var lighter := await replay_combo(lab)
		gravity.value = 200.0
		var heavier := await replay_combo(lab)
		check(baseline.health == [36, 22, 0] and stronger.health == baseline.health
			and lighter.health == baseline.health and heavier.health == baseline.health,
			"Every setting preserves all three actual Sabre damage events")
		check(baseline.impulse.length() > 0.0 and stronger.impulse.is_equal_approx(baseline.impulse * 2.0)
			and lighter.impulse.is_equal_approx(baseline.impulse)
			and heavier.impulse.is_equal_approx(baseline.impulse), "Only the launch slider changes the lethal impulse")
		check(is_equal_approx(baseline.flight, -50.0) and is_equal_approx(stronger.flight, baseline.flight)
			and is_equal_approx(lighter.flight, -12.5) and is_equal_approx(heavier.flight, -100.0),
			"Only the gravity slider changes the flight acceleration")
		check(is_equal_approx(lighter.ground_scale, 0.25) and is_equal_approx(heavier.ground_scale, 2.0),
			"The grounded ragdoll finishes its gravity blend at either setting")
		print("RAGDOLL_TUNING flight=", [baseline.flight, stronger.flight, lighter.flight, heavier.flight],
			" impulse=", [baseline.impulse.length(), stronger.impulse.length()],
			" ground_scales=", [lighter.ground_scale, heavier.ground_scale])
	lab.free()
	print("MECHANIC_LAB_RAGDOLL_TUNING failures=", failures)
	quit(0 if failures.is_empty() else 1)

func click_slider(slider: HSlider, high: bool) -> void:
	var rect := slider.get_global_rect()
	var position := Vector2(rect.end.x - 1.0 if high else rect.position.x + 1.0, rect.get_center().y)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = position
		event.global_position = position
		event.pressed = pressed
		root.push_input(event, true)

func replay_combo(lab) -> Dictionary:
	lab.reset_player()
	var group := lab.get_node("Zombies")
	group._spawn_serial = 1
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var result := {"health": [], "impulse": Vector3.ZERO, "flight": 0.0, "ground_scale": 0.0}
	var zombie = group.get_child(0)
	if zombie == null:
		return result
	var record_health := func(_point, _direction, _clip, _index, _serial, _lethal):
		result.health.append(zombie.health)
	group.sabre_contact.connect(record_health)
	for i in 56:
		await physics_frame
	var attack := InputEventKey.new()
	attack.physical_keycode = KEY_E
	attack.pressed = true
	root.push_input(attack, true)
	for i in 140:
		if zombie.health == 0:
			break
		await physics_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	root.push_input(release, true)
	group.sabre_contact.disconnect(record_health)
	for i in 140:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		result.impulse = zombie.ragdoll.total_applied_impulse
		var chest: PhysicalBone3D = zombie.ragdoll.bodies.Chest
		var state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
		if result.flight == 0.0 and state and not zombie._corpse_landed:
			result.flight = state.total_gravity.y
		if zombie.ragdoll.floor_landing_blended:
			result.ground_scale = chest.gravity_scale
			break
	zombie.free()
	await physics_frame
	return result
