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
	for i in 125:
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
	await check_overlapping_landing_dust(lab, dust)
	await check_gauntlet_debris(lab, dust)
	await check_running_wake_support(lab, wind)
	await check_running_wake_render_clock(lab, wind, dust)
	await check_floor_edge_landing(lab, dust)
	await check_non_grass_landing(lab, dust)
	await check_non_grass_steps(lab, dust, wind)
	await check_wall_slide_steps(lab, dust, wind)
	await check_curved_step_effects(lab, dust, wind)
	await check_steps_during_attacks(lab, dust)
	await check_dust_contact_clock(lab, dust)
	await check_zombie_steps_on_slab(lab)
	await check_zombie_dust_contact_clock(lab)
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
	# The reflected M_WhirlWind_Emissive renders the same texture on both faces.
	check(wake.material.cull_mode == BaseMaterial3D.CULL_DISABLED,
		"The Lab wake renders both sides of the source wind material")
	check(is_equal_approx(wake.origin.y, 0.25 + 0.38),
		"The wake's height is measured from the grass under the foot")
	var age_before: float = wake.age
	# A long render interval alone must not consume the first visible wake.
	wind._process(0.10)
	check(wake.mesh.visible and wake.age < age_before + 0.02,
		"The run wake ages from the foot-contact clock instead of a long render interval")
	var next: int = wind._next
	var over_edge := Vector3(51.0, 0.25, 0.0)
	lab.player.surface_contact.emit(over_edge, false)
	lab.player.surface_contact.emit(lab.player.global_position + Vector3.UP * 2.0, false)
	check(wind._next == next, "Foot contacts beyond the floor or above the grass do not spawn wakes")
	Input.action_release("move_right")
	floor_body.position.y -= 0.25
	for i in 6:
		await physics_frame
	await process_frame
	wind._process(0.0)
	check(wake.mesh.visible and wake.age >= 0.08 and wake.material.albedo_color.a < wind.TINT.a,
		"The wake moves through its fade on the physics clock after input stops")
	for i in 9:
		await physics_frame
	await process_frame
	wind._process(0.0)
	check(not wake.mesh.visible and not wind.is_processing() and not wind.is_physics_processing(),
		"The last wake expires and stops both callbacks")

func check_running_wake_render_clock(lab, wind, dust) -> void:
	lab.reset_player()
	for i in 12:
		await physics_frame
	var samples := 0
	var max_position_error := 0.0
	var max_alpha_error := 0.0
	Input.action_press("move_forward")
	for i in 115:
		await process_frame
		var wake = wind._wakes[posmod(wind._next - 1, wind._wakes.size())]
		var puff = dust._particles[posmod(dust._next - 1, dust._particles.size())]
		if not wake.mesh.visible or not puff.sprite.visible or wake.contact_tick != puff.contact_tick:
			continue
		# The render delta may include time before the planted foot event.
		dust._process(0.15)
		wind._process(0.15)
		var progress: float = puff.age / wind.LIFETIME
		if progress >= 1.0:
			continue
		check(wake.mesh.visible, "The wake stays visible for its full lifetime from contact")
		var expected: Vector3 = wake.origin + wake.trailing * progress * 0.16
		var alpha: float = wind.TINT.a * (1.0 - smoothstep(0.12, 1.0, progress))
		max_position_error = maxf(max_position_error, wake.mesh.global_position.distance_to(expected))
		max_alpha_error = maxf(max_alpha_error, absf(wake.material.albedo_color.a - alpha))
		samples += 1
		if samples >= 12:
			break
	Input.action_release("move_forward")
	check(samples >= 8 and max_position_error < 0.0001 and max_alpha_error < 0.0001,
		"Varying render intervals keep the running wake aligned with dust from the same contact")
	print("MECHANIC_LAB_WAKE_RENDER_CLOCK samples=", samples, " position_error_m=", max_position_error,
		" alpha_error=", max_alpha_error)
	lab.reset_player()

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
	var samples := 0
	var max_error := 0.0
	for particle in dust._particles:
		if particle.sprite.visible and particle.run_drag > 0.0 and particle.age >= 0.08:
			var height := expected_step_rise(particle.age, particle.run_drag)
			var expected: Vector3 = particle.origin + Vector3.UP * height
			max_error = maxf(max_error, expected.distance_to(particle.sprite.global_position))
			samples += 1
	check(samples > 0 and max_error <= 0.00002, "Running dust follows the decoded fixed-step rise")
	print("MECHANIC_LAB_RUN_DUST_RISE samples=", samples, " max_error_m=", max_error)

