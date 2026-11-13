extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func visible_particles(dust: Node3D) -> int:
	var count := 0
	for particle: Node3D in dust.get_children():
		if particle.visible:
			count += 1
	return count

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var dust := lab.get_node_or_null("MovementDust") as Node3D
	var wind := lab.get_node_or_null("MovementWind") as Node3D
	check(dust != null, "MechanicLab has a dust emitter with verified source masks")
	check(wind != null, "MechanicLab has a run wake with a verified source texture")
	if dust == null or wind == null:
		lab.free()
		quit(1)
		return
	var contacts: Array[bool] = []
	lab.player.surface_contact.connect(func(_position: Vector3, landed: bool): contacts.append(landed))
	for i in 25:
		await physics_frame
	check(contacts.is_empty() and visible_particles(dust) == 0 and visible_particles(wind) == 0,
		"Standing at spawn emits no movement effects")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var walking_peak := 0
	var walking_wind := 0
	for i in 65:
		await physics_frame
		walking_peak = maxi(walking_peak, visible_particles(dust))
		walking_wind = maxi(walking_wind, visible_particles(wind))
	check(contacts.size() >= 2 and walking_peak == 0,
		"MD2 Walk keeps foot contacts without spawning the Run dust emitter")
	check(walking_wind == 0, "Walking does not emit the run wake")
	Input.action_release("sprint")
	var running_wind := 0
	for i in 50:
		await physics_frame
		running_wind = maxi(running_wind, visible_particles(wind))
	check(running_wind > 0, "Fast running emits a short wind wake")
	await check_source_run_dust(lab, dust)
	var run_contacts := contacts.size()
	Input.action_press("jump")
	for i in 10:
		await physics_frame
		if not lab.player._grounded:
			break
	Input.action_release("jump")
	var before_landing := contacts.size()
	var landed_particles := 0
	for i in 75:
		await physics_frame
		if lab.player._grounded:
			landed_particles = visible_particles(dust)
			break
	check(run_contacts > 4 and lab.player._grounded and contacts.size() == before_landing + 1
		and contacts.back() and landed_particles > walking_peak,
		"The jump adds only one stronger burst, on landing")
	check(visible_particles(wind) == 0, "Landing does not start a running wake")
	Input.action_release("move_forward")
	for i in 115:
		await physics_frame
	check(visible_particles(dust) == 0 and not dust.is_processing(), "Dust fades and stops processing at rest")
	check(visible_particles(wind) == 0 and not wind.is_processing(), "The run wake clears at rest")
	Input.action_press("move_forward")
	for i in 35:
		await physics_frame
		if visible_particles(dust) > 0:
			break
	Input.action_release("move_forward")
	check(visible_particles(dust) > 0, "Movement emits dust again after resting")
	lab.reset_player()
	await physics_frame
	check(visible_particles(dust) == 0 and visible_particles(wind) == 0, "Reset clears both movement effects")
	await check_heavy_dust_timing(lab, dust)
	await check_running_wake_support(lab, wind)
	await check_floor_edge_landing(lab, dust)
	print("MECHANIC_LAB_MOVEMENT_FX walk=", walking_peak, " wind=", running_wind, " landing=", landed_particles,
		" contacts=", contacts.size(), " failures=", failures)
	lab.free()
	quit(0 if failures.is_empty() else 1)

func check_running_wake_support(lab, wind) -> void:
	lab.reset_player()
	var floor_body := lab.get_node("Ground") as StaticBody3D
	floor_body.position.y += 0.25
	lab.player.global_position += Vector3.UP * 0.75
	for i in 45:
		await physics_frame
	Input.action_press("move_forward")
	for i in 20:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_right")
	var supported_steps: Array[Vector3] = []
	var listen := func(point, landed):
		if not landed:
			supported_steps.append(point)
	lab.player.surface_contact.connect(listen)
	for i in 35:
		await physics_frame
		if not supported_steps.is_empty():
			break
	lab.player.surface_contact.disconnect(listen)
	var wake = wind._wakes[posmod(wind._next - 1, wind._wakes.size())]
	var velocity: Vector3 = lab.player.get_real_velocity().slide(Vector3.UP)
	check(not supported_steps.is_empty() and wake.mesh.visible and wake.trailing.dot(-velocity.normalized()) > 0.999,
		"After turning, the wake trails the actual movement on a supported foot contact")
	check(is_equal_approx(wake.origin.y, 0.25 + 0.38),
		"The wake's height is measured from the grass under the foot")
	var next: int = wind._next
	var over_edge := Vector3(51.0, 0.25, 0.0)
	lab.player.surface_contact.emit(over_edge, false)
	lab.player.surface_contact.emit(lab.player.global_position + Vector3.UP * 2.0, false)
	check(wind._next == next, "Foot contacts beyond the floor or above the grass do not spawn wakes")
	Input.action_release("move_right")
	floor_body.position.y -= 0.25

