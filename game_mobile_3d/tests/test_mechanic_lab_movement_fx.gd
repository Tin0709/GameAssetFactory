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
		if particle.visible and not particle is MultiMeshInstance3D:
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
	await check_source_dust_batch(lab, dust)
	await check_gauntlet_debris(lab, dust)
	await check_colliding_debris(lab, dust)
	await check_gauntlet_impact_marks(lab)
	await check_tool_ground_effects(lab, dust)
	await check_ground_cue_render_hitch(lab, dust)
	await check_source_dust_and_wake_order(lab, dust, wind)
	await check_running_wake_support(lab, wind)
	await check_running_wake_render_clock(lab, wind, dust)
	await check_floor_edge_landing(lab, dust)
	await check_non_grass_landing(lab, dust)
	await check_non_grass_steps(lab, dust, wind)
	await check_downhill_steps(lab, dust, wind)
	await check_wall_slide_steps(lab, dust, wind)
	await check_curved_step_effects(lab, dust, wind)
	await check_steps_during_attacks(lab, dust)
	await check_landing_variation_is_independent(lab, dust.get_script())
	await check_dust_contact_clock(lab, dust)
	await check_zombie_steps_on_slab(lab)
	await check_zombie_dust_contact_clock(lab)
	await check_selected_landing_surfaces(lab, dust)
	await check_axe_ground_contact_dust(lab, dust)
	await check_selected_floor_steps(lab)
	print("MECHANIC_LAB_MOVEMENT_FX walk=", walking_peak, " wind=", running_wind, " landing=", landed_particles,
		" contacts=", contacts.size(), " failures=", failures)
	lab.free()
	quit(0 if failures.is_empty() else 1)

func check_source_dust_batch(lab, dust) -> void:
	if RenderingServer.get_current_rendering_method() != "mobile":
		return
	lab.reset_player()
	var batch := dust.get_node_or_null("LandingDustBatch") as MultiMeshInstance3D
	check(batch != null, "Forward Mobile batches source dust in MechanicLab")
	if batch == null:
		return
	dust._emit_run_dust(Vector3.RIGHT, "grass", 0.75)
	dust._emit_run_dust(Vector3.LEFT, "grass", 1.0)
	dust._emit_source_landing(Vector3.ZERO, "grass")
	dust._emit_source_landing(Vector3.FORWARD * 0.5, "grass")
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	var smoke: Array = dust._particles.filter(func(p): return p.sprite.visible)
	check(smoke.size() >= 10 and batch.multimesh.visible_instance_count == smoke.size()
		and smoke.all(func(p): return p.sprite.layers == 0),
		"Running dust and overlapping ordinary landings share one draw while retaining all particles")
	dust.emit_combat_debris(Vector3.ZERO, "grass", Engine.get_physics_frames())
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	check(batch.multimesh.visible_instance_count == 0 and smoke.all(func(p): return p.sprite.layers == 1),
		"Gauntlet debris restores individual sorting for overlapping smoke")
	dust.clear()
	check(not dust.is_processing() and batch.multimesh.visible_instance_count == 0 and not batch.visible,
		"Clearing the emitter immediately clears the landing draw")
	for surface in ["dirt", "stone"]:
		dust._emit_source_landing(Vector3.ZERO, surface)
		for i in 3:
			await physics_frame
		await process_frame
		await process_frame
		# process_frame is emitted before the dust renderer updates. More than
		# one physics tick can run before that first render at low FPS.
		var material := batch.multimesh.mesh.material as ShaderMaterial
		var landing: Array = dust._particles.filter(func(p): return p.sprite.visible)
		check(landing.size() in [4, 5, 6] and batch.multimesh.visible_instance_count == landing.size()
			and material.get_shader_parameter("dust_tint") == dust.SURFACE_DUST[surface]
			and landing.all(func(p): return not p.draw_pending and p.sprite.layers == 0),
			"A %s landing still uses one dust batch with the requested tint" % surface)
		dust._emit_source_landing(Vector3.RIGHT, "grass")
		for i in 3:
			await physics_frame
		await process_frame
		await process_frame
		var mixed: Array = dust._particles.filter(func(p): return p.sprite.visible)
		check(batch.multimesh.visible_instance_count == 0 and mixed.size() > landing.size()
			and mixed.all(func(p): return not p.draw_pending and p.sprite.layers == 1),
			"Mixed tints use individual sorting until their overlap ends")
		dust.clear()
	lab.reset_player()


func check_source_dust_and_wake_order(lab, dust, wind) -> void:
	var batch := dust.get_node_or_null("LandingDustBatch") as MultiMeshInstance3D
	if batch == null:
		return
	lab.reset_player()
	for i in 3:
		await physics_frame
	var center: Vector3 = lab.player.global_position
	var far: Vector3 = center + lab.camera.global_basis.x * 3.0
	dust._emit_run_dust(center, "grass", 1.0)
	dust._emit_run_dust(far, "grass", 1.0)
	dust._emit_run_dust(far + lab.camera.global_basis.x, "grass", 1.0)
	var wake = wind._wakes[0]
	wake.origin = center + Vector3.UP * 0.20
	wake.trailing = Vector3.FORWARD
	wake.contact_tick = Engine.get_physics_frames()
	wake.mesh.show()
	wind.set_process(true)
	await physics_frame
	dust._process(0.0)
	var individual := 0
	for particle in dust._particles:
		if particle.sprite.visible and particle.sprite.layers != 0:
			individual += 1
	check(batch.multimesh.visible_instance_count == 2 and individual == 1,
		"Smoke over a wind wake keeps its own draw order while the separated puffs stay batched")
	wind.clear()
	dust._process(0.0)
	check(batch.multimesh.visible_instance_count == 3,
		"All eligible puffs batch again when the wake expires")
	lab.reset_player()


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
	var pending_samples := 0
	var draw_mismatches := 0
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
		var render_tick := Engine.get_physics_frames() + Engine.get_physics_interpolation_fraction() - 1.0
		var pending: bool = wake.contact_tick > render_tick
		pending_samples += int(pending)
		draw_mismatches += int((wake.mesh.layers != 0) == pending)
		if dust._landing_batch == null:
			draw_mismatches += int((puff.sprite.layers != 0) == pending)
		else:
			var drawn := 0
			var individual := 0
			for particle in dust._particles:
				if particle.sprite.visible and particle.run_drag > 0.0 and particle.contact_tick <= render_tick:
					drawn += 1
					individual += int(particle.sprite.layers != 0)
			draw_mismatches += int(dust._landing_batch.multimesh.visible_instance_count + individual != drawn)
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
	check(draw_mismatches == 0, "Dust and wake draw only once presentation reaches their planted-foot contact")
	print("MECHANIC_LAB_WAKE_RENDER_CLOCK samples=", samples, " position_error_m=", max_position_error,
		" alpha_error=", max_alpha_error, " pending=", pending_samples, " draw_mismatches=", draw_mismatches)
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
	var puff_slots: Dictionary = {}
	var forward: Vector3 = lab.player.visual.global_basis.z.slide(Vector3.UP).normalized()
	for i in Engine.physics_ticks_per_second:
		await physics_frame
		var visible := visible_particles(dust)
		if not landings.is_empty() and visible > 0:
			for particle in dust._particles:
				if particle.sprite.visible and is_equal_approx(particle.sprite.pixel_size * 16.0, 0.88):
					puff_slots[particle] = particle.origin
			if burst_frame < 0:
				burst_frame = Engine.get_physics_frames() - 1
			if counts.is_empty() or counts.back() != visible:
				counts.append(visible)
	check(landings.size() == 1 and landings[0].particles == 0,
		"The actual Sabre dive suppresses the ordinary dust burst on touchdown")
	var delay_ticks := ceili(0.045126423 * Engine.physics_ticks_per_second)
	check(not landings.is_empty() and burst_frame == int(landings[0].frame) + delay_ticks,
		"The first visible heavy dust appears at the Sabre debris notify")
	check(not counts.is_empty() and counts.max() == 11, "The two Sabre notifies show ten heavy puffs plus one small puff")
	check(puff_slots.size() == 1 and absf(Vector3(puff_slots.values()[0]).dot(forward) - 0.90) < 0.02,
		"The separate Sabre puff appears once at the 90 cm source offset")
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
	check(landing_ticks.size() == 2 and heavy_peak == 11,
		"The running jump and follow-up Sabre dive both complete their landings")
	check(lost == 0, "The Sabre landing and later footsteps preserve visible dust from the ordinary landing")
	print("MECHANIC_LAB_OVERLAPPING_DUST lost=", lost, " heavy=", heavy_peak)
	lab.reset_player()
	await physics_frame

