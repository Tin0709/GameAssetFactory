extends SceneTree
## Real capsule/player fixtures: detects ballistic overshoot and unsafe/stale climbs.
const PLAYER = preload("res://scenes/characters/CuboidPlayer.tscn")
var failures: Array[String] = []
var results: Array[Dictionary] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func tick(count: int) -> void:
	for i in count: await physics_frame

func release_inputs() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint"]: Input.action_release(action)

func box(parent: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = position

func fixture(height := 0.0, width := 8.0, depth := 14.0, ceiling := false, drop := false) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	box(world, Vector3(60, 1, 60), Vector3(0, -0.5, 0))
	if height > 0: box(world, Vector3(width, height, depth), Vector3(0, height / 2.0, -2.0 - depth / 2.0))
	if ceiling: box(world, Vector3(8, 0.3, 15), Vector3(0, 2.25, -3))
	if drop: box(world, Vector3(8, 1, 3), Vector3(0, 0.5, -0.5))
	var player: CharacterBody3D = PLAYER.instantiate()
	world.add_child(player)
	player.position = Vector3(0, 1.02 if drop else 0.02, 0)
	player.get_node("Pistol").enabled = false
	return {"world": world, "player": player}

func dispose(f: Dictionary) -> void:
	release_inputs()
	f.world.queue_free()
	await tick(3)

func active(player: CharacterBody3D) -> bool:
	return player.get("smooth_step_active") == true

func forest_terraces() -> void:
	var level := load("res://scenes/ForestQualitySlice.tscn").instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	level.set_enemies_enabled(false)
	var p: CharacterBody3D = level.player
	p.get_node("Pistol").enabled = false
	# Existing real terrain, not extra boxes: x=10 avoids masonry/tree trunks.
	# Each forward route crosses a .5m vertical face in the concave terrace mesh.
	for route in [{"start": Vector3(10, 1.02, -2), "top": 1.5}, {"start": Vector3(10, 1.52, -5), "top": 2.0}]:
		p.global_position = route.start
		p.velocity = Vector3.ZERO
		await tick(36)
		var max_y := p.position.y
		var max_dy := 0.0
		var starts := 0
		var was_active := false
		Input.action_press("move_forward")
		for i in 58:
			var before := p.position.y
			await tick(1)
			max_y = maxf(max_y, p.position.y)
			max_dy = maxf(max_dy, p.position.y - before)
			if active(p) and not was_active: starts += 1
			was_active = active(p)
		release_inputs()
		await tick(30)
		check(starts == 1 and p.is_on_floor() and absf(p.position.y - float(route.top)) < 0.04, "Real forest concave terrace reaches top: " + str(route.start))
		check(max_y <= float(route.top) + 0.04 and max_dy < 0.10 and not active(p), "Real forest terrace ascent stays bounded")
		results.append({"case": "forest concave " + str(route.start), "position": str(p.position), "max_y": max_y, "max_dy": max_dy, "starts": starts})
	level.set_enemies_enabled(false)
	level.queue_free()
	await tick(4)

func traverse(name: String, height: float, allowed: bool, sprint := false, diagonal := false, width := 8.0, depth := 14.0, ceiling := false, enabled := true) -> void:
	var f := fixture(height, width, depth, ceiling)
	var p: CharacterBody3D = f.player
	if p.get("smooth_step_up_enabled") != null: p.set("smooth_step_up_enabled", enabled)
	await tick(36)
	var base_y := p.position.y
	var max_y := base_y
	var max_dy := 0.0
	var max_step := 0.0
	var starts := 0
	var was_active := false
	Input.action_press("move_forward")
	if sprint: Input.action_press("sprint")
	if diagonal: Input.action_press("move_right")
	for i in 100:
		var before := p.position
		await tick(1)
		max_y = maxf(max_y, p.position.y)
		max_dy = maxf(max_dy, p.position.y - before.y)
		max_step = maxf(max_step, p.position.distance_to(before))
		if active(p) and not was_active: starts += 1
		was_active = active(p)
	release_inputs()
	await tick(30)
	check(starts == (1 if allowed else 0), name + ": controlled ascent count")
	check(max_dy < 0.10 and max_step < 0.20, name + ": bounded continuous body movement")
	check(max_y <= height + 0.04 if allowed else max_y <= base_y + 0.04, name + ": no ballistic apex or unsafe ascent")
	check(not active(p), name + ": no stale ascent state")
	if allowed: check(p.is_on_floor() and absf(p.position.y - height) < 0.04, name + ": walks onto top and returns to floor")
	results.append({"case": name, "position": str(p.position), "max_y": max_y, "max_dy": max_dy, "starts": starts})
	await dispose(f)

func run() -> void:
	var f := fixture(1.0)
	check(f.player.get("smooth_step_up_enabled") == true, "Smooth step up is enabled by default")
	await tick(60)
	check(not active(f.player) and absf(f.player.position.y) < 0.04, "Idle near a ledge stays on floor")
	await dispose(f)
	for height in [0.5, 1.0]:
		await traverse("walk " + str(height), height, true)
		await traverse("sprint " + str(height), height, true, true)
	await traverse("diagonal", 1.0, true, false, true, 12.0)
	await traverse("minimum", 0.12, true)
	await traverse("maximum", 1.05, true)
	await traverse("flat", 0.0, false)
	await traverse("disabled", 1.0, false, false, false, 8.0, 14.0, false, false)
	await traverse("tall wall", 1.6, false)
	await traverse("tree", 4.0, false, false, false, 0.6)
	await traverse("low ceiling", 1.0, false, false, false, 8.0, 14.0, true)
	await traverse("narrow top", 1.0, false, false, false, 0.35)
	await traverse("thin top", 1.0, false, false, false, 8.0, 0.35)
	for heading in [Vector3(6.25, 0, 0), Vector3(0, 0, 6.25)]:
		f = fixture(1.0)
		f.player.position.z = -1.55
		await tick(36)
		f.player.velocity = heading
		Input.action_press("move_forward")
		await tick(2)
		check(not active(f.player) and f.player.position.y < 0.04, "Turn/reversal does not climb along off-path input: " + str(heading))
		await dispose(f)
	for cancel in ["release", "reversal", "steer", "analog steer", "death", "reset", "off"]:
		f = fixture(1.0, 0.7 if cancel == "analog steer" else (0.8 if cancel == "steer" else 8.0))
		await tick(36)
		Input.action_press("move_forward")
		for i in 80:
			await tick(1)
			if active(f.player) and f.player.position.y > 0.10: break
		check(active(f.player), cancel + ": fixture enters controlled ascent")
		release_inputs()
		if cancel == "reversal": Input.action_press("move_backward")
		elif cancel == "steer":
			Input.action_press("move_forward")
			Input.action_press("move_right")
		elif cancel == "analog steer":
			Input.action_press("move_forward")
			Input.action_press("move_right", 0.25)
		elif cancel == "death": f.player.is_dead = true
		elif cancel == "reset":
			f.player.position = Vector3(0, 0.02, 0)
			f.player.velocity = Vector3.ZERO
		elif cancel == "off" and f.player.get("smooth_step_up_enabled") != null: f.player.smooth_step_up_enabled = false
		var cancel_y: float = f.player.position.y
		# Small analog steering needs several frames to exceed this top's .025m
		# lateral support margin, while remaining below the direction guard.
		await tick(8 if cancel == "analog steer" else 4)
		check(not active(f.player), cancel + ": cancels climb")
		if cancel == "analog steer":
			var stopped_y: float = f.player.position.y
			await tick(3)
			check(f.player.position.y <= stopped_y + 0.01, cancel + ": unsupported ascent stops raising body")
		else:
			check(f.player.position.y <= cancel_y + 0.04, cancel + ": removes controlled upward velocity")
		await tick(90)
		if cancel != "death": check(f.player.is_on_floor(), cancel + ": normal floor/gravity resumes")
		await dispose(f)
	# Feature must not alter a normal walking descent.
	for enabled in [true, false]:
		f = fixture(0.0, 8.0, 14.0, false, true)
		if f.player.get("smooth_step_up_enabled") != null: f.player.smooth_step_up_enabled = enabled
		await tick(36)
		Input.action_press("move_forward")
		await tick(80)
		release_inputs()
		await tick(30)
		check(not active(f.player) and f.player.is_on_floor() and absf(f.player.position.y) < 0.04, "Walking descent unchanged, enabled=" + str(enabled))
		await dispose(f)
	await forest_terraces()
	var report := {"checks": checks, "failures": failures, "fixtures": results}
	DirAccess.make_dir_recursive_absolute("res://.validation/smooth_step_up")
	FileAccess.open("res://.validation/smooth_step_up/physics_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("SMOOTH_STEP_UP " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
