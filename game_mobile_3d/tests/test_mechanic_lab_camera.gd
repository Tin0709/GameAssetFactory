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
	check_contact_render_hitch(lab)
	await check_sabre_dive(lab)
	lab.free()
	print("PAWN_SHAKE_RANGE failures=", failures)
	quit(0 if failures.is_empty() else 1)

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
		for i in 16:
			await physics_frame
			var frame := Engine.get_physics_frames() - 1
			if lab._shake_duration > 0.0 and onset < 0:
				onset = frame
			if lab._impact_light.visible and flash_frame < 0:
				flash_frame = frame
			if burst_frame < 0 and lab.player.effects.particles.any(func(particle): return particle.life > 0.0):
				burst_frame = frame
		if attempt in [1, 2]:
			check(onset < 0 and flash_frame < 0 and burst_frame < 0 and is_zero_approx(lab.camera.h_offset),
				"Reset and defeat discard the queued aerial shake, flash and burst")
			continue
		var flash_delay := ceili(0.056890413 * Engine.physics_ticks_per_second)
		check(flash_frame == landings[attempt] + flash_delay and burst_frame == flash_frame,
			"The aerial light and sparks share the authored one-shot VFX key")
		var delay := ceili(0.052268848 * Engine.physics_ticks_per_second)
		check(onset == landings[attempt] + delay, "The Sabre camera pulse starts at its montage cue")
		if target != null:
			var damage_delay := ceili(0.054369554 * Engine.physics_ticks_per_second)
			check(target_hits == [landings[attempt] + damage_delay] and target.health == 8
				and is_equal_approx(lab._impact_light.light_energy, 2.3),
				"Target damage keeps its own key and cannot replace the landing flash")
			target.free()
		lab._process(1.0 / 60.0)
		check(not is_zero_approx(lab.camera.h_offset), "The aerial cue moves the actual camera")
		for i in 15:
			lab._process(1.0 / 60.0)
		check(is_zero_approx(lab.camera.h_offset), "The pulse settles back to the original camera offset")
		print("SABRE_DIVE_SHAKE touchdown=", landings[attempt], " onset=", onset, " flash=", flash_frame, " burst=", burst_frame)