func check_gauntlet_debris(lab, dust: Node3D) -> void:
	for weapon in [lab.Weapon.GAUNTLETS, lab.Weapon.BASIC_GAUNTLETS]:
		lab._select_weapon(weapon)
		lab.reset_player()
		var landings: Array[Vector3] = []
		var record_landing := func(point: Vector3, forward: Vector3, _serial: int, _height: float) -> void:
			landings.assign([point, forward.slide(Vector3.UP).normalized()])
		lab.player.heavy_jump_landed.connect(record_landing, CONNECT_ONE_SHOT)
		await start_heavy_drop(lab)
		for i in 65:
			await physics_frame
			if visible_particles(dust) > 0:
				break
		var particles: Array = dust._particles.filter(func(p): return p.sprite.visible and p.debris_drag > 0.0)
		var puffs: Array = dust._particles.filter(func(p): return p.sprite.visible and p.debris_drag == 0.0)
		check(lab._equipped_weapon == weapon and lab.player.is_on_floor()
			and particles.size() in [3, 4, 5], "A Gauntlets dive emits one compact ground debris burst")
		check(puffs.size() == 1, "The Gauntlets dive has a separate compact impact puff")
		var impact = puffs[0] if puffs.size() == 1 else null
		check(landings.size() == 2, "The Gauntlets fixture records the real heavy touchdown")
		if impact != null and not particles.is_empty() and landings.size() == 2:
			var debris_offset: Vector3 = particles[0].origin - landings[0]
			var puff_offset: Vector3 = impact.origin - landings[0]
			check(debris_offset.slide(Vector3.UP).distance_to(landings[1] * 1.80) < 0.02,
				"The Gauntlets debris starts at the same 180 cm forward offset as the crack")
			check(impact.contact_tick == particles[0].contact_tick
				and puff_offset.slide(Vector3.UP).distance_to(landings[1] * 0.90) < 0.02
				and puff_offset.y > 0.12 and puff_offset.y < 0.20
				and impact.duration > 0.20 and impact.duration < 0.35,
				"The short dust layer shares the landing clock and keeps its independent 90 cm offset")
			print("GAUNTLET_ANCHORS weapon=", weapon, " debris_m=", debris_offset.dot(landings[1]),
				" puff_m=", puff_offset.dot(landings[1]))
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
		if impact != null:
			check(not impact.sprite.visible and particles.any(func(p): return p.sprite.visible),
				"The impact puff fades while the source debris is still active")
		print("MECHANIC_LAB_GAUNTLET_DEBRIS weapon=", weapon, " count=", particles.size(),
			" samples=", samples, " motion_error_m=", motion_error)
		lab.reset_player()
		await physics_frame
		check(visible_particles(dust) == 0 and not dust.is_processing(), "Reset clears Gauntlets debris")
	var edge := Vector3(49.8, 0.0, 0.0)
	lab._show_gauntlet_ground_impact(edge, Vector3.RIGHT, "grass")
	var edge_puff = dust._particles[posmod(dust._next - 1, dust._particles.size())]
	var edge_position: Vector3 = edge_puff.origin
	check(edge_position.slide(Vector3.UP).distance_to(edge) < 0.01,
		"An impact offset beyond the floor falls back to the actual landing contact")
	dust.clear()
	lab._select_weapon(lab.Weapon.SABRE)

