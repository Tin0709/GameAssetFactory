extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		Engine.physics_ticks_per_second = int(args[0])
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL ", message)

func contact(lab, delta: Vector3, serial: int, clip: String = "NativeFinisher", index: int = 2) -> float:
	var body := lab.player.get_node("BodyCollision") as CollisionShape3D
	lab._on_sabre_contact(body.global_position + delta, Vector3.RIGHT, clip, index, serial, false)
	lab._process(1.0 / 60.0)
	return lab.camera.h_offset / lab.camera.size

func run() -> void:
	var lab = load("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.set_process(false)
	await physics_frame
	if lab.get_node_or_null("CombatAudio") == null:
		check(false, "Private MD2 player is available in MechanicLab")
		lab.free()
		quit(1)
		return
	check(is_zero_approx(contact(lab, Vector3(2.4, 1.9, 0), 100)), "Raised contact outside the three-dimensional outer radius does not shake")
	check(lab._impact_light.visible, "An out-of-range shake does not suppress local contact light")
	lab.reset_player()
	var half := contact(lab, Vector3(1.8, 1.35, 0), 101)
	check(is_equal_approx(half, 0.004), "Offset along two axes measures a 2.25 m distance with half strength")
	lab.reset_player()
	check(is_equal_approx(contact(lab, Vector3(0.9, 1.2, 0), 102), 0.008), "Three-dimensional inner radius applies the full kick")
	lab.reset_player()
	lab.camera.size = 6.0
	check(is_equal_approx(contact(lab, Vector3(1.8, -1.35, 0), 103, "Attack3"), half), "Sword finisher is symmetric about the pawn and independent of zoom")
	var age: float = lab._shake_age
	contact(lab, Vector3(1.0, 0.0, 0.0), 103, "Attack3")
	check(lab._shake_age > age, "A second target in the same swing does not restart the camera pulse")
	lab.reset_player()
	check(is_zero_approx(contact(lab, Vector3(1, 0, 0), 104, "Attack2", 1)), "Sword ordinary strike has zero shake")
	check_shake_slider(lab)
	check_contact_render_hitch(lab)
	await check_sabre_dive(lab)
	if DisplayServer.get_name() != "headless":
		await check_sabre_dive_presentation(lab)
	await check_aerial_contact_pose(lab)
	lab.free()
	print("PAWN_SHAKE_RANGE failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_shake_slider(lab) -> void:
	var slider := lab.get_node_or_null("HUD/CameraShake/Slider") as HSlider
	check(slider != null and slider.is_visible_in_tree(), "Camera shake has a visible live control")
	if slider == null:
		return
	check(slider.value == 100.0, "Camera shake starts at the reference strength")
	lab.reset_player()
	slider.value = 50.0
	check(is_equal_approx(contact(lab, Vector3.RIGHT, 106, "NativeCurvedAttack3"), 0.004),
		"The 50 percent setting halves the first displayed kick")
	slider.value = 0.0
	check(is_zero_approx(lab.camera.h_offset), "Turning shake off immediately clears an active kick")
	lab.reset_player()
	check(is_zero_approx(contact(lab, Vector3.RIGHT, 107, "NativeCurvedAttack3"))
		and lab._impact_light.visible and is_equal_approx(lab._impact_light.light_energy, 2.3),
		"The zero setting keeps the camera steady and still shows the contact light")
	slider.value = 100.0
	lab.reset_player()
	check(is_equal_approx(contact(lab, Vector3.RIGHT, 108, "NativeCurvedAttack3"), 0.008),
		"Returning to full strength restores the reference kick")
	lab.reset_player()

func check_contact_render_hitch(lab) -> void:
	var offsets: Array[float] = []
	var energies: Array[float] = []
	var body := lab.player.get_node("BodyCollision") as CollisionShape3D
	for first_delta in [1.0 / 60.0, 0.22]:
		lab.reset_player()
		lab._on_sabre_contact(body.global_position + Vector3.RIGHT, Vector3.RIGHT, "Attack3", 2, 105, false)
		lab._process(first_delta)
		check(is_equal_approx(lab._impact_light.light_energy, 2.3)
			and is_equal_approx(lab.camera.h_offset / lab.camera.size, 0.008),
			"The first frame shows the full contact light and shake")
		lab._process(1.0 / 30.0)
		offsets.append(lab.camera.h_offset / lab.camera.size)
		energies.append(lab._impact_light.light_energy)
		lab._process(0.22)
		check(not lab._impact_light.visible and is_zero_approx(lab.camera.h_offset),
			"A later hitch clears both contact effects")
	check(is_equal_approx(offsets[0], offsets[1]) and offsets[1] < 0.0
		and is_equal_approx(energies[0], energies[1]) and energies[1] > 0.0 and energies[1] < 2.3,
		"Light decay and camera reversal follow elapsed time after the first displayed frame")
	lab.reset_player()

func check_sabre_dive(lab) -> void:
	var landings: Array[int] = []
	lab.player.heavy_jump_landed.connect(func(_point, _forward, _serial, _height):
		landings.append(Engine.get_physics_frames()))
	for attempt in 4:
		lab.reset_player()
		for i in 8:
			await physics_frame
		var target: CharacterBody3D
		var target_hits: Array[int] = []
		if attempt == 3:
			lab.get_node("HUD/SpawnZombie").pressed.emit()
			target = lab.get_node("Zombies").get_child(0)
			target.set_physics_process(false)
			target.collision_layer = 0
			target.global_position = lab.player.global_position + lab.player.visual.global_basis.z * 1.5
			lab.get_node("Zombies").sabre_contact.connect(func(_point, _direction, _clip, _index, _serial, _lethal):
				target_hits.append(Engine.get_physics_frames()))
		await start_sabre_dive(lab)
		for i in Engine.physics_ticks_per_second:
			await physics_frame
			if landings.size() > attempt:
				break
		check(landings.size() == attempt + 1, "A real Sabre dive lands on the empty floor")
		if landings.size() != attempt + 1:
			return
		check(lab._shake_duration == 0.0, "Touchdown leaves the camera stable until the montage cue")
		check(not lab._impact_light.visible and not lab.player.effects.particles.any(func(particle): return particle.life > 0.0),
			"Sabre touchdown waits for the montage before showing the impact burst")
		if attempt == 1:
			lab.reset_player()
		elif attempt == 2:
			lab._on_player_hit(100)
		var onset := -1
		var flash_frame := -1
		var burst_frame := -1
		var sampled_kick := 0.0
		for i in 16:
			await physics_frame
			var frame := Engine.get_physics_frames() - 1
			if lab._shake_duration > 0.0 and onset < 0:
				onset = frame
				lab.player.render_presenter.prepare(1.0)
				lab._process(0.0)
				sampled_kick = lab.camera.h_offset / lab.camera.size
			if lab._light_sample_time >= 0.0 and flash_frame < 0:
				flash_frame = frame
			if burst_frame < 0 and lab.player.effects.particles.any(func(particle): return particle.life > 0.0):
				burst_frame = frame
		if attempt in [1, 2]:
			check(onset < 0 and flash_frame < 0 and burst_frame < 0 and is_zero_approx(lab.camera.h_offset),
				"Reset and defeat discard the queued aerial shake, flash and burst")
			continue
		var flash_delay := ceili(0.056890413 * Engine.physics_ticks_per_second)
		check(flash_frame == landings[attempt] + flash_delay and burst_frame == flash_frame,
			"The aerial light and sparks are sampled at the authored one-shot VFX key")
		var delay := ceili(0.052268848 * Engine.physics_ticks_per_second)
		check(onset == landings[attempt] + delay and is_equal_approx(sampled_kick, 0.008),
			"The Sabre camera pulse reaches its full kick at the sampled montage cue")
		if target != null:
			var damage_delay := ceili(0.054369554 * Engine.physics_ticks_per_second)
			check(target_hits == [landings[attempt] + damage_delay] and target.health == 8
				and is_equal_approx(lab._impact_light.light_energy, 2.3),
				"Target damage keeps its own key and cannot replace the landing flash")
			target.free()
		print("SABRE_DIVE_SHAKE touchdown=", landings[attempt], " onset=", onset, " flash=", flash_frame, " burst=", burst_frame)

func start_sabre_dive(lab) -> void:
	lab.get_node("HUD/DropMedium").pressed.emit()
	for i in 2:
		await physics_frame
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	root.push_input(event, true)
	for i in 2:
		await physics_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	root.push_input(event, true)

func check_aerial_contact_pose(lab) -> void:
	lab.set_process(false)
	var group: Node = lab.get_node("Zombies")
	var sparks = lab.get_node("ContactSparks")
	sparks.process_mode = Node.PROCESS_MODE_DISABLED
	for slot: int in [lab.Weapon.SABRE, lab.Weapon.SWORD, lab.Weapon.AXE]:
		lab.reset_player()
		for i in 8:
			await physics_frame
		lab._select_weapon(slot)
		check(lab._equipped_weapon == slot, "The aerial contact test equips slot %d" % slot)
		lab.get_node("HUD/SpawnZombie").pressed.emit()
		var forward: Vector3 = lab.player.visual.global_basis.z
		var target = group.get_child(0)
		target.set_physics_process(false)
		target.collision_layer = 0
		target.global_position = lab.player.global_position + forward * 1.5
		var contacts: Array[Vector3] = []
		group.sabre_contact.connect(func(point, _direction, _clip, _index, _serial, _lethal):
			contacts.append(point), CONNECT_ONE_SHOT)
		var landings: Array[Vector3] = []
		group.sabre_landing.connect(func(point, _serial): landings.append(point), CONNECT_ONE_SHOT)
		await start_sabre_dive(lab)
		for i in Engine.physics_ticks_per_second:
			await physics_frame
			if not contacts.is_empty():
				break
		check(contacts.size() == 1, "The aerial attack hits one target in slot %d" % slot)
		if not contacts.is_empty():
			var clock: float = lab.player.effects.clock
			lab.player.render_presenter.prepare(0.0)
			sparks._process(0.0)
			lab._process(0.0)
			var early_count: int = sparks._streaks.visible_instance_count
			check(early_count == 0, "Aerial body sparks wait for the contact pose in slot %d" % slot)
			if slot != lab.Weapon.SABRE:
				check(not lab._impact_light.visible, "The landing light waits for the contact pose in slot %d" % slot)
				check(is_equal_approx(lab._light_sample_time, clock),
					"The landing light uses the current physics pose in slot %d" % slot)
				check(landings.size() == 1, "The weapon reports one floor contact in slot %d" % slot)
				if landings.size() == 1:
					var floor_count := 0
					var floor_point := landings[0] + Vector3.UP * 0.12
					for i in lab.player.effects.particles.size():
						var particle: Dictionary = lab.player.effects.particles[i]
						if is_equal_approx(particle.born, clock) and floor_point.is_equal_approx(particle.position):
							floor_count += 1
							check(lab.player.effects.particle_at(i, lab.player.render_presenter.display_clock).life == 0.0
								and lab.player.effects.particle_at(i, clock).life > 0.0,
								"A floor particle appears first on the contact pose")
					check(floor_count == 8, "One floor burst starts on the contact pose in slot %d" % slot)
			lab.player.render_presenter.prepare(1.0)
			sparks._process(0.0)
			lab._process(0.0)
			check(sparks._streaks.visible_instance_count == 9, "One body burst starts on the contact pose in slot %d" % slot)
			for spark in sparks._particles:
				if spark.age < spark.lifetime:
					check(is_equal_approx(spark.origin.distance_to(contacts[0]), 0.21), "Body sparks start at their struck target")
			if slot != lab.Weapon.SABRE:
				check(lab._impact_light.visible and is_equal_approx(lab._impact_light.light_energy, 2.3),
					"The floor flash keeps priority over the body flash at full intensity in slot %d" % slot)
			print("AERIAL_CONTACT_POSE slot=", slot, " early_streaks=", early_count,
				" on_pose_streaks=", sparks._streaks.visible_instance_count)
		target.free()
		if contacts.is_empty():
			break

func check_sabre_dive_presentation(lab) -> void:
	lab.reset_player()
	lab.set_process(true)
	var landing: Array[int] = []
	var first_draw := {}
	lab.player.heavy_jump_landed.connect(func(_point, _forward, _serial, _height):
		landing.append(Engine.get_physics_frames()), CONNECT_ONE_SHOT)
	var sample := func():
		if landing.is_empty():
			return
		var render_tick := Engine.get_physics_frames() + Engine.get_physics_interpolation_fraction() - 1.0
		var elapsed := render_tick - landing[0]
		if not first_draw.has("camera") and not is_zero_approx(lab.camera.h_offset):
			first_draw.camera = elapsed
			first_draw.kick = lab.camera.h_offset / lab.camera.size
		var light: OmniLight3D = lab._impact_light
		if not first_draw.has("light") and light.is_visible_in_tree() and light.light_energy > 0.0:
			first_draw.light = elapsed
		if first_draw.has("sparks"):
			return
		var sparks: MultiMesh = lab.player.effects.sparks.multimesh
		for i in sparks.instance_count:
			if sparks.get_instance_color(i).a > 0.001 and sparks.get_instance_transform(i).origin.y < 0.45:
				first_draw.sparks = elapsed
				break
	RenderingServer.frame_pre_draw.connect(sample)
	for i in 8:
		await physics_frame
	await start_sabre_dive(lab)
	for i in Engine.physics_ticks_per_second:
		await physics_frame
		if first_draw.size() == 4:
			break
	RenderingServer.frame_pre_draw.disconnect(sample)
	var cue := ceili(0.056890413 * Engine.physics_ticks_per_second)
	check(first_draw.get("light", -1.0) >= cue - 0.000001
		and is_equal_approx(first_draw.get("light", -1.0), first_draw.get("sparks", -2.0)),
		"The rendered floor flash and sparks start together on or after the authored pose")
	var shake_cue := ceili(0.052268848 * Engine.physics_ticks_per_second)
	check(first_draw.get("camera", -1.0) >= shake_cue - 0.000001
		and is_equal_approx(first_draw.get("kick", 0.0), 0.008),
		"The displayed camera waits for its authored pose and begins at full strength")
	await create_timer(0.25).timeout
	check(is_zero_approx(lab.camera.h_offset), "The displayed pulse settles back to the original camera offset")
	print("SABRE_DIVE_FIRST_DRAW cue=", cue, " draw=", first_draw)