func expected_step_rise(age: float, drag: float) -> float:
	const STEP := 1.0 / 60.0
	var ticks := floori(age / STEP)
	var speed := 0.0
	var height := 0.0
	var divisor := 1.0 + drag * STEP
	for tick in ticks:
		speed = (speed + STEP) / divisor
		height += speed * STEP
	return height + (speed + STEP) / divisor * (age - ticks * STEP)

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

func check_overlapping_landing_dust(lab, dust: Node3D) -> void:
	lab.reset_player()
	dust._random.seed = 27385
	var landing_ticks: Array[int] = []
	var record := func(_point: Vector3, landed: bool):
		if landed:
			landing_ticks.append(Engine.get_physics_frames())
	lab.player.surface_contact.connect(record)
	var ordinary_puffs: Dictionary = {}
	var lost := 0
	var heavy_peak := 0
	var jumps := 0
	var second_air_ticks := 0
	var rate := Engine.physics_ticks_per_second
	Input.action_press("move_forward")
	for tick in 177:
		await physics_frame
		var now := Engine.get_physics_frames()
		var heavy_puffs := 0
		for particle in dust._particles:
			if ordinary_puffs.has(particle):
				var original: Vector2 = ordinary_puffs[particle]
				var age := float(now - 1 - int(original.x)) / rate
				if particle.contact_tick != int(original.x) or not particle.sprite.visible:
					lost += int(age + 0.0001 < original.y)
					ordinary_puffs.erase(particle)
			elif landing_ticks.size() == 1 and particle.sprite.visible and particle.landing_tick >= 0:
				ordinary_puffs[particle] = Vector2(particle.contact_tick, particle.duration)
			if landing_ticks.size() == 2 and particle.sprite.visible and particle.contact_tick > landing_ticks[1] \
					and particle.landing_tick < 0 and particle.run_drag == 0.0:
				heavy_puffs += 1
		heavy_peak = maxi(heavy_peak, heavy_puffs)
		if tick == 38 or (jumps == 1 and landing_ticks.size() == 1 and now - landing_ticks[0] >= 2):
			Input.action_press("jump")
			jumps += 1
		if lab.player._grounded or jumps == 0:
			continue
		Input.action_release("jump")
		if jumps == 2:
			second_air_ticks += 1
			if second_air_ticks in [10, 12]:
				var attack := InputEventKey.new()
				attack.physical_keycode = KEY_E
				attack.pressed = second_air_ticks == 10
				root.push_input(attack, true)
	Input.action_release("move_forward")
	Input.action_release("jump")
	lab.player.surface_contact.disconnect(record)
	check(landing_ticks.size() == 2 and heavy_peak == 10,
		"The running jump and follow-up Sabre dive both complete their landings")
	check(lost == 0, "The Sabre landing and later footsteps preserve visible dust from the ordinary landing")
	print("MECHANIC_LAB_OVERLAPPING_DUST lost=", lost, " heavy=", heavy_peak)
	lab.reset_player()
	await physics_frame

func check_gauntlet_debris(lab, dust: Node3D) -> void:
	for weapon in [lab.Weapon.GAUNTLETS, lab.Weapon.BASIC_GAUNTLETS]:
		lab._select_weapon(weapon)
		lab.reset_player()
		await start_heavy_drop(lab)
		for i in 65:
			await physics_frame
			if visible_particles(dust) > 0:
				break
		var particles: Array = dust._particles.filter(func(p): return p.sprite.visible)
		check(lab._equipped_weapon == weapon and lab.player.is_on_floor()
			and particles.size() in [3, 4, 5], "A Gauntlets dive emits one compact ground debris burst")
		for particle in particles:
			check(is_equal_approx(particle.sprite.pixel_size * 16.0, 0.15)
				and particle.duration >= 1.0 and particle.duration <= 1.5
				and particle.velocity.length() >= 3.49 and particle.velocity.length() <= 6.51
				and absf(particle.origin.y) < 0.02,
				"Gauntlets debris uses the source size, lifetime and speed at the ground contact")
		var motion_error := 0.0
		var samples := 0
		for tick in 40:
			await physics_frame
			for particle in particles:
				if particle.age < 0.08 or not particle.sprite.visible:
					continue
				var expected := gauntlet_debris_position(particle.origin, particle.velocity, particle.debris_drag, particle.age)
				motion_error = maxf(motion_error, expected.distance_to(particle.sprite.global_position))
				samples += 1
		check(samples > 20 and motion_error <= 0.00005,
			"Gauntlets debris follows the cooked solve between fixed updates")
		print("MECHANIC_LAB_GAUNTLET_DEBRIS weapon=", weapon, " count=", particles.size(),
			" samples=", samples, " motion_error_m=", motion_error)
		lab.reset_player()
		await physics_frame
		check(visible_particles(dust) == 0 and not dust.is_processing(), "Reset clears Gauntlets debris")
	lab._select_weapon(lab.Weapon.SABRE)