func check_colliding_debris(lab, dust: Node3D) -> void:
	var detail := lab.get_node_or_null("HUD/ImpactFxPanel/Rows/DebrisQuality") as OptionButton
	check(detail != null, "The impact panel provides the detailed debris profile")
	if detail == null:
		return
	var actor = lab.player
	check(detail.selected == 0, "MechanicLab starts with the existing light debris")
	detail.select(1)
	detail.item_selected.emit(1)
	for fixture in ["flat", "wall", "ledge"]:
		lab.reset_player()
		for i in 12:
			await physics_frame
		lab._select_weapon(lab.Weapon.BASIC_GAUNTLETS)
		if fixture == "ledge":
			actor._reset_map_actor_at(Vector3(48.05, 0.015, 0), PI * 0.5)
		var forward: Vector3 = actor.visual.global_basis.z.slide(Vector3.UP).normalized()
		var wall: StaticBody3D
		# Leave room for the 1.10 m mark so the debris launches near the wall.
		var wall_face := 2.40
		if fixture == "wall":
			wall = StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(8.0, 4.0, 0.18)
			collision.shape = shape
			wall.add_child(collision)
			wall.transform = Transform3D(Basis.looking_at(forward, Vector3.UP, true),
				forward * (wall_face + 0.09) + Vector3.UP * 2.0)
			lab.add_child(wall)
		for i in 12:
			await physics_frame
		dust._random.seed = 27625
		await start_heavy_drop(lab)
		var fragments: Array = []
		for i in 70:
			await physics_frame
			fragments = dust._particles.filter(func(p): return p.sprite.visible and p.debris_drag > 0.0)
			if not fragments.is_empty():
				break
		check(fragments.size() in [5, 6, 7] and fragments.all(func(p): return p.duration >= 5.0 and p.duration <= 6.0),
			"%s uses the source count and lifetime of the detailed profile" % fixture)
		var closest_floor := INF
		var furthest := -INF
		var fell_beyond_edge := false
		var rebounded := false
		var fell: Dictionary = {}
		var previous: Dictionary = {}
		for i in 150:
			await physics_frame
			for particle in fragments:
				var point: Vector3 = particle.sprite.global_position
				closest_floor = minf(closest_floor, point.y)
				furthest = maxf(furthest, point.dot(forward))
				fell_beyond_edge = fell_beyond_edge or (point.x > 50.2 and point.y < -0.06)
				if previous.has(particle):
					var before: Vector3 = previous[particle]
					if before.y > point.y + 0.003:
						fell[particle] = true
					rebounded = rebounded or (fell.has(particle) and point.y > before.y + 0.003)
				previous[particle] = point
		if fixture == "ledge":
			check(fell_beyond_edge, "Fragments can fall off the actual floor edge")
		else:
			check(closest_floor > 0.07 and rebounded, "%s fragments rebound above the real floor" % fixture)
		if fixture == "wall":
			check(furthest <= wall_face - 0.095 and furthest >= wall_face - 0.18,
				"The swept fragments reach the wall without crossing it")
		print("DEBRIS_CONTACT fixture=", fixture, " count=", fragments.size(), " floor_m=", closest_floor,
			" furthest_m=", furthest, " bounce=", rebounded, " fall=", fell_beyond_edge)
		if wall != null:
			wall.free()
		lab.reset_player()
		await physics_frame
		check(visible_particles(dust) == 0 and not dust.is_physics_processing(),
			"Reset releases every moving or settled debris slot")
	detail.select(0)
	detail.item_selected.emit(0)
	lab._select_weapon(lab.Weapon.SABRE)

func check_gauntlet_impact_marks(lab) -> void:
	var marks := lab.get_node_or_null("CombatEffects/GauntletImpactMarks") as Node3D
	check(marks != null, "The Lab has a pooled receiver for the verified Gauntlets impact atlas")
	if marks == null:
		return
	var pool := marks.get_children()
	var dust: Node3D = lab.get_node("MovementDust")
	check(pool.size() == 4, "The impact mark renderer has four reusable slots")
	var camera_ground: MeshInstance3D = lab.get_node("Ground/Mesh")
	var player_mesh: MeshInstance3D = lab._basic_gauntlet_mounts[0]
	for slot: Node in pool:
		if RenderingServer.get_current_rendering_method() == &"gl_compatibility":
			var flat := slot as MeshInstance3D
			check(flat != null and flat.mesh is PlaneMesh and flat.mesh.size == Vector2(1.10, 1.10)
				and flat.material_override.get_shader_parameter(&"mark_mask").get_size() == Vector2(16, 16),
				"The flat mark uses the same dimensions and one atlas tile")
		else:
			var decal := slot as Decal
			check(decal != null and decal.texture_albedo.get_size() == Vector2(16, 16)
				and (decal.cull_mask & camera_ground.layers) != 0 and (decal.cull_mask & player_mesh.layers) == 0,
				"The decal uses one atlas tile and projects only onto the stage")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var audio: Node = lab.get_node("CombatAudio")
	toggle.button_pressed = true
	for fixture in ["grass", "dirt", "stone_wall", "stone_wall_far", "stone_footprint", "slab"]:
		lab.reset_player()
		for i in 8:
			await physics_frame
		lab._select_weapon(lab.Weapon.BASIC_GAUNTLETS if fixture == "grass" else lab.Weapon.GAUNTLETS)
		var surface := "stone" if fixture.begins_with("stone") else ("dirt" if fixture == "dirt" else "grass")
		lab._select_floor_surface(["grass", "dirt", "stone"].find(surface))
		var forward: Vector3 = lab.player.visual.global_basis.z.slide(Vector3.UP).normalized()
		var obstacle: StaticBody3D
		var wall_face := 0.90 if fixture == "stone_wall" else 1.35
		if fixture == "stone_footprint":
			wall_face = 2.10
		if fixture.begins_with("stone") or fixture == "slab":
			obstacle = StaticBody3D.new()
			var box := BoxShape3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = box
			obstacle.add_child(shape)
			if fixture.begins_with("stone"):
				box.size = Vector3(2.0, 2.0, 0.2)
				obstacle.transform = Transform3D(Basis.looking_at(forward, Vector3.UP, true),
					forward * (wall_face + 0.1) + Vector3.UP)
			else:
				box.size = Vector3(2.0, 0.4, 2.0)
				obstacle.position = Vector3.UP * 0.2
				lab.player.position.y += 0.4
			lab.add_child(obstacle)
		for i in 8:
			await physics_frame
		var cue := StringName("slam_" + surface)
		var initial_cue: int = audio._next_choice.get(cue, 0)
		await start_heavy_drop(lab)
		var appeared: Node3D
		for i in 65:
			await physics_frame
			for mark: Node3D in pool:
				if mark.visible:
					appeared = mark
					break
			if appeared != null:
				break
		if fixture == "slab":
			check(appeared == null and lab.player.is_on_floor() and lab.player.global_position.y > 0.39,
				"An unsupported slab material cannot imprint the stage below")
			check(visible_particles(dust) == 0 and audio._next_choice.get(cue, 0) == initial_cue,
				"An unsupported slab emits no stage debris, dust or debris audio below")
		else:
			check(appeared != null and lab.player.is_on_floor(), "The %s Gauntlets dive leaves its mark on touchdown" % fixture)
			if appeared != null:
				var reach := appeared.global_position.dot(forward)
				var expected := 0.0 if fixture.begins_with("stone") else 1.8
				check(absf(reach - expected) < 0.02 and absf(appeared.global_position.y) < 0.03,
					"The %s crack stays on the supported side of the stage" % fixture)
				var particles: Array = dust._particles.filter(func(p): return p.sprite.visible and p.debris_drag > 0.0)
				check(particles.size() in [3, 4, 5] and particles.all(func(p):
						return p.origin.slide(Vector3.UP).distance_to(appeared.global_position.slide(Vector3.UP)) < 0.02),
					"The crack and debris share the support point in the %s fixture" % fixture)
				if fixture.begins_with("stone"):
					check(reach + marks.PROJECTION_SIZE.x * 0.5 < wall_face, "The entire mark fits in front of the wall")
					var puffs: Array = dust._particles.filter(func(p): return p.sprite.visible and p.debris_drag == 0.0)
					var expected_puff := 0.0 if fixture == "stone_wall" else 0.90
					check(puffs.size() == 1 and absf(puffs[0].origin.dot(forward) - expected_puff) < 0.02,
						"The puff keeps its 90 cm offset when it fits before the wall")
				var voices: Array = audio._surface_landing_voices.filter(func(voice):
					return voice.playing and voice.stream in audio._groups[cue])
				check(audio._next_choice.get(cue, 0) == (initial_cue + 1) % audio._groups[cue].size()
					and voices.size() == 1 and voices[0].global_position.distance_to(appeared.global_position) < 0.02,
					"The %s Gauntlets debris sound plays once at the mark" % fixture)
				var debris_reach: float = particles[0].origin.dot(forward) if not particles.is_empty() else -1.0
				var audio_reach: float = voices[0].global_position.dot(forward) if not voices.is_empty() else -1.0
				print("GAUNTLET_IMPACT_MARK ", fixture, " mark_m=", reach,
					" debris_m=", debris_reach, " audio_m=", audio_reach)
				if fixture == "grass":
					lab.reset_player()
					check(not appeared.visible and not marks.is_processing(), "Reset clears an active mark immediately")
				else:
					for i in 75:
						await physics_frame
					check(not appeared.visible and not marks.is_processing(), "The mark expires and stops processing")
		if obstacle != null:
			obstacle.free()
	toggle.button_pressed = false
	lab.reset_player()
	await physics_frame
	lab._select_floor_surface(0)
	lab._select_weapon(lab.Weapon.SABRE)
	check(pool.all(func(mark: Node3D): return not mark.visible), "Reset hides every retained impact mark")

