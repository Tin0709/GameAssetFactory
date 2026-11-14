extends SceneTree

const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL ", description)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var body := lab.player.model.find_child("SabrePrototypeBody", true, false) as MeshInstance3D
	var face := lab.player.face as MeshInstance3D
	var weapon := lab.player.model.find_child("SabrePrototypeSabre", true, false) as MeshInstance3D
	var original_overlay := body.material_overlay
	var weapon_overlay := weapon.material_overlay
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	for i in 180:
		await physics_frame
		if lab.player_health < 100:
			break
	var numbers := lab.get_node_or_null("CombatEffects/PlayerDamageNumbers")
	check(lab.player_health == 94, "A real zombie attack takes six HP")
	check(body.material_overlay != original_overlay and face.material_overlay == body.material_overlay
		and weapon.material_overlay == weapon_overlay, "The body and face flash while the weapon retains its material")
	await wait_for_damage_display()
	check(numbers != null and numbers.get_child_count() == 1, "One number appears on the real hit")
	if numbers != null and numbers.get_child_count() == 1:
		var number := numbers.get_child(0) as Node3D
		var digit := number.get_child(0) as Sprite3D
		check(number.get_meta("amount") == 6 and digit.modulate.r > digit.modulate.g * 2.0,
			"The number shows actual HP lost in red")
		var start := number.global_position
		await ticks(10)
		check(number.global_position.y > start.y and body.material_overlay == original_overlay,
			"The number floats upward while the short flash clears")
	await ticks(45)
	check(numbers != null and numbers.get_child_count() == 0, "The floating number expires")
	var remaining: int = lab.player_health
	lab._on_player_hit(999)
	check(lab.player_health == 0 and lab.player.is_dead and body.material_overlay != original_overlay,
		"A lethal hit still flashes and enters defeat")
	await wait_for_damage_display()
	if numbers != null:
		check(numbers.get_child_count() == 1 and numbers.get_child(0).get_meta("amount") == remaining,
			"Overkill displays only the HP actually lost")
		lab._on_player_hit(1)
		check(numbers.get_child_count() == 1, "Damage after defeat adds no number")
	lab.reset_player()
	await ticks(3)
	check(lab.player_health == 100 and body.material_overlay == original_overlay
		and numbers != null and numbers.get_child_count() == 0, "Retry clears player hit effects")
	for zombie in lab.get_node("Zombies").get_children():
		zombie.free()
	await check_turned_zombie(lab)
	await check_melee_montage_clock(lab)
	await check_melee_focus(lab)
	await check_melee_height(lab)
	await check_zombie_perception(lab)
	await check_zombie_roam(lab)
	await check_simultaneous_damage(lab, numbers)
	lab._on_player_hit(6)
	lab._process(0.12)
	lab._process(1.0 / 60.0)
	check(body.material_overlay != original_overlay and float(body.get_instance_shader_parameter(&"player_hit_flash")) > 0.9,
		"A render hitch before the first displayed frame does not consume the player flash")
	lab._process(0.12)
	check(body.material_overlay == original_overlay, "A later render hitch expires the player flash")
	lab.free()
	print("MECHANIC_LAB_PLAYER_HIT failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_turned_zombie(lab) -> void:
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = lab.get_node("Zombies").get_child(0)
	zombie.global_position = Vector3(0.0, 0.0, -1.34)
	zombie.rotation.y = deg_to_rad(170.0)
	zombie.animation.play(ZOMBIE.IDLE, 0.0)
	zombie.animation.advance(0.0)
	var openings: Array[float] = []
	zombie.melee_audio.connect(func(_point, contact):
		if not contact:
			var offset: Vector3 = lab.player.global_position - zombie.global_position
			offset.y = 0.0
			openings.append(zombie.global_basis.z.dot(offset.normalized())))
	for i in 90:
		await physics_frame
		if lab.player_health < 100:
			break
	check(openings.size() == 1 and openings[0] >= ZOMBIE.MELEE_HALF_ANGLE_COS and lab.player_health == 94,
		"An initially turned zombie faces the stationary player before its first windup and lands once")
	print("MECHANIC_LAB_ZOMBIE_FACING first_dot=", openings.front() if not openings.is_empty() else "none",
		" attacks=", openings.size(), " hp=", lab.player_health)
	zombie.free()

func check_melee_montage_clock(lab) -> void:
	lab.reset_player()
	await ticks(3)
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie := lab.get_node("Zombies").get_child(0) as ZOMBIE
	zombie.global_position = Vector3(0.0, 0.02, -1.34)
	zombie.rotation.y = 0.0
	zombie.animation.play(ZOMBIE.IDLE, 0.0)
	zombie.animation.advance(0.0)
	var attack_ticks: Array[int] = []
	var source_positions: Array[float] = []
	zombie.melee_audio.connect(func(_point, contact: bool):
		attack_ticks.append(Engine.get_physics_frames())
		if contact:
			source_positions.append(zombie.animation.current_animation_position))
	await ticks(56)
	check(attack_ticks.size() == 2 and attack_ticks[1] - attack_ticks[0] == 23 and lab.player_health == 94,
		"The native zombie montage reaches its first melee contact on the expected 60 Hz tick")
	check(source_positions.size() == 1 and absf(source_positions[0] - 0.584444) < 0.001,
		"The zombie leaves the accelerated telegraph at frame 13 and advances at the montage rate")
	print("MECHANIC_LAB_ZOMBIE_MONTAGE ticks=", attack_ticks, " contact_source=", source_positions)
	zombie.free()
	lab.reset_player()

func check_melee_focus(lab) -> void:
	var player: CharacterBody3D = lab.player
	player.set_physics_process(false)
	for fixture in ["early sidestep", "late sidestep", "retreat"]:
		lab.reset_player()
		await ticks(3)
		lab.get_node("HUD/SpawnZombie").pressed.emit()
		var zombie := lab.get_node("Zombies").get_child(0) as ZOMBIE
		zombie.global_position = Vector3(0.0, 0.02, -1.34)
		zombie.rotation.y = 0.0
		zombie.animation.play(ZOMBIE.IDLE, 0.0)
		zombie.animation.advance(0.0)
		for frame in 30:
			await physics_frame
			if zombie.animation.current_animation == ZOMBIE.ATTACK:
				break
		check(zombie.animation.current_animation == ZOMBIE.ATTACK, "The focus fixture begins a real windup")
		await ticks(4)
		if fixture == "late sidestep":
			await ticks(14)
			check(zombie.animation.current_animation_position > 13.0 / 30.0,
				"The late sidestep starts after the montage releases focus")
		var initial_yaw := zombie.rotation.y
		player.global_position += Vector3(0.0, 0.0, 0.95) if fixture == "retreat" else Vector3(0.78, 0.0, 0.0)
		await ticks(22)
		var turned := absf(angle_difference(initial_yaw, zombie.rotation.y))
		if fixture == "early sidestep":
			check(turned > 0.30 and lab.player_health == 94, "The telegraph tracks an early sidestep and hits once")
		elif fixture == "late sidestep":
			check(turned < 0.001 and lab.player_health == 100, "The hit section keeps its heading and misses a late sidestep")
		else:
			check(lab.player_health == 100, "A retreat outside the reach avoids the strike")
		print("MECHANIC_LAB_ZOMBIE_FOCUS ", fixture, " yaw_change=", turned, " hp=", lab.player_health)
		zombie.free()
	player.set_physics_process(true)
	lab.reset_player()

func check_melee_height(lab) -> void:
	var group: Node = lab.get_node("Zombies")
	lab.player.set_physics_process(false)
	for fixture: Vector2 in [Vector2(1.65, 0.0), Vector2(2.05, 0.0), Vector2(1.65, 1.0)]:
		var height := fixture.x
		var blocked := fixture.y > 0.0
		lab.reset_player()
		lab.player.global_position = Vector3.UP * height
		lab.get_node("HUD/SpawnZombie").pressed.emit()
		var zombie := group.get_child(0) as ZOMBIE
		zombie.global_position = Vector3(0.0, 0.02, -1.34)
		zombie.rotation.y = 0.0
		zombie.animation.play(ZOMBIE.IDLE, 0.0)
		zombie.animation.advance(0.0)
		var wall: StaticBody3D
		if blocked:
			for frame in 36:
				await physics_frame
				if zombie.animation.current_animation == ZOMBIE.ATTACK:
					break
			check(zombie.animation.current_animation == ZOMBIE.ATTACK, "The wall fixture starts with a real windup")
			wall = StaticBody3D.new()
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(3.0, 3.0, 0.15)
			collider.shape = box
			wall.add_child(collider)
			wall.position = Vector3(0.0, 1.5, -0.67)
			lab.add_child(wall)
		await ticks(60)
		var expected_health := 94 if height < 2.0 and not blocked else 100
		check(lab.player_health == expected_health, "Zombie attack at height %.2f m with wall=%s" % [height, blocked])
		if height > 2.0:
			check(zombie.animation.current_animation != ZOMBIE.ATTACK, "Targets beyond the height limit do not start a windup")
		if wall != null:
			wall.free()
		zombie.free()
	lab.player.set_physics_process(true)
	lab.reset_player()
	await ticks(2)

func check_zombie_perception(lab) -> void:
	var group: Node = lab.get_node("Zombies")
	var player: CharacterBody3D = lab.player
	player.set_physics_process(false)
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie := group.get_child(0) as ZOMBIE
	player.global_position = Vector3(0.0, 0.02, 10.25)
	await ticks(2)
	zombie.global_position = Vector3(0.0, 0.02, 0.0)
	zombie.rotation.y = PI
	zombie.animation.play(ZOMBIE.IDLE, 0.0)
	zombie.animation.advance(0.0)
	await ticks(29)
	check(absf(zombie.position.z) < 0.02, "An unseen target outside the 10 m radius does not cause pursuit")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16.0, 4.0, 0.25)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(0.0, 2.0, 5.0)
	lab.add_child(wall)
	player.global_position.z = 9.5
	await ticks(7)
	check(absf(zombie.position.z) < 0.02, "A wall prevents first detection inside the radius")
	lab.remove_child(wall)
	await ticks(23)
	check(absf(zombie.position.z) < 0.02, "A new sighting needs 0.4 seconds before pursuit")
	await ticks(9)
	check(zombie.position.z > 0.2, "The zombie detects the player from behind inside 10 m")
	lab.add_child(wall)
	await ticks(12)
	var before_shift := zombie.position
	player.global_position.x = 4.0
	await ticks(36)
	check(zombie.position.z > before_shift.z + 1.0 and absf(zombie.position.x) < 0.10,
		"During the sight-loss grace period the zombie pursues the last seen location")
	lab.remove_child(wall)
	var before_reveal := zombie.position
	await ticks(8)
	check(zombie.position.x > before_reveal.x + 0.08,
		"A target revealed during the grace period is pursued immediately")
	lab.add_child(wall)
	for frame in 4:
		await physics_frame
		if not zombie._target_visible:
			break
	check(not zombie._target_visible and zombie._target_aggressive, "Losing sight starts the grace period")
	await ticks(117)
	check(zombie._target_aggressive, "The zombie keeps its target through the two-second grace period")
	await ticks(4)
	check(not zombie._target_aggressive, "The zombie drops its target after the grace period")
	var lost_position := zombie.position
	lab.remove_child(wall)
	await ticks(17)
	check(zombie.position.distance_to(lost_position) < 0.02,
		"After two seconds out of sight the zombie needs a fresh detection")
	await ticks(16)
	check(zombie.position.distance_to(lost_position) > 0.15, "Reacquiring the target resumes pursuit")
	print("MECHANIC_LAB_ZOMBIE_PERCEPTION last_seen=", before_shift, " dropped=", lost_position, " reacquired=", zombie.position)
	wall.free()
	zombie.free()
	player.set_physics_process(true)
	lab.reset_player()
	await ticks(2)