func gauntlet_debris_position(origin: Vector3, velocity: Vector3, drag: float, age: float) -> Vector3:
	const STEP := 1.0 / 60.0
	const ACCELERATION := Vector3.DOWN * 14.7
	var position := origin
	var elapsed_ticks := floori(age / STEP)
	var divisor := 1.0 + drag * STEP
	for i in elapsed_ticks:
		velocity = (velocity + ACCELERATION * STEP) / divisor
		position += velocity * STEP
	var next_velocity := (velocity + ACCELERATION * STEP) / divisor
	return position + next_velocity * (age - elapsed_ticks * STEP)

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
		var source_landing := false
		for i in 70:
			await physics_frame
			var visible := visible_particles(dust)
			if visible > max_dust:
				max_dust = visible
				dust_near_edge = dust.get_children().filter(func(sprite): return sprite.visible).all(
					func(sprite): return absf(sprite.global_position.x - 50.0) < 0.45)
				if not heavy:
					source_landing = dust._particles.filter(func(particle): return particle.sprite.visible).all(
						func(particle):
							return (particle.duration >= 1.0 and particle.duration <= 2.0
								and is_equal_approx(particle.origin.y, 0.50)
								and is_equal_approx(particle.sprite.pixel_size * 16.0, 1.0)
								and absf(particle.origin.x - 50.0) < 0.03))
		check(lab.player.is_on_floor() and lab.player.global_position.x > 50.0,
			"The capsule lands while its centre is past the grass edge")
		check((max_dust == 10 and dust_near_edge) if heavy else (max_dust in [4, 5, 6] and source_landing),
			"The edge landing emits one full dust burst next to the grass contact")
		if heavy:
			check(audio._next_choice.get(&"slam_grass", 0) == (heavy_before + 1) % 6
				and movement.event_count.landing == ordinary_before, "The edge dive plays one heavy grass cue")
			var grass_voices: Array = audio.get_children().filter(func(voice):
				return voice is AudioStreamPlayer3D and voice.stream in audio._groups[&"slam_grass"])
			check(grass_voices.size() == 1 and absf(grass_voices[0].global_position.x - 50.0) < 0.03,
				"The heavy debris cue plays at the grass edge")
		else:
			check(source_landing, "The ordinary landing starts source-sized sprites 50 cm above its contact for 1 to 2 seconds")
			check(movement.event_count.landing == ordinary_before + 1, "The ordinary edge landing plays grass audio once")
			if not movement.events.is_empty():
				check(absf(movement.events.back().at[0] - 50.0) < 0.03, "The ordinary cue plays at the grass edge")
	toggle.button_pressed = false
	# Allow the real-time Ogg mixer to release stopped streams before teardown.
	await create_timer(0.10, true, false, true).timeout

