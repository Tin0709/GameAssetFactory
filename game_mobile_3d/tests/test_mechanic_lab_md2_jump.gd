
extends SceneTree

const LAB = preload("res://scenes/dev/MechanicLab.tscn")
const SOURCE_ACTOR = preload("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
var failures: Array[String] = []
var checks := 0
var moving_resume_seconds := {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func tick() -> void:
	await physics_frame

func wait_clip(actor, clip: String, ticks: int) -> bool:
	for i in ticks:
		await tick()
		if actor.active_clip == clip:
			return true
	return false

func pose_error(actor, oracle) -> float:
	var worst := 0.0
	for bone in actor.skeleton.get_bone_count():
		var live: Transform3D = actor.skeleton.get_bone_pose(bone)
		var source: Transform3D = oracle.skeleton.get_bone_pose(bone)
		worst = maxf(worst, live.origin.distance_to(source.origin))
		for axis in 3:
			worst = maxf(worst, live.basis[axis].distance_to(source.basis[axis]))
	return worst

func compare_source(actor, oracle, key: String, label: String) -> void:
	check(actor.active_clip == key, label + " selects " + key)
	if actor.active_clip != key:
		return
	oracle.review(key)
	oracle.animation_player.seek(actor.animation_player.current_animation_position, true)
	check(not actor.hybrid_motion.owns_pose and pose_error(actor, oracle) < 0.00005,
		label + " preserves the full source pose outside the handoff")

func run() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	var actor = lab.player
	var oracle = SOURCE_ACTOR.new()
	root.add_child(oracle)
	oracle.set_physics_process(false)
	if not actor.primary_ready or not oracle.using_original_source:
		check(false, "Private source player is available")
		quit(1)
		return
	actor.scripted_input = true
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		lab.reset_player()
		var label := " at %d Hz" % hz
		for i in 8:
			await tick()
			if actor.is_on_floor():
				break
		check(actor.is_on_floor() and actor.active_clip == "Idle", "Reset settles on the floor" + label)
		actor.requested_jump = true
		check(await wait_clip(actor, "JumpTakeoff", hz), "Space starts takeoff" + label)
		actor.requested_jump = false
		for i in ceili(0.07 * hz):
			await tick()
		compare_source(actor, oracle, "JumpTakeoff", "Takeoff" + label)
		check(await wait_clip(actor, "JumpAirborne", hz), "Apex starts airborne loop" + label)
		check(actor.velocity.y <= 0.0, "Airborne transition follows the physical apex" + label)
		for i in ceili(0.07 * hz):
			await tick()
		compare_source(actor, oracle, "JumpAirborne", "Jump descent" + label)
		check(await wait_clip(actor, "JumpLanding", hz) and actor.is_on_floor(), "Contact starts landing" + label)
		for i in ceili(0.07 * hz):
			await tick()
		compare_source(actor, oracle, "JumpLanding", "Landing" + label)
		check(await wait_clip(actor, "Idle", hz), "Landing returns to Idle" + label)

		check(actor.drop_for_lab(7.0), "Free-fall button starts a drop" + label)
		check(await wait_clip(actor, "JumpAirborne", 4), "Drop enters airborne loop directly" + label)
		for i in ceili(0.10 * hz):
			await tick()
		compare_source(actor, oracle, "JumpAirborne", "Free fall" + label)
		check(await wait_clip(actor, "JumpLanding", 2 * hz) and actor.is_on_floor(),
			"Free-fall landing starts at actual contact" + label)
		check(await wait_clip(actor, "Idle", hz), "Drop landing returns to Idle" + label)

		check(actor.drop_for_lab(5.0), "Medium drop starts on the floor" + label)
		check(await wait_clip(actor, "JumpAirborne", 4), "Medium drop enters the same source loop" + label)
		check(await wait_clip(actor, "JumpLanding", 2 * hz), "Medium drop plays source landing" + label)
		check(await wait_clip(actor, "Idle", hz), "Medium drop returns to Idle" + label)

		actor.requested_direction = Vector2(0.0, -1.0)
		actor.requested_run = true
		check(await wait_clip(actor, "Run", hz), "Moving trial starts in Run" + label)
		actor.requested_jump = true
		check(await wait_clip(actor, "JumpTakeoff", hz), "Running jump starts source takeoff" + label)
		actor.requested_jump = false
		check(await wait_clip(actor, "JumpLanding", hz) and actor.is_on_floor(),
			"Running jump enters source landing on contact" + label)
		var contact_clock: float = actor.simulation_clock
		check(actor.current_speed > 1.0, "Landing animation allows horizontal movement" + label)
		check(await wait_clip(actor, "Run", hz), "Landing resumes Run" + label)
		var resume_seconds: float = actor.simulation_clock - contact_clock
		moving_resume_seconds[hz] = resume_seconds
		check(actor.hybrid_motion.owns_pose, "Live gait owns the pose on Run entry" + label)
		check(resume_seconds <= 0.05 + 1.0 / hz + 0.00001,
			"Running landing hands back promptly%s (%.3f s)" % [label, resume_seconds])
		await check_sabre_landing_movement(lab, hz)
	check(oracle.get("native_jump_pose_enabled") != true, "Shared actor defaults to the existing hybrid jump")
	print("MECHANIC_LAB_MD2_JUMP ", JSON.stringify({"checks": checks, "failures": failures, "moving_resume_seconds": moving_resume_seconds}))
	lab.free()
	oracle.free()
	quit(0 if failures.is_empty() else 1)

func check_sabre_landing_movement(lab, hz: int) -> void:
	var actor = lab.player
	actor.requested_direction = Vector2.ZERO
	lab.reset_player()
	for i in 8:
		await physics_frame
	check(actor.drop_for_lab(5.0), "Sabre movement fixture starts a drop at %d Hz" % hz)
	for i in 2:
		await physics_frame
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	root.push_input(event, true)
	await physics_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	root.push_input(event, true)
	for i in hz:
		await physics_frame
		if actor.is_on_floor():
			break
	check(actor.is_on_floor() and actor.active_clip == "AirAttack", "Sabre enters the landing animation at %d Hz" % hz)
	if not actor.is_on_floor():
		return
	var origin: Vector3 = actor.global_position
	var touchdown_tick := Engine.get_physics_frames()
	actor.requested_direction = Vector2(0.0, -1.0)
	actor.requested_run = true
	var first_step := -1
	for i in hz:
		await physics_frame
		if absf(actor.global_position.z - origin.z) > 0.00001:
			first_step = Engine.get_physics_frames() - touchdown_tick
			break
	var delay := 0.410354003
	check(first_step == ceili(delay * hz) and actor.active_clip == "AirAttack",
		"Sabre moves on the first physics step containing AN_ResumeMovement at %d Hz" % hz)
	var expected_travel: float = actor.run_speed * (float(first_step) / hz - delay)
	check(absf(absf(actor.global_position.z - origin.z) - expected_travel) < 0.001,
		"Sabre only moves during the open fraction of that step at %d Hz" % hz)
	print("SABRE_LANDING_MOVEMENT hz=", hz, " first_step=", first_step, " clip=", actor.active_clip,
		" travel=", absf(actor.global_position.z - origin.z), " expected=", expected_travel)
	actor.requested_direction = Vector2.ZERO


