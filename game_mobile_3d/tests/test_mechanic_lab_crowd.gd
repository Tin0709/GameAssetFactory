extends SceneTree

const LAB = preload("res://scenes/dev/MechanicLab.tscn")
const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")
const COUNT := 100
var lab: Node3D
var tick_started := 0
var frame_started := 0
var physics_ms: Array[float] = []
var frame_ms: Array[float] = []
var render_gpu_ms: Array[float] = []
var draws: Array[float] = []
var active_peak := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	lab = LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	root.size = Vector2i(960, 540)
	root.msaa_3d = Viewport.MSAA_DISABLED
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	physics_frame.connect(func(): tick_started = Time.get_ticks_usec())
	process_frame.connect(func():
		var now := Time.get_ticks_usec()
		if frame_started > 0:
			frame_ms.append((now - frame_started) / 1000.0)
			if tick_started > frame_started:
				physics_ms.append((now - tick_started) / 1000.0)
		frame_started = now
		render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	await measure("empty", 90)
	var group := lab.get_node("Zombies")
	var spawn := lab.get_node("HUD/SpawnZombie") as Button
	var cold := Time.get_ticks_usec()
	var spawn_us: Array[float] = []
	for i in COUNT:
		var start := Time.get_ticks_usec()
		spawn.pressed.emit()
		spawn_us.append((Time.get_ticks_usec() - start) / 1000.0)
	if group.get_child_count() != COUNT:
		printerr("Could not spawn all ", COUNT, " zombies")
		quit(1)
		return
	check_spawn_spacing(group)
	print("CROWD_SPAWN ", JSON.stringify({"count": COUNT, "burst_ms": (Time.get_ticks_usec() - cold) / 1000.0,
		"per_spawn_ms": stats(spawn_us), "first_ms": spawn_us[0],
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}))
	await measure("spawn_animation", 70)
	Input.action_press("move_backward")
	await measure("chase", 120)
	Input.action_release("move_backward")
	# Give each corpse clear room to complete its authored handoff and roll.
	for i in COUNT:
		var zombie = group.get_child(i)
		zombie.global_position = Vector3(i % 10 * 4.0 - 18.0, 0.02, int(i / 10) * 4.0 - 18.0)
		zombie.velocity = Vector3.ZERO
		zombie.reset_physics_interpolation()
		zombie.take_hit(100, Vector3.RIGHT, Vector2.ZERO, 0.0, 1150.0, ZOMBIE.DeathStrike.SABRE_FINISHER)
	await measure("simultaneous_ragdolls", 120, group)
	if active_peak != COUNT:
		failures.append("Expected all 100 ragdolls to run together")
	await measure("corpse_cleanup", 200, group)
	var clean := group.get_child_count() == 0
	if not clean:
		failures.append("Corpses remain after the cleanup window")
	print("CROWD_END failures=", failures, " renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name())
	lab.free()
	quit(0 if failures.is_empty() else 1)

func check_spawn_spacing(group: Node) -> void:
	var zombies := group.get_children()
	for i in zombies.size():
		var point: Vector3 = zombies[i].position
		if absf(point.x) > 49.0 or absf(point.z) > 49.0:
			failures.append("Zombie spawned outside the lab bounds")
			return
		for j in i:
			if point.distance_squared_to(zombies[j].position) < 1.25 * 1.25:
				failures.append("Zombie spawn positions overlap the 1.25 m spacing")
				return

func measure(label: String, ticks: int, group: Node = null) -> void:
	frame_ms.clear()
	physics_ms.clear()
	render_gpu_ms.clear()
	draws.clear()
	active_peak = 0
	for i in ticks:
		await physics_frame
		if group != null:
			var active := 0
			for zombie in group.get_children():
				if zombie.ragdoll.running:
					active += 1
			active_peak = maxi(active_peak, active)
	print("CROWD_PHASE ", JSON.stringify({"phase": label, "frame_ms": stats(frame_ms),
		"physics_to_process_ms": stats(physics_ms), "gpu_ms": stats(render_gpu_ms),
		"draws": stats(draws), "samples": frame_ms.size(), "active_ragdolls_peak": active_peak}))

func stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {}
	var sorted := samples.duplicate()
	sorted.sort()
	return {"p50": sorted[sorted.size() / 2], "p95": sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)],
		"max": sorted.back()}