func check_zombie_roam(lab) -> void:
	var player: CharacterBody3D = lab.player
	var group: Node = lab.get_node("Zombies")
	player.set_physics_process(false)
	player.global_position = Vector3(47.0, 0.02, 47.0)
	await ticks(2)
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie := group.get_child(0) as ZOMBIE
	var origin := zombie.position
	player.global_position = Vector3(-22.0, 0.02, -22.0)
	var reached_idle := false
	for frame in 30:
		await physics_frame
		if zombie.animation.current_animation == ZOMBIE.IDLE:
			reached_idle = true
			break
	check(reached_idle, "A patrol starts from the ordinary spawned idle")
	await ticks(57)
	check(zombie.position.distance_to(origin) < 0.025, "An idle zombie first waits for one second")
	await ticks(27)
	check(zombie.position.distance_to(origin) > 0.5 and zombie.animation.current_animation in ZOMBIE.WALK_CLIPS,
		"An unalerted zombie roams on its native walking clip")
	var peak_distance := 0.0
	var peak_speed := 0.0
	var saw_pause := false
	var saw_second_walk := false
	for frame in 350:
		await physics_frame
		peak_distance = maxf(peak_distance, zombie.position.distance_to(origin))
		peak_speed = maxf(peak_speed, zombie.get_real_velocity().slide(Vector3.UP).length())
		if zombie.animation.current_animation == ZOMBIE.IDLE:
			saw_pause = true
		elif saw_pause and zombie.animation.current_animation in ZOMBIE.WALK_CLIPS:
			saw_second_walk = true
	check(saw_pause and saw_second_walk and peak_distance <= 10.025,
		"Patrol pauses before a new leg and stays within ten metres of the spawn")
	check(peak_speed > 2.95 and peak_speed <= 3.03 and zombie.is_on_floor(),
		"Edge patrol uses the 3 m/s movement attribute and stays on the platform")
	var target_position := zombie.position - Vector3(3.0, 0.0, 3.0)
	player.global_position = target_position
	await ticks(27)
	var start_chase := zombie.position.distance_to(target_position)
	await ticks(26)
	check(zombie._target_aggressive and zombie.position.distance_to(target_position) < start_chase - 1.0,
		"Seeing the player interrupts the patrol and starts pursuit")
	print("MECHANIC_LAB_ZOMBIE_ROAM peak_range=", peak_distance, " peak_speed=", peak_speed, " second_walk=", saw_second_walk)
	zombie.free()
	player.set_physics_process(true)
	lab.reset_player()
	await ticks(2)