func check_non_grass_landing(lab, dust: Node3D) -> void:
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var movement = lab.get_node("MovementAudio")
	var audio = lab.get_node("CombatAudio")
	var slab := StaticBody3D.new()
	slab.position = Vector3(0.0, 0.12, 0.0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.24, 2.0)
	collision.shape = box
	slab.add_child(collision)
	lab.add_child(slab)
	var heavy_landings: Array[Vector3] = []
	var record_heavy := func(point: Vector3, _direction: Vector3, _serial: int, _height: float):
		heavy_landings.append(point)
	lab.player.heavy_jump_landed.connect(record_heavy)
	toggle.button_pressed = true
	for heavy in [false, true]:
		lab.reset_player()
		lab.player.global_position = Vector3(0.53, 1.0, 0.0)
		var ordinary_before: int = movement.event_count.landing
		var heavy_before: int = audio._next_choice.get(&"slam_grass", 0)
		heavy_landings.clear()
		if heavy:
			lab.player.global_position.y = 5.0
			await press_heavy_attack()
		var peak_dust := 0
		for i in 70:
			await physics_frame
			peak_dust = maxi(peak_dust, visible_particles(dust))
		check(lab.player.is_on_floor() and lab.player.global_position.y > 0.20,
			"The player's capsule comes to rest on the raised slab")
		check(heavy_landings.size() == int(heavy) and peak_dust == 0
			and movement.event_count.landing == ordinary_before
			and audio._next_choice.get(&"slam_grass", 0) == heavy_before,
			"Landing on a slab edge does not emit dust or audio for the grass below (heavy=%s)" % heavy)
		print("MECHANIC_LAB_SLAB_LANDING heavy=", heavy, " y=", lab.player.global_position.y,
			" peak_dust=", peak_dust, " grass_landings=", movement.event_count.landing - ordinary_before,
			" heavy_landings=", heavy_landings.size())
	lab.player.heavy_jump_landed.disconnect(record_heavy)
	toggle.button_pressed = false
	slab.free()
	lab.reset_player()
	await create_timer(0.10, true, false, true).timeout

func check_non_grass_steps(lab, dust, wind) -> void:
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var movement = lab.get_node("MovementAudio")
	var slab := StaticBody3D.new()
	slab.position = Vector3(0.0, 0.09, 0.0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.18, 30.0)
	collision.shape = box
	slab.add_child(collision)
	lab.add_child(slab)
	toggle.button_pressed = true
	lab.reset_player()
	lab.player.scripted_input = true
	lab.player.global_position = Vector3(0.45, 0.7, -6.0)
	for i in 34:
		await physics_frame
	var outside_steps: Array[float] = []
	var record := func(point: Vector3, landed: bool):
		if not landed and point.x > 0.5:
			outside_steps.append(point.x)
	lab.player.surface_contact.connect(record)
	for running in [false, true]:
		outside_steps.clear()
		var before_audio: int = movement.event_count.grass
		var before_dust: int = dust._next
		var before_wind: int = wind._next
		lab.player.requested_run = running
		lab.player.requested_direction = Vector2(0, 1)
		for i in 100:
			await physics_frame
		var grass_steps: int = movement.event_count.grass - before_audio
		check(lab.player.is_on_floor() and lab.player.global_position.y > 0.16 and not outside_steps.is_empty(),
			"The player plants a posed sole past the edge while the capsule stays on the slab")
		check(grass_steps == 0 and dust._next == before_dust and wind._next == before_wind,
			"Footsteps over the slab edge do not play grass audio, dust or wake (running=%s)" % running)
		print("MECHANIC_LAB_SLAB_STEPS running=", running, " contacts=", outside_steps.size(),
			" grass_audio=", grass_steps, " dust_changed=", dust._next != before_dust,
			" wind_changed=", wind._next != before_wind)
	lab.player.surface_contact.disconnect(record)
	var before_audio: int = movement.event_count.grass
	var before_dust: int = dust._next
	var before_wind: int = wind._next
	for i in 105:
		await physics_frame
		if movement.event_count.grass > before_audio:
			break
	check(lab.player.is_on_floor() and absf(lab.player.global_position.y) < 0.05
		and movement.event_count.grass == before_audio + 1 and dust._next != before_dust and wind._next != before_wind,
		"The next supported running step on grass resumes sound, dust and wake together")
	lab.player.requested_direction = Vector2.ZERO
	lab.player.requested_run = false
	lab.player.scripted_input = false
	toggle.button_pressed = false
	slab.free()
	lab.reset_player()
	await create_timer(0.10, true, false, true).timeout

