extends SceneTree
const LEVEL = preload("res://scenes/CuboidGameplayTest.tscn")
const LAB = preload("res://scenes/PlayerPoseLab.tscn")
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
const Profiles = preload("res://scripts/weapon_fire_profiles.gd")
const Catalog = preload("res://scripts/upgrade_catalog.gd")
var level: Node3D
var player: CharacterBody3D
var gun: Node3D
var combat: Node
var checks := 0
var failures: Array[String] = []
var rendered := false
var metrics := {}
var inspection_lab: Node3D

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
func tick(frames: int) -> void:
	for frame in frames: await physics_frame
func capture(label: String) -> void:
	if not rendered: return
	if is_instance_valid(inspection_lab): inspection_lab._update_status()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/movement_weapon_%s.png" % label)
func enemy(point: Vector3) -> Node3D:
	var actor := ZOMBIE.instantiate()
	actor.position = point
	level.get_node("Actors").add_child(actor)
	actor.max_hp = 100000
	actor.current_hp = 100000
	actor.set_physics_process(false)
	combat.register_zombie(actor)
	return actor
func clear_enemies() -> void:
	for actor in combat.living_zombies.duplicate(): actor.queue_free()
	combat.living_zombies.clear()
func release_inputs() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_backward", "sprint"]: Input.action_release(action)

