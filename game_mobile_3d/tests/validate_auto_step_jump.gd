extends SceneTree
## Real player/capsule fixtures: catches missing/unsafe impulses and stale jump state.
var failures: Array[String] = []
var results: Array[Dictionary] = []
var checks := 0
const PLAYER = preload("res://scenes/characters/CuboidPlayer.tscn")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func tick(count: int) -> void:
	for i in count: await physics_frame

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

func fixture(height: float = 0.0, width: float = 8.0, depth: float = 14.0, ceiling: bool = false, drop: bool = false) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	box(world, Vector3(60, 1, 60), Vector3(0, -0.5, 0))
	if height > 0:
		box(world, Vector3(width, height, depth), Vector3(0, height * 0.5, -2.0 - depth * 0.5))
	if ceiling: box(world, Vector3(8, 0.3, 15), Vector3(0, 2.25, -3))
	if drop: box(world, Vector3(8, 1, 3), Vector3(0, 0.5, -0.5))
	var player: CharacterBody3D = PLAYER.instantiate()
	world.add_child(player)
	player.position = Vector3(0, 1.02 if drop else 0.02, 0)
	player.get_node("Pistol").enabled = false
	var starts: Array[Dictionary] = []
	var lands: Array[int] = [0]
	if player.has_signal("block_jump_started"):
		player.connect("block_jump_started", func(up: bool, rise: float) -> void: starts.append({"up": up, "rise": rise}))
	if player.has_signal("block_jump_landed"):
		player.connect("block_jump_landed", func() -> void: lands[0] += 1)
	return {"world": world, "player": player, "starts": starts, "lands": lands}

func release_inputs() -> void:
	for action in ["move_forward", "move_right", "sprint"]: Input.action_release(action)

func dispose(f: Dictionary) -> void:
	release_inputs()
	f.world.queue_free()
	await tick(3)

func traverse(name: String, height: float, sprint: bool = false, width: float = 8.0, ceiling: bool = false, enabled: bool = true, diagonal: bool = false, depth: float = 14.0, usable: bool = true) -> void:
	var f := fixture(height, width, depth, ceiling)
	var p: CharacterBody3D = f.player
	if p.get("auto_step_jump_enabled") != null: p.set("auto_step_jump_enabled", enabled)
	await tick(36)
	check(f.starts.is_empty(), name + ": settling does not invent a drop")
	Input.action_press("move_forward")
	if sprint: Input.action_press("sprint")
	if diagonal: Input.action_press("move_right")
	var maximum_y := p.position.y
	var maximum_step := 0.0
	for i in 100:
		var before := p.position
		await tick(1)
		maximum_y = maxf(maximum_y, p.position.y)
		maximum_step = maxf(maximum_step, before.distance_to(p.position))
	release_inputs()
	await tick(24)
	var expected_up := enabled and height >= 0.12 and height <= 1.05 and width > 0.6 and depth > 0.6 and not ceiling and usable
	var up: Array = f.starts.filter(func(event: Dictionary) -> bool: return event.up)
	check(up.size() == (1 if expected_up else 0), name + ": correct ascent count")
	check(maximum_step < 0.25, name + ": movement uses physics without teleport")
	if expected_up:
		check(p.is_on_floor() and absf(p.position.y - height) < 0.06, name + ": reaches usable top and lands")
		check(f.lands[0] == 1, name + ": one actual landing")
		if not up.is_empty(): check(absf(up[0].rise - height) < 0.04, name + ": measured rise")
	else:
		check(maximum_y < 0.08, name + ": no unsafe/disabled hop")
		check(f.starts.is_empty() and f.lands[0] == 0, name + ": no jump events")
	results.append({"case": name, "position": str(p.position), "max_y": maximum_y, "starts": f.starts, "lands": f.lands[0]})
	await dispose(f)