func check_wall_slide_steps(lab, dust, wind) -> void:
	var player = lab.player
	var movement = lab.get_node("MovementAudio")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var camera: Camera3D = lab.camera
	var original_camera_basis := camera.global_basis
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(38.0, 3.0, 0.45)
	shape.shape = box
	wall.add_child(shape)
	lab.add_child(wall)
	toggle.button_pressed = true
	for case: Dictionary in [
		{"yaw": 0.31, "camera_yaw": 0.0, "live": false, "progress": false},
		{"yaw": 0.31, "camera_yaw": 0.7, "live": true, "progress": false},
		{"yaw": 1.20, "camera_yaw": 0.7, "live": true, "progress": true},
	]:
		var camera_basis := Basis(Vector3.UP, case.camera_yaw)
		var forward := camera_basis.z
		wall.position = forward * 2.0 + Vector3.UP * 1.5
		wall.rotation.y = case.yaw + case.camera_yaw
		lab.reset_player()
		player.scripted_input = not case.live
		camera.global_basis = camera_basis
		for i in 10:
			await physics_frame
		if case.live:
			Input.action_press("move_backward")
		else:
			player.requested_direction = Vector2.DOWN
			player.requested_run = true
		for i in 43:
			await physics_frame
		var before_audio: int = movement.event_count.grass
		var before_dust: int = dust._next
		var before_wind: int = wind._next
		var dust_emitted := false
		var wind_emitted := false
		var wall_frames := 0
		var forward_speed := 0.0
		var lateral_speed := 0.0
		for i in 82:
			await physics_frame
			dust_emitted = dust_emitted or dust._next != before_dust
			wind_emitted = wind_emitted or wind._next != before_wind
			if player.is_on_wall() and player.is_on_floor():
				wall_frames += 1
				var motion: Vector3 = player.get_real_velocity()
				forward_speed = maxf(forward_speed, motion.dot(forward))
				lateral_speed = maxf(lateral_speed, absf(motion.dot(camera_basis.x)))
		Input.action_release("move_backward")
		var steps: int = movement.event_count.grass - before_audio
		check(wall_frames >= 75 and lateral_speed > 0.8,
			"The player stays grounded and slides sideways along the angled wall")
		if case.progress:
			check(forward_speed > 5.0 and steps > 0 and dust_emitted and wind_emitted,
				"Running along the wall still produces grass footsteps, dust and wind")
		else:
			check(forward_speed < 0.7 and steps == 0 and not dust_emitted and not wind_emitted,
				"Sliding mainly sideways into a wall does not produce running cues (live=%s)" % case.live)
		print("MECHANIC_LAB_WALL_STEPS live=", case.live, " progress=", case.progress, " wall_ticks=", wall_frames,
			" forward=", forward_speed, " lateral=", lateral_speed, " grass_steps=", steps,
			" dust=", dust_emitted, " wind=", wind_emitted)
	player.scripted_input = false
	camera.global_basis = original_camera_basis
	toggle.button_pressed = false
	wall.free()
	lab.reset_player()
	await create_timer(0.10, true, false, true).timeout