func run() -> void:
	rendered = "--capture" in OS.get_cmdline_user_args()
	level = LEVEL.instantiate()
	level.get_node("SpawnDirector").enabled = false
	level.get_node("Progression").enabled = false
	root.add_child(level)
	current_scene = level
	check(paused and level.weapon_selector.visible, "Startup selection pauses gameplay")
	level.select_test_weapon(0)
	check(not paused, "Selection resumes gameplay")
	player = level.player
	gun = player.get_node("Pistol")
	combat = level.combat
	# Silence only this stress harness, avoiding native MP3 shutdown race in
	# artificially accelerated headless loops. Audio regression runs separately.
	combat.audio.minimum_event_interval = 1000000.0
	await tick(3)
	var target := enemy(Vector3(0, 0.02, 3.5))
	for weapon in 3:
		player.equip_test_weapon(weapon)
		var profile: Dictionary = Profiles.PROFILES[weapon]
		check(gun.damage_per_shot == profile.damage and is_equal_approx(gun.shot_interval, profile.interval), "Distinct weapon profile %d" % weapon)
		player.position = Vector3(0, 0.02, 0)
		player.velocity = Vector3.ZERO
		var shots: int = gun.shot_count
		await tick(120)
		var count: int = gun.shot_count - shots
		check(count >= floori(1.8 / profile.interval) and count <= ceili(2.0 / profile.interval), "Automatic cadence %d" % weapon)
		check(target.current_hp < 100000 and player.visual.recoil_gain <= 1.45, "Damage and bounded repeated recoil %d" % weapon)
		metrics["weapon_%d_shots_in_2s" % weapon] = count
		var origin: Vector3 = player.visual.socket.muzzle_position()
		var bullets_before: int = combat.projectiles.get_child_count()
		var flashes_before: int = combat.effects.get_child_count()
		combat.fire(origin, Vector3.BACK, int(profile.damage), float(profile.speed), 0.9, float(profile.range), weapon)
		var flash: Node3D = combat.effects.get_child(-1)
		check(combat.projectiles.get_child_count() - bullets_before == profile.pellets and combat.effects.get_child_count() - flashes_before == 1, "One flash and correct pellet count per trigger %d" % weapon)
		check(flash.global_position.is_equal_approx(origin) and absf(flash.duration - profile.flash_duration) < 0.00001, "Actual Muzzle_Point and brief weapon-specific flash %d" % weapon)
		for actions in [["move_backward"], ["move_right"], ["move_forward"], ["move_right", "move_backward"]]:
			player.position = Vector3(0, 0.02, 0)
			player.velocity = Vector3.ZERO
			shots = gun.shot_count
			for action in actions: Input.action_press(action)
			await tick(38)
			check(absf(player.current_speed - 2.6) < 0.03 and gun.can_fire(), "Controlled combat movement %d / %s" % [weapon, actions])
			check(gun.shot_count > shots or gun.cooldown > 0.0, "Slow movement preserves fire cooldown %d" % weapon)
			release_inputs()
			await tick(10)
		player.position = Vector3(0, 0.02, 0)
		player.velocity = Vector3.ZERO
		Input.action_press("move_right")
		Input.action_press("sprint")
		await tick(6)
		shots = gun.shot_count
		check(player.current_speed > 3.0 and not gun.can_fire() and not player.visual.has_target, "Acceleration stops fire and lowers weapon %d" % weapon)
		await tick(28)
		check(gun.shot_count == shots and absf(player.current_speed - 6.25) < 0.03, "Sprint into target range stays fast and cannot shoot %d" % weapon)
		check(player.visual.aim_weight < 0.01, "Run reaches LowReady %d" % weapon)
		Input.action_release("sprint")
		await tick(7)
		check(absf(player.current_speed - 2.6) < 0.03 and gun.can_fire() and player.visual.has_target, "Slowing crosses threshold and raises Aim %d" % weapon)
		await tick(65)
		check(gun.shot_count > shots, "No queued burst; ordinary firing resumes %d" % weapon)
		release_inputs()
		await tick(15)
	# Threshold checks are independent of the sprint button and target state.
	player.current_speed = 3.001
	check(not gun.can_fire(), "Actual speed blocks fire without Shift")
	var before: int = combat.projectiles.get_child_count()
	combat.fire(Vector3(0,1,0), Vector3.BACK, 20, 14, 0.9)
	check(combat.projectiles.get_child_count() == before, "Production shot service also blocks fast movement")
	player.current_speed = 3.0
	check(gun.can_fire(), "Inclusive 3m/s threshold")
	clear_enemies()
	await tick(2)
	player.position = Vector3(0, 0.02, 0)
	Input.action_press("move_right")
	await tick(20)
	check(absf(player.current_speed - 4.25) < 0.03, "Free walk remains 4.25m/s")
	Input.action_press("sprint")
	await tick(12)
	check(absf(player.current_speed - 6.25) < 0.03, "Free run remains 6.25m/s")
	release_inputs()
	await tick(15)
	player.equip_test_weapon(0)
	Catalog.apply(Catalog.UPGRADES[0], player, gun)
	Catalog.apply(Catalog.UPGRADES[1], player, gun)
	player.equip_test_weapon(1)
	check(gun.damage_per_shot == 17 and absf(gun.shot_interval - 0.108) < 0.0001, "Upgrades survive switch to rifle")
	player.equip_test_weapon(2)
	check(gun.damage_per_shot == 15 and absf(gun.shot_interval - 0.9) < 0.0001, "Upgrades survive switch to shotgun")
	player.equip_test_weapon(0)
	check(gun.damage == 25 and absf(gun.fire_interval - 0.45) < 0.0001, "Upgrades survive round trip")
	player.equip_test_weapon(1)
	for upgrade in 20: Catalog.apply(Catalog.UPGRADES[1], player, gun)
	check(absf(gun.shot_interval - 0.0432) < 0.0001, "Rifle rapid-fire upgrade uses existing normalized floor without slowing it")
	player.equip_test_weapon(0)
	gun.damage = 20
	gun.fire_interval = 0.5
	# Independent swept pellets damage separate actors along a real cone.
	gun.enabled = false
	player.position = Vector3(0, 0.02, 0)
	var directions := Profiles.directions(Vector3.FORWARD, 2, 0)
	var victims: Array[Node3D] = []
	for direction in [directions[0], directions[1], directions[4]]:
		victims.append(enemy((Vector3(0, 1.02, 0) + direction * 3.8) * Vector3(1, 0, 1) + Vector3(0, 0.02, 0)))
	await tick(2)
	combat.fire(Vector3(0, 1.02, 0), Vector3.FORWARD, 10, 18, 0.5, 7, 2)
	check(combat.projectiles.get_child_count() == 7, "Shotgun creates exactly seven independently directed streaks")
	check(directions[0].angle_to(directions[1]) > 0.15 and directions[1] != directions[2], "Spread has a tunable ten-degree half cone")
	await tick(20)
	check(victims.all(func(actor): return actor.current_hp < 100000), "Shotgun burst hits three separate targets")
	metrics["shotgun_target_damage"] = victims.map(func(actor): return 100000 - actor.current_hp)
	clear_enemies()
	await tick(40)
	check(combat.projectiles.get_child_count() == 0, "Pellets expire without accumulating")
	var close_target := enemy(Vector3(0, 0.02, -1))
	await tick(2)
	combat.fire(Vector3(0, 1.02, 0), Vector3.FORWARD, 10, 18, 0.5, 7, 2)
	await tick(6)
	check(close_target.current_hp == 99930, "Close shotgun target can receive all seven pellets / 70 damage")
	clear_enemies()
	await tick(30)
	await bounce_and_views()
	await stress()
	release_inputs()
	metrics["checks"] = checks
	metrics["failures"] = failures
	metrics["phone_tested"] = false
	metrics["rendered"] = rendered
	FileAccess.open("res://tests/movement_weapon_%s_validation.json" % ("rendered" if rendered else "headless"), FileAccess.WRITE).store_string(JSON.stringify(metrics, "\t"))
	print(JSON.stringify(metrics))
	level.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func bounce_and_views() -> void:
	player.position = Vector3(0, 0.02, 0)
	player.set_physics_process(false)
	var v: Node3D = player.visual
	v.set_process(false)
	for speed in [4.25, 6.25]:
		v.set_bounce(true)
		var minimum := 0.0
		var maximum := 0.0
		for frame in 180:
			v.update_motion(Vector3.BACK * speed, null, 1.0/60.0)
			v._process(1.0/60.0)
			minimum = minf(minimum, v.body_spring.value.x)
			maximum = maxf(maximum, v.body_spring.value.x)
		metrics["bounce_%.2f_hip_range_m" % speed] = [minimum, maximum]
		check(minimum < (-0.02 if speed == 4.25 else -0.045) and maximum > 0.002, "Visible compression/rebound %.2f" % speed)
		var low := 0.0
		for frame in 90:
			v.update_motion(Vector3.BACK * speed, null, 1.0/60.0)
			v._process(1.0/60.0)
			if v.body_spring.value.x < low:
				low = v.body_spring.value.x
				if rendered and low < (-0.02 if speed == 4.25 else -0.045):
					await capture("game_%s_compress" % ("walk" if speed == 4.25 else "run"))
					v.bounce_enabled = false
					v._evaluate(0)
					await capture("game_%s_off" % ("walk" if speed == 4.25 else "run"))
					v.bounce_enabled = true
					break
	var lab := LAB.instantiate()
	level.hide()
	level.get_node("HUD").hide()
	inspection_lab = lab
	root.add_child(lab)
	lab.set_process(false)
	for weapon in 3:
		lab.equip(weapon)
		lab.set_locomotion(2)
		lab.set_bounce_strength(2.0)
		for aiming in [false, true]:
			lab.set_aim(aiming)
			for frame in 120:
				if frame % 8 == 0: lab.fire_recoil()
				lab._advance(1.0/60.0)
				check(lab.visual.body_spring.value.is_finite(), "200 percent finite rigid springs")
			lab.set_view(1)
			await capture("lab_%d_%s_side" % [weapon, "aim" if aiming else "low"])
			lab.set_view(4)
			await capture("lab_%d_%s_iso" % [weapon, "aim" if aiming else "low"])
		lab.set_bounce_strength(1.0)
	lab.equip(2)
	lab.set_locomotion(0)
	lab.set_aim(true)
	for frame in 30: lab._advance(1.0/60.0)
	lab.fire_recoil()
	lab._advance(1.0/60.0)
	await capture("lab_shotgun_flash_spread")
	lab.queue_free()
	await process_frame
	level.show()
	level.get_node("HUD").show()
	v.set_process(true)
	player.set_physics_process(true)