func check_tool_ground_effects(lab, dust: Node3D) -> void:
	var actor = lab.player
	var ring := lab.get_node_or_null("CombatEffects/ToolGroundSlam") as MeshInstance3D
	check(ring != null and actor.has_signal(&"tool_ground_cue"), "The Lab has physical ground cues for Pickaxe and Shovel")
	if ring == null or not actor.has_signal(&"tool_ground_cue"):
		return
	var cues: Array[float] = []
	var cue_clocks: Array[float] = []
	var record := func(cue: Dictionary, _serial: int, sample: float):
		cues.append(actor.combo.time - (actor.effects.clock - sample) * actor.combo.playback_rate())
		cue_clocks.append(sample)
	actor.connect(&"tool_ground_cue", record)
	for fixture in ["grass", "dirt", "stone", "wall", "near_wall", "post", "arena_edge",
			"overhang", "outside_disc", "ledge", "shovel", "reset_during_windup"]:
		lab.reset_player()
		lab._select_floor_surface(maxi(lab.FLOOR_SURFACES.find(fixture), 0))
		lab._select_weapon(lab.Weapon.SHOVEL if fixture == "shovel" else lab.Weapon.PICKAXE)
		var forward: Vector3 = actor.visual.global_basis.z.slide(Vector3.UP).normalized()
		var obstacle: StaticBody3D
		var overhang: Node3D
		if fixture == "overhang":
			overhang = Node3D.new()
			lab.add_child(overhang)
			var side := Vector3.UP.cross(forward)
			# Ten boxes touch the old query volume but sit wholly above the
			# ring plane and off the ray that places the impact on grass.
			var box := BoxShape3D.new()
			box.size = Vector3(0.10, 0.025, 0.085)
			for i in 10:
				var shelf := StaticBody3D.new()
				var collision := CollisionShape3D.new()
				collision.shape = box
				shelf.add_child(collision)
				var forward_offset := 1.24 + (i % 5) * 0.12
				var side_offset := 0.26 if i < 5 else -0.26
				shelf.position = forward * forward_offset + side * side_offset + Vector3.UP * 0.069
				overhang.add_child(shelf)
		elif fixture == "outside_disc":
			overhang = Node3D.new()
			lab.add_child(overhang)
			var side := Vector3.UP.cross(forward)
			var box := BoxShape3D.new()
			box.size = Vector3(0.024, 0.07, 0.024)
			for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
				for i in 3:
					var post := StaticBody3D.new()
					var collision := CollisionShape3D.new()
					collision.shape = box
					post.add_child(collision)
					var forward_offset := 1.5 + corner.y * (0.55 + i * 0.043)
					post.position = forward * forward_offset + side * corner.x * 0.59 + Vector3.UP * 0.035
					overhang.add_child(post)
		if fixture == "arena_edge":
			actor._reset_map_actor_at(Vector3(48.18, 0.015, 0), PI * 0.5)
		if fixture in ["wall", "near_wall", "post", "ledge"]:
			obstacle = StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			shape.shape = box
			obstacle.add_child(shape)
			if fixture in ["wall", "near_wall"]:
				box.size = Vector3(3.0, 2.0, 0.2)
				var wall_normal := forward.rotated(Vector3.UP, deg_to_rad(25.0)) if fixture == "near_wall" else forward
				var front := forward * 1.99 + wall_normal * 0.1 if fixture == "near_wall" else forward
				obstacle.transform = Transform3D(Basis.looking_at(wall_normal, Vector3.UP, true), front + Vector3.UP)
			elif fixture == "post":
				box.size = Vector3(0.12, 0.14, 0.12)
				obstacle.rotation.y = deg_to_rad(23.0)
				obstacle.position = forward * 1.93 + Vector3.UP.cross(forward) * 0.23 + Vector3.UP * 0.07
			else:
				box.size = Vector3(1.1, 0.4, 1.1)
				obstacle.position.y = 0.2
				actor.position.y += 0.4
			lab.add_child(obstacle)
		for i in 12:
			await physics_frame
		cues.clear()
		cue_clocks.clear()
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = true
		root.push_input(key, true)
		var peak := 0
		var ring_seen := false
		var cancelled := false
		var expected := [0.765836, 0.213588, 0.279747] if fixture == "shovel" else [0.270322, 0.273662, 0.277670, 0.298377]
		for i in Engine.physics_ticks_per_second * 5:
			await physics_frame
			if fixture == "reset_during_windup" and actor.combo.index == 2 and actor.combo.time >= 0.18:
				lab.reset_player()
				cancelled = true
				break
			peak = maxi(peak, visible_particles(dust))
			ring_seen = ring_seen or ring.visible
			if cues.size() >= expected.size():
				break
		key = InputEventKey.new()
		key.physical_keycode = KEY_E
		root.push_input(key, true)
		if fixture == "reset_during_windup":
			for i in 20:
				await physics_frame
			lab._select_weapon(lab.Weapon.SABRE)
			check(cancelled and cues.is_empty() and not ring.visible and visible_particles(dust) == 0
				and lab._equipped_weapon == lab.Weapon.SABRE, "Reset during windup cancels Pickaxe ground cues")
			continue
		for i in 3:
			await physics_frame
			peak = maxi(peak, visible_particles(dust))
			ring_seen = ring_seen or ring.visible
		check(cues.size() == expected.size(), "%s emits each montage cue once" % fixture)
		for index in mini(cues.size(), expected.size()):
			check(absf(cues[index] - float(expected[index])) < 0.00001,
				"%s cue %d crosses the authored source timestamp" % [fixture, index + 1])
		check(not lab._impact_light.visible, "%s ground effects do not fake a zombie hit light" % fixture)
		if fixture in ["grass", "dirt", "stone"]:
			check(ring_seen and peak >= 4, "%s Pickaxe finisher emits a ring, debris and dust without a target" % fixture)
			check(absf((ring.global_position - actor.global_position).dot(forward) - 1.5) < 0.02,
				"The Pickaxe ring uses the independent 150 cm cue offset")
			var ring_tint: Color = ring.material_override.get_shader_parameter(&"tint")
			check(ring_tint.is_equal_approx(dust.SURFACE_DUST[fixture].lightened(0.36)),
				"The Pickaxe ring follows the surface tint on %s" % fixture)
			var debris: Array = dust._particles.filter(func(p): return p.sprite.visible and p.debris_drag > 0.0)
			check(not debris.is_empty() and debris.all(func(p):
				return absf((p.origin - actor.global_position).dot(forward) - 1.8) < 0.02 \
					and Color(p.sprite.modulate, 1.0) == dust.SURFACE_DUST[fixture]),
				"The Pickaxe debris uses the 180 cm cue and samples the selected surface tint")
		elif fixture in ["near_wall", "post", "arena_edge"]:
			check(ring_seen, "The %s keeps the supported part of the Pickaxe shockwave" % fixture)
			if ring_seen:
				var material := ring.material_override as ShaderMaterial
				if fixture == "arena_edge":
					check(material.get_shader_parameter("clip_count") == 1
						and material.get_shader_parameter("blocker_count") == 0,
						"The edge of the arena uses one boundary plane and no obstacles")
					var planes: PackedVector3Array = material.get_shader_parameter("clip_planes")
					var normal := Vector2(planes[0].x, planes[0].y)
					var edge_offset := Vector3(50.0, 0.0, 0.0) - ring.global_position
					check(normal.dot(Vector2.LEFT) > 0.999
						and absf(normal.dot(Vector2(edge_offset.x, edge_offset.z)) + planes[0].z) < 0.015,
						"The clipping plane matches the arena edge within 1.5 cm")
				else:
					check(material.get_shader_parameter("clip_count") == 0
						and material.get_shader_parameter("blocker_count") == 1,
						"The %s uses the finite box instead of a plane across the ring" % fixture)
					var axes: PackedVector4Array = material.get_shader_parameter("blocker_axes")
					var box_shape := (obstacle.get_child(0) as CollisionShape3D).shape as BoxShape3D
					var local := obstacle.to_local(ring.global_position)
					check(axes.size() >= 2 and absf(axes[0].z - local.x) < 0.001
						and absf(axes[1].z - local.z) < 0.001
						and is_equal_approx(axes[0].w * 2.0, box_shape.size.x)
						and is_equal_approx(axes[1].w * 2.0, box_shape.size.z),
						"The %s projection uses the actual collider size and position" % fixture)
		elif fixture == "overhang":
			check(ring_seen and peak >= 4, "Ten boxes above the reaction plane leave the Pickaxe ring visible")
			var material := ring.material_override as ShaderMaterial
			check(material.get_shader_parameter("clip_count") == 0
				and material.get_shader_parameter("blocker_count") == 0,
				"Overhanging boxes contribute no clipping planes")
			print("TOOL_RING_OVERHANG visible=", ring_seen, " peak=", peak)
		elif fixture == "outside_disc":
			check(ring_seen and peak >= 4, "Posts outside the maximum ring radius leave the shockwave visible")
			var material := ring.material_override as ShaderMaterial
			check(material.get_shader_parameter("clip_count") == 0
				and material.get_shader_parameter("blocker_count") == 0,
				"Posts outside the shockwave disc consume no clipping slots")
		elif fixture == "shovel":
			check(peak >= 4 and not ring_seen, "Shovel emits the separate debris passes without the Pickaxe ring")
		else:
			check(not ring_seen and peak == 0,
				"%s does not show impact geometry beyond support" % fixture)
		var shake_index := 1 if fixture == "shovel" else 3
		check(cue_clocks.size() > shake_index and lab._shake_duration > 0.0
			and absf(lab._shake_sample_time - cue_clocks[shake_index]) < 0.045,
			"The %s camera pulse comes from the montage instead of enemy contact" % fixture)
		print("TOOL_GROUND_FX ", fixture, " cues=", cues, " peak=", peak, " ring=", ring_seen)
		if obstacle != null:
			obstacle.free()
		if overhang != null:
			overhang.free()
		lab.reset_player()
		check(not ring.visible and visible_particles(dust) == 0, "Reset clears the tool ring and particles")
	actor.disconnect(&"tool_ground_cue", record)
	lab._select_floor_surface(0)
	lab._select_weapon(lab.Weapon.SABRE)
	await physics_frame

