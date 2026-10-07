extends SceneTree
## Exercise history through the actual production controller, especially reversals.
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("GRASSLAND MOTION: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level = load("res://scenes/Grassland.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player = level.get_node("Actors/Player")
	for i in range(8): await physics_frame
	# At the real controller's first negative velocity frame, a new segment must
	# attack from zero while the previously traversed segment keeps its endpoint.
	Input.action_press("move_right")
	for i in range(60): await physics_frame
	Input.action_release("move_right")
	Input.action_press("move_left")
	var saw_reversal := false
	for i in range(20):
		var before: Array = level.motion.samples.duplicate(true)
		await physics_frame
		if before.is_empty() or level.motion.samples.is_empty(): continue
		var old: Dictionary = before.back()
		var old_direction: Vector2 = old.end - old.start
		if player.velocity.x < -0.1 and old_direction.x > 0.0:
			saw_reversal = true
			var preserved := false
			for sample in level.motion.samples:
				if sample.born == old.born:
					preserved = sample.end == old.end and sample.last == old.last
			check(preserved, "Reversal preserves the previous path instead of flipping its aged direction")
			if level.motion.samples.back().born != old.born:
				check(level.motion.starts[level.motion.active_count - 1].z < 0.04, "Fresh reversal sample starts with a smooth attack")
	check(saw_reversal, "Real walking controller crosses direction during the checked interval")
	Input.action_release("move_left")
	for i in range(100): await physics_frame
	check(level.motion.active_count == 0, "Stopped player leaves no persistent disturbance")
	# Direct provider stress: rapid turns cannot evict a still-recovering trail.
	var motion = load("res://scripts/grassland_motion.gd").new()
	var point := Vector3.ZERO
	motion.advance(0, point, Vector3.ZERO, 4.25, 6.25)
	var touched: Dictionary = {}
	for i in range(80):
		var velocity := Vector3(4.25 if i % 2 == 0 else -4.25, 0, 0)
		point += velocity / 60.0
		for sample in motion.samples: touched[sample.born] = sample.duplicate(true)
		motion.advance(1.0 / 60.0, point, velocity, 4.25, 6.25)
		for born in touched:
			var existing := false
			for sample in motion.samples:
				if sample.born == born: existing = true
			if not existing:
				check(motion.clock - float(touched[born].last) >= 0.7999, "History saturation only retires already-recovered samples")
		check(motion.active_count <= 8, "Rapid-turn history remains bounded")
	var report := {"checks": checks, "failures": failures}
	FileAccess.open("res://.validation/grassland_motion.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
