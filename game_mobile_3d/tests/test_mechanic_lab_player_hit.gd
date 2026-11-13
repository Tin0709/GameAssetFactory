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
	await check_melee_height(lab)
	await check_simultaneous_damage(lab, numbers)
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

func check_melee_height(lab) -> void:
	var group: Node = lab.get_node("Zombies")
	lab.player.set_physics_process(false)
	for height: float in [1.65, 2.05]:
		lab.reset_player()
		lab.player.global_position = Vector3.UP * height
		lab.get_node("HUD/SpawnZombie").pressed.emit()
		var zombie := group.get_child(0) as ZOMBIE
		zombie.global_position = Vector3(0.0, 0.02, -1.34)
		zombie.rotation.y = 0.0
		zombie.animation.play(ZOMBIE.IDLE, 0.0)
		zombie.animation.advance(0.0)
		await ticks(60)
		var expected_health := 94 if height < 2.0 else 100
		check(lab.player_health == expected_health, "The source 2 m melee height limit applies at %.2f m" % height)
		if height > 2.0:
			check(zombie.animation.current_animation != ZOMBIE.ATTACK, "Targets beyond the height limit do not start a windup")
		zombie.free()
	lab.player.set_physics_process(true)
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