func check_ground_cue_render_hitch(lab, dust: Node3D) -> void:
	var dust_mode := dust.process_mode
	var dust_counts := {lab.Weapon.PICKAXE: 1, lab.Weapon.MEAT_CLEAVER: 2, lab.Weapon.AXE: 10}
	var active_smoke := func() -> Array:
		return dust._particles.filter(func(p): return p.sprite.visible and p.debris_drag == 0.0)
	for weapon: int in dust_counts:
		lab.reset_player()
		lab._select_weapon(weapon)
		for i in 12:
			await physics_frame
		dust.process_mode = Node.PROCESS_MODE_DISABLED
		lab.set_process(false)
		var airborne: bool = weapon != lab.Weapon.PICKAXE
		if airborne:
			check(lab.player.drop_for_lab(5.0), "A real dive starts the delayed ground cue fixture")
			for i in 2:
				await physics_frame
		var attack := InputEventKey.new()
		attack.physical_keycode = KEY_E
		attack.pressed = true
		root.push_input(attack, true)
		for i in Engine.physics_ticks_per_second * 4:
			await physics_frame
			if active_smoke.call().size() >= dust_counts[weapon]:
				break
		attack = InputEventKey.new()
		attack.physical_keycode = KEY_E
		root.push_input(attack, true)
		var born: Array = active_smoke.call()
		check(born.size() == dust_counts[weapon], "The attack emits its authored ground dust layers")
		check(born.all(func(p): return p.sprite.layers == 0), "The pending dust is off screen")
		for i in ceili(0.45 * Engine.physics_ticks_per_second):
			await physics_frame
		dust._process(0.45)
		lab._process(0.45)
		var drawn := born.filter(func(p): return p.sprite.visible and p.sprite.layers == 1)
		var step := dust.get_physics_process_delta_time()
		check(drawn.size() == dust_counts[weapon]
			and drawn.all(func(p): return p.age <= step + 0.0001),
			"The first displayed combat dust begins near its launch age after a hitch")
		if weapon != lab.Weapon.AXE:
			check(lab._tool_slam_ring.visible and absf(lab.camera.h_offset) > 0.001,
				"The delayed ground dust, shockwave and camera kick start on the same frame")
		print("GROUND_CUE_HITCH weapon=", weapon, " born=", born.size(), " drawn=", drawn.size(),
			" ring=", lab._tool_slam_ring.visible, " camera=", lab.camera.h_offset)
		for i in 4:
			await physics_frame
		dust._process(4.0 * step)
		check(drawn.all(func(p): return p.age > step * 3.0), "After the first image, the burst advances normally")
		for i in ceili(0.45 * Engine.physics_ticks_per_second):
			await physics_frame
		dust._process(0.45)
		check(active_smoke.call().is_empty(), "An already displayed puff expires after a later hitch")
		dust.process_mode = dust_mode
		lab.set_process(true)
	lab.reset_player()

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
	var heavy_ticks: Array[int] = []
	var record_heavy := func(point: Vector3, _direction: Vector3, _serial: int, _height: float):
		heavy_landings.append(point)
		heavy_ticks.append(Engine.get_physics_frames())
	lab.player.heavy_jump_landed.connect(record_heavy)
	toggle.button_pressed = true
	for attack: StringName in [&"ordinary", &"sabre", &"sword"]:
		var heavy := attack != &"ordinary"
		if attack == &"sword":
			lab._select_weapon(lab.Weapon.SWORD)
			check(lab._equipped_weapon == lab.Weapon.SWORD, "The slab fixture equips Sword before takeoff")
		lab.reset_player()
		lab.player.global_position = Vector3(0.53, 1.0, 0.0)
		var ordinary_before: int = movement.event_count.landing
		var heavy_before: int = audio._next_choice.get(&"slam_grass", 0)
		var sword_before: int = audio._next_choice.get(&"slam", 0)
		heavy_landings.clear()
		heavy_ticks.clear()
		if heavy:
			lab.player.global_position.y = 5.0
			await press_heavy_attack()
		var peak_dust := 0
		var sword_tick := -1
		var sword_point := Vector3.INF
		for i in 70:
			await physics_frame
			peak_dust = maxi(peak_dust, visible_particles(dust))
			if sword_tick < 0 and audio._next_choice.get(&"slam", 0) != sword_before:
				sword_tick = Engine.get_physics_frames() - 1
				for voice: AudioStreamPlayer3D in audio._voices:
					if voice.stream in audio._groups[&"slam"]:
						sword_point = voice.global_position
						break
		check(lab.player.is_on_floor() and lab.player.global_position.y > 0.20,
			"The player's capsule comes to rest on the raised slab")
		check(heavy_landings.size() == int(heavy) and peak_dust == 0
			and movement.event_count.landing == ordinary_before
			and audio._next_choice.get(&"slam_grass", 0) == heavy_before,
			"Landing on a slab edge does not emit dust or audio for the grass below (heavy=%s)" % heavy)
		print("MECHANIC_LAB_SLAB_LANDING heavy=", heavy, " y=", lab.player.global_position.y,
			" peak_dust=", peak_dust, " grass_landings=", movement.event_count.landing - ordinary_before,
			" heavy_landings=", heavy_landings.size())
		if attack == &"sword":
			check(heavy_ticks.size() == 1 and sword_tick == heavy_ticks[0]
				and audio._next_choice.get(&"slam", 0) == (sword_before + 1) % audio._groups[&"slam"].size(),
				"Sword plays one verified heavy-hit sample on touchdown without a grass layer")
			check(sword_point.is_finite() and absf(sword_point.y - 0.24) < 0.015,
				"The Sword heavy-hit sample starts on the slab's real support surface")
			print("MECHANIC_LAB_SWORD_SLAB_AUDIO tick=", sword_tick, " support=", sword_point)
	lab.player.heavy_jump_landed.disconnect(record_heavy)
	lab._select_weapon(lab.Weapon.SABRE)
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