func check_curved_step_effects(lab, dust: Node3D, wind: Node3D) -> void:
	var weapon := lab.get_node("HUD/Weapon") as OptionButton
	var sound := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var movement = lab.get_node("MovementAudio")
	var selected := weapon.selected
	var sound_was_enabled := sound.button_pressed
	weapon.select(2)
	weapon.item_selected.emit(2)
	sound.button_pressed = true
	lab.reset_player()
	var run_steps: Array[Dictionary] = []
	var walk_steps: Array[Dictionary] = []
	var last_audio := [int(movement.event_count.grass)]
	var observe := func(sole: Vector3, landed: bool):
		if landed:
			return
		var frame := Engine.get_physics_frames()
		var ground: Dictionary = lab._player_foot_contact_at(sole)
		var previous: int = last_audio[0]
		last_audio[0] = int(movement.event_count.grass)
		if ground.is_empty():
			return
		var source: String = lab.player.clips.get(lab.player.active_clip, {}).get("source_name", "")
		if source not in ["Player_2H_Medium_Run", "Player_2H_Medium_Walk"]:
			return
		var puffs: Array = dust._particles.filter(func(p): return p.sprite.visible and p.contact_tick == frame)
		var wakes: Array = wind._wakes.filter(func(w): return w.mesh.visible and w.contact_tick == frame)
		var record := {"puffs": puffs.size(), "wakes": wakes.size(),
			"sound": last_audio[0] == previous + 1 and movement.events[-1].at == [ground.position.x, ground.position.y, ground.position.z],
			"source_puff": puffs.size() == 1 and puffs[0].run_drag > 0.0
				and puffs[0].velocity == Vector3.ZERO
				and puffs[0].origin.is_equal_approx(ground.position + Vector3.UP * 0.20)
				and is_equal_approx(puffs[0].sprite.pixel_size * 16.0, 1.0)}
		if source == "Player_2H_Medium_Run":
			run_steps.append(record)
		else:
			walk_steps.append(record)
	lab.player.surface_contact.connect(observe)
	Input.action_press("move_forward")
	for i in 49:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_right")
	for i in 47:
		await physics_frame
	Input.action_press("sprint")
	for i in 65:
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("sprint")
	lab.player.surface_contact.disconnect(observe)
	check(run_steps.size() >= 3 and run_steps.all(func(step): return step.sound and step.source_puff)
		and run_steps.any(func(step): return step.wakes == 1),
		"Curved Greatsword run and turn use source dust at the same supported foot as the sound")
	var walk_quiet := walk_steps.all(func(step): return step.sound and step.puffs == 0 and step.wakes == 0)
	check(walk_steps.size() >= 2 and walk_quiet,
		"Curved Greatsword walking keeps the supported footstep sound without run effects")
	print("MECHANIC_LAB_CURVED_STEP_FX run=", run_steps, " walk=", walk_steps)
	weapon.select(selected)
	weapon.item_selected.emit(selected)
	sound.button_pressed = sound_was_enabled
	lab.reset_player()
	await physics_frame

func check_steps_during_attacks(lab, dust: Node3D) -> void:
	var player = lab.player
	var picker := lab.get_node("HUD/Weapon") as OptionButton
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var movement = lab.get_node("MovementAudio")
	var selected := picker.selected
	var sound_was_enabled := toggle.button_pressed
	toggle.button_pressed = true
	for slot: int in [0, 2, 3, 6]:
		lab.reset_player()
		for i in 12:
			await physics_frame
		picker.select(slot)
		picker.item_selected.emit(slot)
		check(lab._equipped_weapon == slot, "The movement fixture equips %s" % picker.get_item_text(slot))
		for walking: bool in [false, true]:
			var expected_puffs := 0 if walking or slot == 3 else 1
			var counts := [0, 0]
			var last_audio := [int(movement.event_count.grass)]
			var observed := func(sole: Vector3, landed: bool):
				if landed:
					return
				var audio_before: int = last_audio[0]
				last_audio[0] = int(movement.event_count.grass)
				if player.active_clip in player.GAITS or not player._move_requested:
					return
				if slot != 3 and not (player._combat_was_moving or (slot == 6 and player.hybrid_motion.phase_advanced > 0.0)):
					return
				var ground: Dictionary = lab._player_foot_contact_at(sole)
				if ground.is_empty():
					return
				var contact_tick := Engine.get_physics_frames()
				var puffs: Array = dust._particles.filter(func(p): return p.sprite.visible and p.contact_tick == contact_tick)
				var correct_dust := puffs.size() == expected_puffs
				if expected_puffs == 1 and correct_dust:
					correct_dust = puffs[0].run_drag > 0.0 and puffs[0].velocity == Vector3.ZERO \
						and puffs[0].origin.is_equal_approx(ground.position + Vector3.UP * 0.20) \
						and is_equal_approx(puffs[0].sprite.pixel_size * 16.0, 1.0)
				var correct_audio: bool = last_audio[0] == audio_before + 1 \
					and movement.events[-1].at == [ground.position.x, ground.position.y, ground.position.z]
				counts[0] += 1
				counts[1] += int(correct_dust and correct_audio)
			player.surface_contact.connect(observed)
			for attack_at: int in [24, 33, 41]:
				lab.reset_player()
				for i in 9:
					await physics_frame
				Input.action_press("move_forward")
				if walking:
					Input.action_press("sprint")
				for i in 125:
					if i == attack_at or i == attack_at + 48:
						var attack := InputEventKey.new()
						attack.physical_keycode = KEY_E
						attack.pressed = i == attack_at
						root.push_input(attack, true)
					await physics_frame
				Input.action_release("move_forward")
				Input.action_release("sprint")
			player.surface_contact.disconnect(observed)
			var label := picker.get_item_text(slot)
			check(counts[0] > 0 and counts[0] == counts[1],
				"%s planted steps during %s attacks share the gait's dust and grass audio %s" %
				[label, "walking" if walking else "running", counts])
			print("MECHANIC_LAB_COMBAT_STEPS weapon=", label, " walk=", walking, " matched/total=", counts[1], "/", counts[0])
	lab.reset_player()
	for i in 12:
		await physics_frame
	picker.select(selected)
	picker.item_selected.emit(selected)
	toggle.button_pressed = sound_was_enabled

