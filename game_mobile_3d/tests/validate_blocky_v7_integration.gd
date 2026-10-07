extends SceneTree
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
var level: Node3D
var player: CharacterBody3D
var visual: Node3D
var checks := 0
var failures: Array[String] = []
var metrics := {}
var rendered := false

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
func tick(n: int) -> void:
	for i in n: await physics_frame
func release_inputs() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint"]: Input.action_release(action)
func capture(label: String) -> void:
	if not rendered: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/blocky_v7_%s.png" % label)
func sole(bone: int) -> Vector3:
	var transform: Transform3D = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(bone)
	var lowest := Vector3(0, INF, 0)
	for x in [-0.1125, 0.1125]:
		for z in [-0.1125, 0.1125]:
			var point := transform * Vector3(x, 0.675, z)
			if point.y < lowest.y: lowest = point
	return lowest
func run() -> void:
	rendered = "--capture" in OS.get_cmdline_user_args()
	level = LEVEL.instantiate()
	level.get_node("SpawnDirector").enabled = false
	level.get_node("Progression").enabled = false
	root.add_child(level)
	level.player.get_node("WeaponBehavior").enabled=false # Historical pose/gameplay baseline, without D0 behavior.
	current_scene = level
	level.select_test_weapon(0)
	player = level.player
	visual = player.visual
	visual.set_locomotion_mode(0) # Explicit retained Run V7 rollback contract.
	# Baseline authored locomotion is measured without the opt-in carry overlay.
	visual.set_weapon_equipped(false)
	player.get_node("Pistol").enabled = false
	level.combat.audio.minimum_event_interval = 1000000.0
	await tick(20)
	check(visual.authored_locomotion, "Authored integration enabled")
	check(visual.idle.clip == visual.animation_player.get_animation("Idle"), "New Idle drives runtime")
	check(visual.run.clip == visual.animation_player.get_animation("Run"), "New Run drives runtime")
	check(visual.idle.clip.loop_mode == Animation.LOOP_LINEAR and visual.run.clip.loop_mode == Animation.LOOP_LINEAR, "Both clips loop")
	check(absf(visual.run.clip.length - 16.0 / 24.0) < 0.000001, "Run has exact authored duration")
	check(visual.current_state == &"Idle" and player.is_on_floor(), "Idle and collision floor work")
	check(visual.find_children("*", "Skeleton3D", true, false).size() == 1, "One live skeleton")
	check(visual.skeleton.get_bone_count() == 12 and visual.socket_bone >= 0, "Carrier and existing non-deforming weapon socket retained")
	check(player.walk_speed == 4.25 and player.run_speed == 6.25, "Gameplay speeds unchanged")
	var material := visual.meshes[0].mesh.surface_get_material(0) as BaseMaterial3D
	check(material != null and material.albedo_texture != null and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Imported textured mesh uses nearest filtering")
	await capture("idle")
	player.position = Vector3(0, 0.02, -4)
	Input.action_press("move_backward")
	await tick(40)
	check(visual.current_state == &"Walk" and absf(player.current_speed - 4.25) < 0.01, "Legacy Walk preserved at original speed")
	await capture("walk")
	Input.action_press("sprint")
	await tick(20)
	check(visual.current_state == &"Run" and absf(player.current_speed - 6.25) < 0.01, "Run state at original speed")
	check(absf(visual.global_basis.z.dot(player.get_real_velocity().normalized()) - 1) < 0.01, "+Z model faces actual motion")
	await capture("run")
	# Measure one authored cycle while repositioning safely away from arena walls.
	player.position = Vector3(0, 0.02, -3)
	await tick(20)
	player.position = Vector3(0, 0.02, -3)
	var start := player.global_position
	var last_phase: float = visual.authored_run_time
	var phase_error := 0.0
	var root_drift := 0.0
	var pose_error := 0.0
	var rotation_error := 0.0
	var scale_error := 0.0
	var hip_start: Vector3 = visual.skeleton.get_bone_global_pose(visual.hips).origin
	var min_sole := INF
	var slide_velocities: Array[float] = []
	var prev_soles := [sole(visual.leg_left), sole(visual.leg_right)]
	var cycle_frames: int = roundi(60.0 * visual.run.clip.length / visual.run_animation_speed_scale)
	for f in cycle_frames:
		await tick(1)
		var expected: float = fposmod(last_phase + visual.run_animation_speed_scale / 60.0, visual.run.clip.length)
		phase_error = maxf(phase_error, absf(wrapf(visual.authored_run_time - expected, -visual.run.clip.length / 2, visual.run.clip.length / 2)))
		last_phase = visual.authored_run_time
		var root_index: int = visual.skeleton.find_bone("Root")
		root_drift = maxf(root_drift, visual.skeleton.get_bone_pose_position(root_index).length())
		for i in visual.skeleton.get_bone_count():
			if i == visual.socket_bone: continue
			pose_error = maxf(pose_error, visual.skeleton.get_bone_pose_position(i).distance_to(visual.run.position(i, visual.authored_run_time)))
			rotation_error = maxf(rotation_error, 1.0 - absf(visual.skeleton.get_bone_pose_rotation(i).dot(visual.run.rotation(i, visual.authored_run_time))))
			scale_error = maxf(scale_error, visual.skeleton.get_bone_pose_scale(i).distance_to(Vector3.ONE))
		var soles := [sole(visual.leg_left), sole(visual.leg_right)]
		for i in 2:
			min_sole = minf(min_sole, soles[i].y)
			if soles[i].y < 0.025 and prev_soles[i].y < 0.025:
				slide_velocities.append((soles[i].z - prev_soles[i].z) * 60.0)
		prev_soles = soles
	var travelled := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	check(absf(travelled - player.run_speed * visual.run.clip.length / visual.run_animation_speed_scale) < 0.02, "Measured gameplay travel during one cadence-adjusted Run cycle")
	check(phase_error < 0.00001 and root_drift < 0.00001 and pose_error < 0.00001, "Configured Run clock with authored body and no root motion")
	var hip_cycle_error: float = hip_start.distance_to(visual.skeleton.get_bone_global_pose(visual.hips).origin)
	check(rotation_error < 0.000001 and scale_error < 0.000001 and hip_cycle_error < 0.00001, "Authored rotations, unit scale and cyclic local Hips preserved")
	metrics.merge({"authored_rotation_quaternion_dot_error":rotation_error,"bone_scale_error":scale_error,"hips_loop_local_displacement_m":hip_cycle_error})
	metrics.merge({"walk_speed_mps":player.walk_speed,"run_speed_mps":player.run_speed,"cycle_seconds":visual.run.clip.length,"travel_per_run_cycle_m":travelled,"run_phase_max_error_seconds":phase_error,"root_pose_translation_max_m":root_drift,"authored_body_position_error_m":pose_error,"minimum_sole_world_y_m":min_sole,"support_sole_world_z_velocity_mps":slide_velocities,"blend_seconds":0.13})
	var changes: int = visual.state_changes
	var phase_before_turn: float = visual.authored_run_time
	Input.action_release("move_backward");Input.action_press("move_right")
	await tick(25)
	check(visual.current_state == &"Run" and absf(wrapf(visual.authored_run_time - phase_before_turn - 25.0 / 60.0 * visual.run_animation_speed_scale, -visual.run.clip.length / 2, visual.run.clip.length / 2)) < 0.00001, "Direction change keeps uninterrupted authored Run clock")
	metrics["turn_state_changes_from_real_speed"] = visual.state_changes - changes
	check(visual.global_basis.z.dot(player.get_real_velocity().normalized()) > 0.98, "Model follows direction change")
	await capture("turn")
	release_inputs()
	await tick(30)
	check(visual.current_state == &"Idle" and player.current_speed < 0.001 and visual.move_weight == 0.0, "Smooth return to Idle")
	await capture("stop")
	for repeat in 4:
		player.position = Vector3(0, 0.02, 0)
		Input.action_press("move_backward");Input.action_press("sprint")
		await tick(20)
		check(visual.current_state == &"Run", "Repeated start %d" % repeat)
		release_inputs();await tick(25)
		check(visual.current_state == &"Idle", "Repeated stop %d" % repeat)
	# Ten continuous cycles through repeated circles using the unchanged input
	# controller. This also exercises diagonals and both sides without hitting walls.
	player.position=Vector3(0,0.02,-2.5)
	var circle_clock: float = visual.authored_run_time
	var circle_elapsed := 0.0
	var circle_clock_error := 0.0
	Input.action_press("sprint")
	for frame in ceili(10.0 * visual.run.clip.length / visual.run_animation_speed_scale * 60.0)+25:
		var angle: float = frame / 60.0 * 2.5
		var x := cos(angle)
		var z := sin(angle)
		for action in ["move_left","move_right","move_forward","move_backward"]:Input.action_release(action)
		Input.action_press("move_right" if x >= 0 else "move_left",absf(x))
		Input.action_press("move_backward" if z >= 0 else "move_forward",absf(z))
		await tick(1)
		circle_elapsed += 1.0 / 60.0
		circle_clock_error=maxf(circle_clock_error,absf(wrapf(visual.authored_run_time-circle_clock-circle_elapsed*visual.run_animation_speed_scale,-visual.run.clip.length/2,visual.run.clip.length/2)))
	check(circle_clock_error<0.00001 and visual.current_state==&"Run", "Ten continuous cycles, circles/diagonals and uninterrupted Run phase")
	metrics.merge({"run_animation_speed_scale":visual.run_animation_speed_scale,"runtime_cycle_seconds":visual.run.clip.length/visual.run_animation_speed_scale,"continuous_circular_cycles":circle_elapsed*visual.run_animation_speed_scale/visual.run.clip.length,"circle_clock_error_seconds":circle_clock_error})
	release_inputs();await tick(30)
	player.position = Vector3(0, 0.02, 5.7)
	Input.action_press("move_backward");Input.action_press("sprint")
	await tick(40)
	check(player.position.z < 6.6 and player.current_speed < 0.1, "Arena wall collision preserved")
	release_inputs();player.position = Vector3(0, 0.02, 0);player.velocity = Vector3.ZERO
	var enemy := ZOMBIE.instantiate()
	enemy.position = Vector3(0, 0.02, 3.5)
	enemy.max_hp = 100000
	level.get_node("Actors").add_child(enemy)
	enemy.current_hp = 100000;enemy.set_physics_process(false)
	level.combat.register_zombie(enemy)
	player.get_node("Pistol").enabled = true
	for weapon in 3:
		player.equip_test_weapon(weapon)
		var gun: Node = player.get_node("Pistol")
		var shots: int = gun.shot_count
		await tick(70)
		check(gun.shot_count > shots and visual.socket.equipped == weapon, "Weapon %d still fires from socket" % weapon)
		check(visual.socket.muzzle_position().is_finite(), "Valid muzzle %d" % weapon)
		await capture("weapon_%d" % weapon)
	metrics["camera_current"] = level.get_node("Camera3D").current
	check(metrics.camera_current, "Existing camera remains active")
	var report := {"checks":checks,"failures":failures,"metrics":metrics,"rendered":rendered}
	var file := FileAccess.open("res://tests/run_cadence_integration_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"));file.close()
	print("BLOCKY_V7_VALIDATION=" + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