func check_downhill_steps(lab, dust, wind) -> void:
	var player = lab.player
	var movement = lab.get_node("MovementAudio")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var ramp := StaticBody3D.new()
	ramp.position.y = 0.21
	ramp.rotation.x = 0.045
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.12, 15.0)
	shape.shape = box
	ramp.add_child(shape)
	lab.add_child(ramp)
	toggle.button_pressed = true
	lab.reset_player()
	player.scripted_input = true
	player.global_position = Vector3(0.43, 0.65, 0.0)
	for i in 34:
		await physics_frame
	var snapped_steps := [0]
	var on_contact := func(point: Vector3, landed: bool):
		if (not landed and point.x > 0.5 and player.is_on_floor()
				and player.get_slide_collision_count() == 0 and player.global_position.y > 0.05):
			snapped_steps[0] += 1
	player.surface_contact.connect(on_contact)
	var before_audio: int = movement.event_count.grass
	var before_dust: int = dust._next
	var before_wind: int = wind._next
	player.requested_run = true
	player.requested_direction = Vector2(0, 1)
	for i in 45:
		await physics_frame
	player.surface_contact.disconnect(on_contact)
	var grass_cues: int = movement.event_count.grass - before_audio
	check(snapped_steps[0] > 0,
		"The actor takes a downhill step over the ramp edge with floor snap holding support")
	check(grass_cues == 0 and dust._next == before_dust and wind._next == before_wind,
		"A snapped step on the ramp does not emit the grass below it")
	print("MECHANIC_LAB_DOWNHILL_STEPS snapped=", snapped_steps[0], " grass_audio=", grass_cues,
		" dust=", dust._next != before_dust, " wind=", wind._next != before_wind)
	ramp.free()
	player.scripted_input = false
	toggle.button_pressed = false
	lab.reset_player()
	await physics_frame

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

