extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var lab := preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await settle()
	var sun := lab.get_node("Sun") as DirectionalLight3D
	var environment: Environment = lab.get_node("WorldEnvironment").environment
	var noon := [sun.basis, sun.light_color, sun.light_energy, environment.ambient_light_color,
		environment.ambient_light_energy, environment.background_color]
	var label := lab.get_node_or_null("HUD/TimeOfDay") as Label
	check(label != null and label.text.contains("12:00"), "Lab displays the Noon starting hour")
	for hour: String in ["16:30", "18:30", "19:30", "22:00", "02:30", "07:00", "12:00"]:
		press_time(false)
		await settle()
		check(label != null and label.text.contains(hour), "T changes the hour to " + hour)
		if hour == "16:30" and lab.showcase.forest_active():
			check(lab.showcase.projected_sun._weight > 0.0,
				"Afternoon uses the WorldMap projected sunlight when the private mask is present")
		if hour == "22:00":
			check(sun.light_energy < float(noon[2]) and not sun.basis.is_equal_approx(noon[0]), "Night changes the key light and direction")
			press_time(true)
			check(label != null and label.text.contains(hour), "Holding T does not skip phases")
			if lab.showcase.forest_active():
				check(lab.showcase.mist.effect.snapshot().ready and lab.showcase.phase_finish.active,
					"Night enables the same spatial mist and phase finishing as WorldMap")
		if hour == "02:30" and lab.showcase.forest_active() and lab.showcase.sky_response.available():
			var ground := lab.get_node("Ground/Mesh").material_override as ShaderMaterial
			check(lab.showcase._dawn_turf_color > 0.0 and ground.shader.code.contains("#define GAF_WORLD_FLAT_TURF"),
				"Dawn applies the WorldMap turf color to the flat grass blocks")
	check(sun.basis.is_equal_approx(noon[0]) and noon.slice(1) == [sun.light_color, sun.light_energy,
		environment.ambient_light_color, environment.ambient_light_energy, environment.background_color],
		"Cycling restores the Noon lighting")
	var floor_shape := lab.get_node("Ground/Collision").shape as BoxShape3D
	check(floor_shape.size == Vector3(100.0, 1.0, 100.0), "The lab keeps its flat 100 × 100 collision floor")
	check(lab.showcase.projected_sun._weight == 0.0 and lab.showcase._dawn_turf_color == 0.0,
		"Noon restores the neutral sunlight projection and turf color")
	lab.free()
	print("MECHANIC_LAB_LIGHTING failures=", failures)
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for i in 24:
		await process_frame

func press_time(echo: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_T
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	if not echo:
		var release := InputEventKey.new()
		release.physical_keycode = KEY_T
		root.push_input(release, true)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)
