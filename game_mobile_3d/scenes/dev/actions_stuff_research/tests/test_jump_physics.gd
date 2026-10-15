extends SceneTree
## Real capsule collisions catch absent launch, timeline landing, and lost air control.
const ACTOR_PATH := "res://scenes/dev/actions_stuff_research/source_jump_actor.gd"
const PLAYER := preload("res://scenes/dev/ExpressiveLocomotionPlayer.tscn")
const VISUAL := preload("res://scenes/dev/actions_stuff_research/walk_run_visual.gd")
var failures: Array[String] = []
var reports: Array = []
var actor: CharacterBody3D
var floor_body: StaticBody3D
var fps := 30

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func tick() -> void:
	await physics_frame
	await process_frame

func query() -> Dictionary:
	return actor.get("last_jump_query") if actor.get("last_jump_query") != null else {}

func run() -> void:
	fps = 60 if OS.get_cmdline_user_args().has("60") else 30
	Engine.physics_ticks_per_second = fps
	var world := Node3D.new()
	root.add_child(world)
	floor_body = StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, .2, 200)
	collider.shape = shape
	collider.position.y = -.1
	floor_body.add_child(collider)
	world.add_child(floor_body)
	actor = PLAYER.instantiate()
	var available := FileAccess.file_exists(ACTOR_PATH)
	if available:
		actor.set_script(load(ACTOR_PATH))
	actor.get_node("Visual").set_script(VISUAL)
	actor.review_pace = 1.
	actor.walk_speed = 1.8
	actor.run_speed = 5.031
	actor.acceleration = 32.
	actor.deceleration = 28.
	actor.scripted_input = true
	world.add_child(actor)
	for i in 4:
		await tick()
	check(actor.is_on_floor(), "Capsule establishes actual floor contact")
	check(not query().get("landed", false), "Initial floor acquisition is not a Jump landing")
	for mode in ["stand", "walk", "run"]:
		actor.requested_direction = Vector2.ZERO if mode == "stand" else Vector2(0, -1)
		actor.requested_run = mode == "run"
		for i in int(.4 * fps):
			await tick()
		if available:
			actor.requested_jump = true
		var peak := actor.position.y
		var takeoffs := 0
		var landings := 0
		var saw_air := false
		var impact := 0.
		var takeoff_speed := 0.
		var reverse_speed := 0.
		for i in int(1.65 * fps):
			await tick()
			var q := query()
			if q.get("takeoff", false):
				takeoffs += 1
				takeoff_speed = actor.velocity.y
			if q.get("landed", false):
				landings += 1
				impact = q.impact_velocity
				check(actor.is_on_floor(), mode + " landing event requires actual collision")
				check(absf(q.vertical_speed) < .001, mode + " grounded source query has zero vertical speed")
			saw_air = saw_air or not actor.is_on_floor()
			peak = maxf(peak, actor.position.y)
			if mode != "stand" and i == int(.18 * fps):
				actor.requested_direction = Vector2(0, 1)
			if mode != "stand" and i == int(.4 * fps):
				reverse_speed = actor.velocity.z
		check(takeoffs == 1, mode + " held jump launches exactly once")
		check(landings == 1, mode + " produces exactly one collision landing")
		check(saw_air and peak > .9 and peak < 1.3, mode + " capsule follows gravity with 1.2m nominal height")
		check(takeoff_speed > 6.5 and takeoff_speed < 6.6, mode + " launch uses gravity-derived impulse")
		check(impact < -5., mode + " collision preserves downward impact velocity")
		check(actor.is_on_floor(), mode + " capsule returns to floor")
		if mode != "stand":
			check(reverse_speed > 1., mode + " opposite input changes velocity during air")
		reports.append({"mode": mode, "takeoffs": takeoffs, "landings": landings, "peak_m": peak, "impact_velocity": impact, "air_reverse_speed": reverse_speed})
		if available:
			actor.requested_jump = false
		await tick()
	# A raised collision surface must terminate flight before its nominal floor arc.
	if available:
		actor.requested_direction = Vector2.ZERO
		actor.requested_jump = true
		for i in int(.4 * fps):
			await tick()
		floor_body.position.y = .5
		var raised_landing := false
		for i in int(.7 * fps):
			await tick()
			if query().get("landed", false):
				raised_landing = true
				check(absf(actor.position.y - .5) < .015, "Raised floor landing follows collision height")
		check(raised_landing and actor.is_on_floor(), "Raised floor triggers actual early landing")
		actor.reset_jump_motion()
		check(not query().get("takeoff", false) and not query().get("landed", false), "Reset clears transient jump events")
	print("JUMP_PHYSICS ", JSON.stringify({"fps": fps, "failures": failures, "trials": reports}))
	world.free()
	quit(0 if failures.is_empty() else 1)