func check_dust_contact_clock(lab, dust) -> void:
	lab.reset_player()
	for i in 12:
		await physics_frame
	var peak_drift := [0.0, 0.0]
	var contact_count := [0, 0]
	var listen := func(_point: Vector3, landed: bool):
		var slot := int(landed)
		if contact_count[slot] > 0:
			return
		var particle = dust._particles[posmod(dust._next - 1, dust._particles.size())]
		var origin: Vector3 = particle.sprite.global_position
		var alpha: float = particle.sprite.modulate.a
		# The render interval includes time before the contact arrived.
		dust._process(0.15)
		peak_drift[slot] = origin.distance_to(particle.sprite.global_position)
		check(particle.sprite.visible and is_equal_approx(particle.sprite.modulate.a, alpha),
			"New movement dust keeps its initial alpha on the contact tick (landing=%s)" % landed)
		contact_count[slot] += 1
	lab.player.surface_contact.connect(listen)
	Input.action_press("move_forward")
	for i in 45:
		await physics_frame
		if contact_count[0] > 0:
			break
	Input.action_release("move_forward")
	Input.action_press("jump")
	for i in 75:
		await physics_frame
		if contact_count[1] > 0:
			break
	Input.action_release("jump")
	lab.player.surface_contact.disconnect(listen)
	check(contact_count == [1, 1] and maxf(peak_drift[0], peak_drift[1]) < 0.001,
		"Run and jump dust begin at the contact position, even after a delayed render")
	print("MECHANIC_LAB_DUST_CONTACT_CLOCK drift=", peak_drift, " contacts=", contact_count)
	lab.reset_player()

func check_zombie_steps_on_slab(lab) -> void:
	var group: Node = lab.get_node("Zombies")
	var dust = lab.get_node("ZombieStepDust")
	var audio = lab.get_node("CombatAudio")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var slab := StaticBody3D.new()
	slab.position.y = 0.09
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.18, 20.0)
	collision.shape = box
	slab.add_child(collision)
	lab.add_child(slab)
	lab.player.global_position = Vector3(0.45, 0.18, 3.7)
	lab.player.set_physics_process(false)
	toggle.button_pressed = true
	for i in 3:
		await physics_frame
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "The zombie spawns for the slab step fixture")
	else:
		var zombie := group.get_child(0) as CharacterBody3D
		zombie.global_position = Vector3(0.45, 0.185, -5.1)
		zombie.rotation.y = 0.0
		var exposed_steps: Array[Vector3] = []
		zombie.step_audio.connect(func(point: Vector3):
			if point.x > 0.5 and zombie.is_on_floor() and point.y > 0.16:
				exposed_steps.append(point))
		var before_audio: int = audio._next_choice.get(&"zombie_step", 0)
		for i in 130:
			await physics_frame
			if not exposed_steps.is_empty():
				break
		audio.flush_zombie_steps()
		var slab_audio: int = audio._next_choice.get(&"zombie_step", 0)
		check(not exposed_steps.is_empty() and zombie.global_position.y > 0.16,
			"A grounded zombie emits an authored contact beyond the slab edge")
		check(slab_audio == before_audio and dust._puffs.is_empty(),
			"A zombie step past the slab edge does not play audio or spawn dust in the grass below")
		print("MECHANIC_LAB_ZOMBIE_SLAB_STEP outside=", exposed_steps, " audio_changed=", slab_audio != before_audio,
			" puffs=", dust._puffs.size())
		slab.queue_free()
		lab.player.global_position = Vector3(0.45, 0.0, 6.0)
		dust.clear()
		for i in 100:
			await physics_frame
			if not dust._puffs.is_empty():
				break
		audio.flush_zombie_steps()
		check(zombie.is_on_floor() and absf(zombie.global_position.y) < 0.05
			and audio._next_choice.get(&"zombie_step", 0) != slab_audio and not dust._puffs.is_empty(),
			"A zombie resumes emitting its grass step, with sound and dust, after returning to grass")
	if is_instance_valid(slab) and not slab.is_queued_for_deletion():
		slab.queue_free()
	lab.player.set_physics_process(true)
	toggle.button_pressed = false
	lab.reset_player()
	await process_frame