func check_landing_variation_is_independent(lab, emitter_script: Script) -> void:
	var player = lab.player
	var only_landings: Node3D = emitter_script.new()
	var with_steps: Node3D = emitter_script.new()
	for emitter in [only_landings, with_steps]:
		var step_profile := Callable(player, "source_step_dust_size") if emitter == with_steps else func() -> float: return 0.0
		var ready: bool = emitter.setup(player, null, lab._player_foot_contact_at,
			Callable(), lab._floor_landing_contact_at, step_profile, true)
		check(ready, "The independent landing fixture loads the verified dust")
		emitter.use_source_landing()
		lab.add_child(emitter)
	var without_steps: Array[Array] = []
	var after_steps: Array[Array] = []
	var regular_steps := [0]
	var compare := func(_sole: Vector3, landed: bool):
		var tick := Engine.get_physics_frames()
		if landed:
			without_steps.append(landing_emission_signature(only_landings, tick))
			after_steps.append(landing_emission_signature(with_steps, tick))
		elif with_steps._particles.any(func(p): return p.sprite.visible and p.contact_tick == tick and p.run_drag > 0.0):
			regular_steps[0] += 1
	player.surface_contact.connect(compare)
	for trial in 3:
		lab.reset_player()
		for i in 12:
			await physics_frame
		Input.action_press("move_forward")
		for i in 38:
			await physics_frame
		Input.action_press("jump")
		await physics_frame
		await physics_frame
		Input.action_release("jump")
		for i in 70:
			await physics_frame
		Input.action_release("move_forward")
	player.surface_contact.disconnect(compare)
	check(regular_steps[0] >= 3 and without_steps.size() == 3
		and without_steps.all(func(row): return row.size() >= 4 and row.size() <= 6),
		"The replay emits real MD2 run puffs and three ordinary landing bursts")
	check(without_steps.size() == 3 and without_steps == after_steps and without_steps[0] != without_steps[-1],
		"Landing particles vary between jumps independently of the run steps")
	print("MECHANIC_LAB_LANDING_VARIATION steps=", regular_steps[0], " jumps=", without_steps.size(),
		" independent=", without_steps == after_steps)
	only_landings.free()
	with_steps.free()
	lab.reset_player()
	await physics_frame

func landing_emission_signature(emitter, tick: int) -> Array[String]:
	var result: Array[String] = []
	for particle in emitter._particles:
		if particle.sprite.visible and particle.contact_tick == tick and particle.landing_tick == 0:
			result.append(var_to_bytes([particle.velocity, particle.duration, particle.sprite.frame]).hex_encode())
	# Pool slots can differ because one emitter has live footstep sprites.
	result.sort()
	return result

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

func check_axe_ground_contact_dust(lab, dust: Node3D) -> void:
	var actor: CharacterBody3D = lab.player
	var audio: Node = lab.get_node("CombatAudio")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	for data: Array in [[0, "grass", "flat"], [1, "dirt", "flat"], [2, "stone", "wall"], [2, "stone", "ledge"]]:
		var surface: String = data[1]
		var fixture: String = data[2]
		lab.reset_player()
		for i in 8:
			await physics_frame
		lab._select_floor_surface(data[0])
		lab._select_weapon(lab.Weapon.AXE)
		check(lab._equipped_weapon == lab.Weapon.AXE, "The ground contact test equips the Axe")
		var forward: Vector3 = actor.visual.global_basis.z.slide(Vector3.UP).normalized()
		var stage_origin := actor.global_position
		var obstacle: StaticBody3D
		if fixture != "flat":
			obstacle = StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			collision.shape = box
			obstacle.add_child(collision)
			if fixture == "wall":
				box.size = Vector3(3.0, 0.25, 0.20)
				obstacle.transform = Transform3D(Basis.looking_at(forward, Vector3.UP, true),
					stage_origin + forward + Vector3.UP * 0.11)
			else:
				box.size = Vector3(1.0, 0.4, 1.0)
				obstacle.position = Vector3(stage_origin.x, 0.20, stage_origin.z)
				actor.position.y += 0.40
			lab.add_child(obstacle)
		var cue := StringName("slam_" + surface)
		var before: int = audio._next_choice.get(cue, 0)
		await start_heavy_drop(lab)
		var contact_tick := -1
		var dust_tick := -1
		var sound_tick := -1
		var first_particles: Array = []
		for i in Engine.physics_ticks_per_second * 2:
			await physics_frame
			var tick := Engine.get_physics_frames() - 1
			if dust_tick == -1 and visible_particles(dust) > 0:
				dust_tick = tick
				first_particles = dust._particles.filter(func(particle): return particle.sprite.visible)
			if sound_tick == -1 and audio._next_choice.get(cue, 0) != before:
				sound_tick = tick
			if contact_tick == -1 and lab._light_serial >= 0:
				contact_tick = tick
			if contact_tick >= 0 and tick >= contact_tick + 5:
				break
		check(contact_tick >= 0, "The %s Axe dive has one blade impact cue" % fixture)
		var point: Vector3 = lab._slam_burst_point
		var tolerance := 0.0001
		if fixture == "ledge":
			check(dust_tick == -1 and sound_tick == -1, "An unclassified ledge emits no terrain dust or surface sound")
		else:
			check(dust_tick == contact_tick and sound_tick == contact_tick and first_particles.size() == dust.HEAVY_PARTICLE_COUNT,
				"The %s/%s Axe dust and surface audio share the contact tick while retaining the ten particles" % [surface, fixture])
			var tint: Color = dust.SURFACE_DUST[surface]
			check(not first_particles.is_empty() and first_particles.all(func(p):
				var offset: Vector3 = (p.origin - point).slide(Vector3.UP)
				return offset.length() <= 0.42 + tolerance and Color(p.sprite.modulate, 1.0).is_equal_approx(tint)),
				"The %s Axe dust is placed around the supported blade impact" % fixture)
			check(audio._next_choice.get(cue, 0) == (before + 1) % 6,
				"The %s Axe plays one surface voice" % fixture)
			if fixture == "wall":
				check(first_particles.all(func(p):
					var endpoint: Vector3 = p.origin + p.velocity * p.duration * 0.6
					return (endpoint - stage_origin).dot(forward) < 0.9),
					"The Axe dust centres stay on the near side of the wall over their full lifetime")
		print("AXE_GROUND_CONTACT ", surface, "/", fixture, " contact=", contact_tick, " dust=", dust_tick,
			" sound=", sound_tick, " anchor=", point)
		if obstacle != null:
			obstacle.free()
	toggle.button_pressed = false
	lab.reset_player()
	await physics_frame
	lab._select_floor_surface(0)
	lab._select_weapon(lab.Weapon.SABRE)
	await physics_frame