func run() -> void:
	var f := fixture()
	check(f.player.has_signal("block_jump_started") and f.player.has_signal("block_jump_landed"), "Player exposes the two jump lifecycle signals")
	await tick(20)
	check(f.starts.is_empty() and f.player.is_on_floor(), "Idle floor never starts jump")
	await dispose(f)
	for height in [0.5, 1.0]:
		await traverse("walk " + str(height), height)
		await traverse("sprint " + str(height), height, true)
	await traverse("diagonal 1m", 1.0, false, 12.0, false, true, true)
	await traverse("minimum 0.12m", 0.12)
	await traverse("maximum 1.05m", 1.05)
	await traverse("flat", 0.0)
	await traverse("disabled", 1.0, false, 8.0, false, false)
	await traverse("tall wall", 1.6)
	await traverse("tree collider", 4.0, false, 0.6)
	await traverse("low ceiling", 1.0, false, 8.0, true)
	await traverse("narrow landing", 1.0, false, 0.35)
	await traverse("thin landing", 1.0, false, 8.0, false, true, false, 0.35)
	await traverse("short top walk", 1.0, false, 8.0, false, true, false, 1.0, false)
	await traverse("short top sprint", 1.0, true, 8.0, false, true, false, 1.0, false)
	for heading in [Vector3(6.25, 0, 0), Vector3(0, 0, 6.25)]:
		f = fixture(1.0)
		f.player.position.z = -0.8
		await tick(36)
		f.player.velocity = heading
		Input.action_press("move_forward")
		await tick(2)
		check(f.starts.is_empty(), "Turn/reversal never probes the off-path input heading: " + str(heading))
		await dispose(f)
	f = fixture(1.0)
	f.player.position.z = -1.65
	await tick(60)
	check(f.starts.is_empty() and f.player.is_on_floor(), "Idle against riser never hops")
	await dispose(f)
	f = fixture(1.0)
	# Low beam lies inside the forward path, away from the initial upward sweep.
	box(f.world, Vector3(4, 0.3, 0.2), Vector3(0, 0.95, -1.4))
	await tick(36)
	Input.action_press("move_forward")
	await tick(100)
	check(f.starts.is_empty(), "Low overhang inside approach corridor rejects jump")
	await dispose(f)
	f = fixture(1.0)
	await tick(36)
	Input.action_press("move_forward")
	for i in 70:
		await tick(1)
		if not f.starts.is_empty(): break
	release_inputs()
	await tick(90)
	check(f.starts.size() == 1 and f.lands[0] == 1 and f.player.is_on_floor(), "Input release in air lands once without retrigger")
	await dispose(f)
	f = fixture(0.0, 8.0, 14.0, false, true)
	await tick(36)
	Input.action_press("move_forward")
	await tick(80)
	release_inputs()
	await tick(20)
	check(f.starts.size() == 1 and not f.starts[0].up and f.lands[0] == 1 and f.player.is_on_floor(), "Walking off edge emits descent and real landing without upward jump")
	await dispose(f)
	f = fixture(0.0, 8.0, 14.0, false, true)
	if f.player.get("auto_step_jump_enabled") != null: f.player.set("auto_step_jump_enabled", false)
	await tick(36)
	Input.action_press("move_forward")
	await tick(100)
	check(f.starts.is_empty() and f.lands[0] == 0, "Disabled feature emits no descent or landing events")
	await dispose(f)
	for cancel in ["death", "teleport reset", "feature off"]:
		f = fixture(1.0)
		await tick(36)
		Input.action_press("move_forward")
		for i in 70:
			await tick(1)
			if not f.starts.is_empty(): break
		release_inputs()
		if cancel == "death": f.player.is_dead = true
		elif cancel == "teleport reset":
			f.player.position = Vector3(0, 0.02, 0)
			f.player.velocity = Vector3.ZERO
		else: f.player.auto_step_jump_enabled = false
		await tick(12)
		check(f.player.get("block_jump_active") == false, cancel + ": clears active jump state")
		check(f.player.visual.get("jump_airborne") == false and is_zero_approx(float(f.player.visual.get("jump_weight"))), cancel + ": visual overlay clears")
		await dispose(f)
	print("AUTO_STEP_JUMP " + JSON.stringify({"checks": checks, "failures": failures, "fixtures": results}))
	quit(0 if failures.is_empty() else 1)