func check_zombie_dust_contact_clock(lab) -> void:
	var dust := lab.get_node_or_null("ZombieStepDust") as MultiMeshInstance3D
	check(dust != null, "Zombie foot contacts use the batched source dust")
	if dust == null:
		return
	lab._on_zombie_step(Vector3.ZERO)
	dust._process(0.15)
	check(dust.multimesh.visible_instance_count == 1 and is_zero_approx(dust._puffs[0].age),
		"Zombie step dust starts at contact even when the first render interval is long")
	var oldest = dust._puffs[0]
	var first_tick := Engine.get_physics_frames()
	while Engine.get_physics_frames() < first_tick + ceili(Engine.physics_ticks_per_second * 0.25):
		await physics_frame
	lab._on_zombie_step(Vector3.RIGHT)
	dust._process(0.15)
	check(oldest.age > 0.20 and oldest.age < 0.30 and is_zero_approx(dust._puffs[1].age),
		"Existing zombie dust advances from its own step while a new puff starts at age zero")
	var second = dust._puffs[1]
	var second_transform := dust.multimesh.get_instance_transform(1)
	var second_data := dust.multimesh.get_instance_custom_data(1)
	oldest.lifetime = 0.1
	dust._process(0.0)
	check(dust.multimesh.visible_instance_count == 1 and dust._puffs[0] == second and second.slot == 0
		and dust.multimesh.get_instance_transform(0) == second_transform
		and dust.multimesh.get_instance_custom_data(0) == second_data,
		"An expired zombie puff yields its render slot and data to the surviving puff")
	var expiry := Engine.get_physics_frames() + ceili(Engine.physics_ticks_per_second * 1.80)
	while Engine.get_physics_frames() < expiry:
		await physics_frame
	await process_frame
	check(dust.multimesh.visible_instance_count == 0 and not dust.is_processing(),
		"The zombie dust batch expires by its source lifetime")

	# Retain the current ages and source data when a puff in the middle expires.
	for i in 128:
		dust.burst(Vector3(float(i) * 0.1, 0.0, 0.0))
	dust._process(0.0)
	var expired = dust._puffs[24]
	var previous_slots := {}
	for puff in dust._puffs:
		previous_slots[puff] = puff.slot
	expired.lifetime = 0.0
	dust._process(0.0)
	var moved := 0
	var used := {}
	for puff in dust._puffs:
		moved += int(puff.slot != previous_slots[puff])
		used[puff.slot] = true
	check(dust.multimesh.visible_instance_count == 127 and used.size() == 127
		and not expired in dust._puffs and moved <= 1,
		"Expiring one of 128 puffs keeps the remaining render slots stable")
	print("MECHANIC_LAB_DUST_REUSE relocated=", moved, " visible=", used.size())
	dust.clear()

	for i in dust.CAPACITY:
		dust.burst(Vector3(float(i) * 0.1, 0.0, 0.0))
	dust._process(0.0)
	const OVERFLOW := 300
	var expected_first = dust._puffs[OVERFLOW]
	var expected_last = dust._puffs.back()
	for i in OVERFLOW:
		dust.burst(Vector3(float(i) * 0.1, 0.0, -3.0))
	dust._process(0.0)
	check(dust.multimesh.visible_instance_count == dust.CAPACITY
		and dust._puffs[0] == expected_first and dust._puffs[dust.CAPACITY - OVERFLOW - 1] == expected_last,
		"An overflowing dust batch evicts the oldest puffs in spawn order")
	for puff in dust._puffs:
		puff.lifetime = 0.0
	dust._process(0.0)
	check(dust.multimesh.visible_instance_count == 0 and not dust.is_processing(),
		"Simultaneous expiry empties the draw batch")
	dust.clear()

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