func check_selected_landing_surfaces(lab, dust: Node3D) -> void:
	var picker := lab.get_node_or_null("HUD/FloorSurface") as OptionButton
	if picker == null:
		check(false, "The Lab offers source grass, dirt and stone test surfaces")
		return
	var ground := lab.get_node("Ground/Mesh") as MeshInstance3D
	var ground_material := ground.material_override as ShaderMaterial
	var default_texture: Texture2DArray = ground_material.get_shader_parameter("source_terrain_tiles")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var audio: Node = lab.get_node("CombatAudio")
	for fixture in [[1, "dirt", lab.Weapon.SABRE], [2, "stone", lab.Weapon.GAUNTLETS],
			[2, "stone", lab.Weapon.BASIC_GAUNTLETS]]:
		var surface: String = fixture[1]
		lab.reset_player()
		for i in 12:
			await physics_frame
		picker.select(fixture[0])
		picker.item_selected.emit(fixture[0])
		lab._select_weapon(fixture[2])
		check(lab._equipped_weapon == fixture[2], "The surface fixture equips the correct weapon")
		var texture: Texture2DArray = ground_material.get_shader_parameter("source_terrain_tiles")
		check(texture != null and texture != default_texture
			and ground.mesh.get_aabb().size.is_equal_approx(Vector3(100.0, 1.0, 100.0)),
			"The selected source texture reuses the same 100×100 floor")
		var cue := StringName("slam_" + surface)
		var before: int = audio._next_choice.get(cue, 0)
		var grass_before: int = audio._next_choice.get(&"slam_grass", 0)
		await start_heavy_drop(lab)
		for i in 65:
			await physics_frame
			if visible_particles(dust) > 0 and audio._next_choice.get(cue, 0) != before:
				break
		var particles: Array = dust._particles.filter(func(particle): return particle.sprite.visible)
		var tint: Color = dust.SURFACE_DUST[surface]
		check(not particles.is_empty() and particles.all(func(particle):
				return Color(particle.sprite.modulate, 1.0).is_equal_approx(tint)),
			"The real E dive uses %s tint for every visible ground particle" % surface)
		check(audio._next_choice.get(cue, 0) == (before + 1) % 6
			and audio._next_choice.get(&"slam_grass", 0) == grass_before,
			"The E dive plays exactly one matching surface layer")
		print("MECHANIC_LAB_IMPACT_SURFACE ", surface, " weapon=", fixture[2], " particles=", particles.size())
	picker.select(0)
	picker.item_selected.emit(0)
	check(ground_material.get_shader_parameter("source_terrain_tiles") == default_texture,
		"Returning to grass restores the default texture object")
	toggle.button_pressed = false
	lab.reset_player()

func check_selected_floor_steps(lab) -> void:
	var menu := lab.get_node("HUD/FloorSurface") as OptionButton
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var movement: Node = lab.get_node("MovementAudio")
	var dust: MultiMeshInstance3D = lab.get_node("ZombieStepDust")
	var audio: Node = lab.get_node("CombatAudio")
	var grass_steps: int = movement.event_count.grass
	for fixture in [[1, "dirt", "sfx_player_step_carapaceDryDirt-"], [2, "stone", "sfx_player_stepStone-"]]:
		lab.reset_player()
		for i in 12:
			await physics_frame
		toggle.button_pressed = false
		menu.select(fixture[0])
		menu.item_selected.emit(fixture[0])
		var surface: String = fixture[1]
		var landing_key := "land_" + surface
		check(movement.groups.get(surface, []).size() == 6 and movement.groups.get(landing_key, []).size() == 4,
			"The selected floor loads all six step and four normal landing samples for %s" % surface)
		check(not movement.step_voices.any(func(voice): return voice.playing),
			"Changing floor while muted starts no voice")
		toggle.button_pressed = true
		var before: int = movement.event_count[surface]
		Input.action_press("move_forward")
		for i in 66:
			await physics_frame
		Input.action_release("move_forward")
		var steps: int = movement.event_count[surface] - before
		check(steps >= 3 and movement.event_count.grass == grass_steps
			and movement.last_sources.get(surface, "").begins_with(fixture[2]),
			"Real steps use the selected %s family" % surface)
		lab.reset_player()
		for i in 12:
			await physics_frame
		var landings: int = movement.event_count.landing
		var footfalls: int = movement.event_count[surface]
		check(lab.player.drop_for_lab(0.35), "The selected floor receives a normal drop")
		for i in 48:
			await physics_frame
			if movement.event_count.landing > landings:
				break
		check(movement.event_count.landing == landings + 1 and movement.event_count[surface] == footfalls
			and movement.last_sources.get(landing_key, "").begins_with("sfx_player_land_" + surface + "_"),
			"Ordinary landing uses the %s event without an extra step" % surface)
		var queued: int = audio._step_points.size()
		lab._on_zombie_step(Vector3.RIGHT)
		dust._process(0.0)
		var count := dust.multimesh.visible_instance_count
		var encoded: int = dust._puffs[0].encoded_cell if count == 1 else -1
		check(count == 1 and floori(encoded / 32.0) == fixture[0]
			and audio._step_points.size() == queued + 1,
			"Zombie feet keep the ground tint and supported generic step on %s" % surface)
		if DisplayServer.get_name() != "headless":
			check(is_equal_approx(dust.multimesh.get_instance_custom_data(0).r, encoded),
				"The rendered zombie instance receives the original surface and atlas cell")
		print("MECHANIC_LAB_FLOOR_STEPS ", surface, " steps=", steps, " dust=", count,
			" cell=", encoded, " queued=", audio._step_points.size() - queued,
			" landing=", movement.last_sources.get(landing_key, "missing"))
	dust.clear()
	var surfaces := ["grass", "dirt", "stone"]
	for i in 128:
		dust.burst(Vector3.RIGHT * i * 0.1, surfaces[i % surfaces.size()])
	dust._process(0.0)
	for i in 70:
		dust._puffs[i].lifetime = 0.0
	dust._process(0.0)
	var palette_matches := dust.multimesh.visible_instance_count == 58
	for i in dust._puffs.size():
		var puff = dust._puffs[i]
		palette_matches = (palette_matches and floori(puff.encoded_cell / 32.0) == (i + 70) % 3
			and is_equal_approx(dust._instance_buffer[i * dust.INSTANCE_FLOATS + 12], puff.encoded_cell))
		if DisplayServer.get_name() != "headless":
			palette_matches = palette_matches and is_equal_approx(
				dust.multimesh.get_instance_custom_data(i).r, puff.encoded_cell)
	check(palette_matches, "Bulk compaction preserves all 58 surviving dust cells and surface colors")
	dust.clear()
	menu.select(0)
	menu.item_selected.emit(0)
	toggle.button_pressed = false
	lab.reset_player()

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
