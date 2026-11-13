extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var lab := preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	var sun := lab.get_node("Sun") as DirectionalLight3D
	var environment: Environment = lab.get_node("WorldEnvironment").environment
	var noon := [sun.basis, sun.light_color, sun.light_energy, environment.ambient_light_color,
		environment.ambient_light_energy, environment.background_color]
	var label := lab.get_node_or_null("HUD/TimeOfDay") as Label
	check(label != null and label.text.contains("12:00"), "Lab displays the Noon starting hour")
	for hour: String in ["16:30", "22:00", "07:00", "12:00"]:
		press_time(false)
		await process_frame
		check(label != null and label.text.contains(hour), "T changes the hour to " + hour)
		if hour == "22:00":
			check(sun.light_energy < float(noon[2]) and not sun.basis.is_equal_approx(noon[0]), "Night changes the key light and direction")
			press_time(true)
			check(label != null and label.text.contains(hour), "Holding T does not skip phases")
	check(sun.basis.is_equal_approx(noon[0]) and noon.slice(1) == [sun.light_color, sun.light_energy,
		environment.ambient_light_color, environment.ambient_light_energy, environment.background_color],
		"Cycling restores the Noon lighting")
	var floor_shape := lab.get_node("Ground/Collision").shape as BoxShape3D
	check(floor_shape.size == Vector3(100.0, 1.0, 100.0), "The lab keeps its flat 100 × 100 collision floor")
	lab.free()
	print("MECHANIC_LAB_LIGHTING failures=", failures)
	quit(0 if failures.is_empty() else 1)

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