func stress() -> void:
	clear_enemies()
	await tick(3)
	player.position = Vector3(0, 0.02, 0)
	var target := enemy(Vector3(0, 0.02, 4))
	gun.enabled = true
	for weapon in [1, 2]:
		player.equip_test_weapon(weapon)
		var shots: int = gun.shot_count
		var start := Time.get_ticks_usec()
		var peak := 0
		for frame in 600:
			await physics_frame
			peak = maxi(peak, combat.projectiles.get_child_count())
		metrics["weapon_%d_10s" % weapon] = {"shots": gun.shot_count - shots, "peak_projectiles": peak, "wall_usec_per_frame": float(Time.get_ticks_usec() - start) / 600.0}
		check(peak <= (10 if weapon == 1 else 14), "Bounded projectile count under sustained fire %d" % weapon)
		check(player.visual.recoil_gain <= 1.45 and player.visual.weapon_spring.value.is_finite(), "Stable sustained recoil %d" % weapon)
	gun.enabled = false
	clear_enemies()
	await tick(90)
	check(combat.projectiles.get_child_count() == 0, "Stress shots clean up")
	# Shot construction CPU cost, separate from vsync / frame wall time.
	for weapon in [1, 2]:
		var start_shot := Time.get_ticks_usec()
		for shot in 100:
			combat.fire(Vector3(0, 1.02, 0), Vector3.FORWARD, 10, 18, 0.5, 7, weapon, shot)
			for bullet in combat.projectiles.get_children(): bullet.free()
			for effect in combat.effects.get_children(): effect.free()
		metrics["weapon_%d_shot_construct_and_free_usec" % weapon] = float(Time.get_ticks_usec() - start_shot) / 100.0
		combat.fire(Vector3(0, 1.02, 0), Vector3.FORWARD, 10, 18, 0.5, 7, weapon)
		var bullets: Array = combat.projectiles.get_children()
		var start_ray := Time.get_ticks_usec()
		for frame in 500:
			for bullet in bullets:
				bullet.age = 0.0
				bullet.distance_traveled = 0.0
				bullet.global_position = Vector3(0, 1.02, 0)
				bullet._physics_process(1.0/60.0)
		metrics["weapon_%d_live_projectile_tick_usec" % weapon] = float(Time.get_ticks_usec() - start_ray) / 500.0
		for bullet in bullets: bullet.free()
		for effect in combat.effects.get_children(): effect.free()
	for i in 40:
		var actor := enemy(Vector3(cos(i * TAU / 40) * 5, 0.02, sin(i * TAU / 40) * 5))
		actor.set_physics_process(true)
	player.equip_test_weapon(1)
	gun.enabled = true
	var start := Time.get_ticks_usec()
	for frame in 180: await physics_frame
	metrics["forty_zombies_wall_usec_per_frame"] = float(Time.get_ticks_usec() - start) / 180.0
	check(combat.living_zombies.size() == 40 and gun.shot_count > 0, "Forty-zombie crowd with sustained M4 fire")
	await capture("crowd_40")
	if rendered: metrics["gpu"] = RenderingServer.get_video_adapter_name()
	gun.enabled = false
	clear_enemies()
	await tick(90)