func check_source_run_dust(lab, dust) -> void:
	var listen := func(_point: Vector3, landed: bool):
		if not landed:
			var particle = dust._particles[posmod(dust._next - 1, dust._particles.size())]
			check(particle.duration >= 0.8 and particle.duration <= 1.75,
				"Run dust uses the authored 0.80 to 1.75 second particle lifetime")
			check(is_equal_approx(particle.sprite.pixel_size * 16.0, 1.0)
				and is_equal_approx(particle.sprite.modulate.a, 0.4),
				"The run notify passes its one-metre sprite size and begins at source alpha 0.4")
	var before: int = dust._next
	lab.player.surface_contact.connect(listen)
	for i in 45:
		await physics_frame
		if dust._next != before:
			break
	lab.player.surface_contact.disconnect(listen)
	check(dust._next != before, "The source Run emitter starts at a supported step")

func check_heavy_dust_timing(lab, dust: Node3D) -> void:
	for i in 8:
		await physics_frame
	var landings: Array[Dictionary] = []
	lab.player.surface_contact.connect(func(_point: Vector3, landed: bool):
		if landed:
			landings.append({"frame": Engine.get_physics_frames(), "particles": visible_particles(dust)}))
	await start_heavy_drop(lab)
	var burst_frame := -1
	var counts: Array[int] = []
	for i in Engine.physics_ticks_per_second:
		await physics_frame
		var visible := visible_particles(dust)
		if not landings.is_empty() and visible > 0:
			if burst_frame < 0:
				burst_frame = Engine.get_physics_frames() - 1
			if counts.is_empty() or counts.back() != visible:
				counts.append(visible)
	check(landings.size() == 1 and landings[0].particles == 0,
		"The actual Sabre dive suppresses the ordinary dust burst on touchdown")
	var delay_ticks := ceili(0.045126423 * Engine.physics_ticks_per_second)
	check(not landings.is_empty() and burst_frame == int(landings[0].frame) + delay_ticks,
		"The first visible heavy dust appears at the Sabre debris notify")
	check(not counts.is_empty() and counts[0] == 10, "The first burst is the ten heavy puffs")
	for i in range(1, counts.size()):
		check(counts[i] < counts[i - 1], "The dive emits a single burst")
	print("MECHANIC_LAB_HEAVY_DUST landings=", landings, " burst_frame=", burst_frame, " counts=", counts)
	landings.clear()
	await start_heavy_drop(lab)
	for i in Engine.physics_ticks_per_second:
		await physics_frame
		if not landings.is_empty():
			break
	check(landings.size() == 1 and dust.is_physics_processing(), "The repeat dive schedules a heavy dust burst")
	lab.reset_player()
	for i in delay_ticks + 2:
		await physics_frame
	check(visible_particles(dust) == 0 and not dust.is_physics_processing(),
		"Reset cancels heavy dust that has not appeared yet")

func check_floor_edge_landing(lab, dust: Node3D) -> void:
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var movement = lab.get_node("MovementAudio")
	var audio = lab.get_node("CombatAudio")
	for heavy in [false, true]:
		lab.reset_player()
		lab.player.global_position = Vector3(49.99, 0.03, 0.0)
		for i in 12:
			await physics_frame
		var ordinary_before: int = movement.event_count.landing
		var heavy_before: int = audio._next_choice.get(&"slam_grass", 0)
		check(lab.player.drop_for_lab(5.0), "The edge fixture starts a real drop")
		lab.player.global_position.x = 50.20
		if heavy:
			await press_heavy_attack()
		var max_dust := 0
		var dust_near_edge := false
		for i in 70:
			await physics_frame
			var visible := visible_particles(dust)
			if visible > max_dust:
				max_dust = visible
				dust_near_edge = dust.get_children().filter(func(sprite): return sprite.visible).all(
					func(sprite): return absf(sprite.global_position.x - 50.0) < 0.45)
		check(lab.player.is_on_floor() and lab.player.global_position.x > 50.0,
			"The capsule lands while its centre is past the grass edge")
		check(max_dust == (10 if heavy else 5) and dust_near_edge,
			"The edge landing emits one full dust burst next to the grass contact")
		if heavy:
			check(audio._next_choice.get(&"slam_grass", 0) == (heavy_before + 1) % 6
				and movement.event_count.landing == ordinary_before, "The edge dive plays one heavy grass cue")
			var grass_voices: Array = audio._voices.filter(func(voice): return voice.stream in audio._groups[&"slam_grass"])
			check(grass_voices.size() == 1 and absf(grass_voices[0].global_position.x - 50.0) < 0.03,
				"The heavy debris cue plays at the grass edge")
		else:
			check(movement.event_count.landing == ordinary_before + 1, "The ordinary edge landing plays grass audio once")
			if not movement.events.is_empty():
				check(absf(movement.events.back().at[0] - 50.0) < 0.03, "The ordinary cue plays at the grass edge")
	toggle.button_pressed = false
	# Allow the real-time Ogg mixer to release stopped streams before teardown.
	await create_timer(0.10, true, false, true).timeout

func start_heavy_drop(lab) -> void:
	lab.get_node("HUD/DropMedium").pressed.emit()
	await press_heavy_attack()

func press_heavy_attack() -> void:
	for i in 2:
		await physics_frame
	var attack := InputEventKey.new()
	attack.physical_keycode = KEY_E
	attack.pressed = true
	root.push_input(attack, true)
	for i in 2:
		await physics_frame
	attack = InputEventKey.new()
	attack.physical_keycode = KEY_E
	root.push_input(attack, true)