func check_simultaneous_damage(lab, numbers: Node) -> void:
	lab.reset_player()
	await ticks(3)
	var group: Node = lab.get_node("Zombies")
	for i in 4:
		group.player_hit.emit(ZOMBIE.MELEE_DAMAGE)
	check(lab.player_health == 76, "Four same-tick hits each apply damage immediately")
	await wait_for_damage_display()
	check(numbers.get_child_count() == 1 and numbers.get_child(0).get_meta("amount") == 24,
		"Same-tick hits display one readable red total")
	if numbers.get_child_count() == 1:
		var total := numbers.get_child(0)
		check(total.get_child_count() == 2 and (total.get_child(0) as Sprite3D).modulate.g < 0.25,
			"The total renders both glyphs in the player damage tint")
	await physics_frame
	group.player_hit.emit(ZOMBIE.MELEE_DAMAGE)
	await wait_for_damage_display()
	check(numbers.get_child_count() == 2 and numbers.get_child(1).get_meta("amount") == 6,
		"A separate physics tick produces its own floating number")
	lab.reset_player()
	await ticks(3)
	lab.set_process(false)
	group.player_hit.emit(2)
	await physics_frame
	group.player_hit.emit(3)
	lab.set_process(true)
	await wait_for_damage_display()
	check(numbers.get_child_count() == 2 and numbers.get_child(0).get_meta("amount") == 2
		and numbers.get_child(1).get_meta("amount") == 3, "Two catch-up ticks keep separate totals")
	lab.reset_player()
	await ticks(3)
	lab.player_health = 9
	group.player_hit.emit(6)
	group.player_hit.emit(6)
	group.player_hit.emit(6)
	await wait_for_damage_display()
	check(lab.player.is_dead and lab.player_health == 0 and numbers.get_child_count() == 1
		and numbers.get_child(0).get_meta("amount") == 9, "The lethal total includes only the HP actually lost")
	lab.reset_player()
	group.player_hit.emit(6)
	lab.reset_player()
	await wait_for_damage_display()
	check(lab.player_health == 100 and numbers.get_child_count() == 0, "Reset discards a pending damage total")

func wait_for_damage_display() -> void:
	await process_frame
	await process_frame
