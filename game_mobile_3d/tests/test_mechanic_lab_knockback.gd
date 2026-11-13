extends SceneTree

const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group := lab.get_node("Zombies")
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	check(group.get_child_count() == 1, "The verified zombie spawns in MechanicLab")
	if group.get_child_count() != 1:
		lab.free()
		quit(1)
		return
	var zombie = group.get_child(0)
	zombie.position = Vector3(0.0, 0.0, 4.0)
	await ticks(28)
	zombie.position = Vector3(0.0, 0.0, 2.45)
	check(zombie.animation.current_animation in ZOMBIE.WALK_CLIPS, "The zombie is actively chasing before contact")
	attack(true)
	await ticks(2)
	attack(false)
	for i in 24:
		if zombie.health < 48:
			break
		await physics_frame
	check(zombie.health == 36 and zombie.animation.current_animation != ZOMBIE.STAGGER,
		"Actual E input lands one 12 damage hit below the poise threshold")
	var at_contact: float = zombie.position.z
	var last: float = at_contact
	var first_chase_step := 0
	var step_limit := roundi(0.4 * Engine.physics_ticks_per_second)
	var furthest: float = at_contact
	for i in range(1, step_limit + 7):
		await physics_frame
		var z: float = zombie.position.z
		furthest = maxf(furthest, z)
		if z < last - 0.0001:
			first_chase_step = i
			break
		last = z
	check(furthest > at_contact + 0.20, "A normal hit actually pushes the zombie away")
	check(first_chase_step >= step_limit - 1 and first_chase_step <= step_limit + 1,
		"The zombie resumes chasing after 0.4 s, measured step %d" % first_chase_step)
	check(zombie.animation.current_animation in ZOMBIE.WALK_CLIPS, "The zombie returns to its locomotion clip")
	var after_chase: float = zombie.position.z
	zombie.take_hit(3, Vector3.BACK, Vector2(200.0, 0.0), 0.0)
	await ticks(2)
	check(zombie.position.z < after_chase, "A splash hit with no lab knockback leaves the chase active")

	zombie.position = Vector3(0.0, 0.0, 1.36)
	for i in Engine.physics_ticks_per_second:
		if zombie.animation.current_animation == ZOMBIE.ATTACK and zombie.animation.current_animation_position >= 0.12:
			break
		await physics_frame
	var player_hp: int = lab.player_health
	var windup_position: float = zombie.animation.current_animation_position
	zombie.take_hit(1, Vector3.RIGHT, Vector2(4.0, 0.0), 1.0)
	check(zombie.animation.current_animation == ZOMBIE.ATTACK
		and is_equal_approx(zombie.animation.current_animation_position, windup_position),
		"A hit below the poise threshold preserves an active windup")
	for i in Engine.physics_ticks_per_second:
		if lab.player_health < player_hp:
			break
		await physics_frame
	check(lab.player_health == player_hp - 6, "The active attack can still connect if the player stays in reach")
	zombie.free()
	await check_sword_finisher_push(lab, group)
	await check_sabre_landing_damage(lab, group)
	await check_coincident_sabre_landing(lab, group)
	await check_crowd(lab, group)
	await check_sabre_height_thresholds(lab, group)
	await check_sabre_edge_support(lab, group)
	lab.free()
	print("MECHANIC_LAB_KNOCKBACK first_chase_step=", first_chase_step,
		" travel=", furthest - at_contact, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_sword_finisher_push(lab, group) -> void:
	lab.reset_player()
	var selector := lab.get_node("HUD/Weapon") as OptionButton
	selector.select(1)
	selector.item_selected.emit(1)
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	zombie.health = 100
	zombie.max_health = 100
	await ticks(roundi(Engine.physics_ticks_per_second * 56.0 / 60.0))
	var hits: Array[Dictionary] = []
	var record := func(_point, direction, clip, index, _serial, _lethal):
		if index == 2:
			hits.append({"origin": zombie.global_position, "direction": direction, "clip": clip,
				"frame": Engine.get_physics_frames()})
	group.sabre_contact.connect(record)
	attack(true)
	for frame in ceili(Engine.physics_ticks_per_second * 3.0):
		await physics_frame
		if not hits.is_empty():
			break
	attack(false)
	group.sabre_contact.disconnect(record)
	check(hits.size() == 1 and zombie.health == 48, "Actual Sword combo leaves a living target on the third hit")
	if not hits.is_empty():
		var hit := hits[0]
		var travel := 0.0
		var stop_time := INF
		var remaining_lock := 0.0
		for frame in ceili(Engine.physics_ticks_per_second * 0.45):
			await physics_frame
			var displacement: Vector3 = zombie.global_position - hit.origin
			travel = maxf(travel, displacement.dot(hit.direction))
			if zombie._knockback == Vector3.ZERO:
				stop_time = float(Engine.get_physics_frames() - hit.frame) / Engine.physics_ticks_per_second
				remaining_lock = zombie._knockback_control_left
				break
		check(hit.clip == "Attack3" and stop_time >= 0.18 and stop_time <= 0.22 and remaining_lock > 0.14,
			"Sword's living target finishes its outward push while movement control is still locked")
		check(travel > 0.73 and travel < 0.79, "Sword's finisher keeps its calibrated outward travel")
		print("MECHANIC_LAB_SWORD_PUSH stop=", stop_time, " travel=", travel, " lock_left=", remaining_lock)
	zombie.free()
	lab.reset_player()
	await ticks(5)
	selector.select(0)
	selector.item_selected.emit(0)
	check(selector.selected == 0 and not group.sword_equipped, "Switch back to Sabre after the Sword combo ends")

func check_sabre_landing_damage(lab, group) -> void:
	lab.reset_player()
	await ticks(5)
	for i in 3:
		lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombies: Array[Node] = group.get_children()
	check(zombies.size() == 3, "The Sabre landing fixture has three targets")
	if zombies.size() != 3:
		return
	var origin: Vector3 = lab.player.global_position
	var forward: Vector3 = lab.player.visual.global_basis.z
	var right := Vector3.UP.cross(forward)
	var centre := origin + forward * 1.5
	for i in zombies.size():
		zombies[i].set_physics_process(false)
		zombies[i].global_position = centre + right * (2.0 if i == 1 else 0.0)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 1.5, 0.2)
	collider.shape = shape
	wall.add_child(collider)
	lab.add_child(wall)
	# Put the third zombie inside the primary radius with a wall on its ray.
	zombies[2].global_position = centre - right
	wall.global_position = origin.lerp(zombies[2].global_position, 0.5) + Vector3.UP * 0.65
	var landings: Array[int] = []
	var contacts: Array[int] = []
	var directions: Array[Vector3] = []
	var record_landing := func(_point, _serial): landings.append(Engine.get_physics_frames())
	var record_hit := func(_point, direction, clip, _index, _serial, _lethal):
		if clip == "AirAttack":
			contacts.append(Engine.get_physics_frames())
			directions.append(direction)
	group.sabre_landing.connect(record_landing)
	group.sabre_contact.connect(record_hit)
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(2)
	attack(true)
	await ticks(2)
	attack(false)
	for i in Engine.physics_ticks_per_second:
		await physics_frame
		if not landings.is_empty():
			break
	check(landings.size() == 1 and contacts.is_empty() and zombies[0].health == 48,
		"Actual Sabre landing triggers the floor effect before applying damage")
	if not landings.is_empty():
		# A new player position must not redirect an already landed strike.
		lab.player.global_position += right * 5.0
		await ticks(ceili(0.1 * Engine.physics_ticks_per_second) + 1)
		var offset_ticks := ceili(0.054369554 * Engine.physics_ticks_per_second)
		check(contacts == [landings[0] + offset_ticks, landings[0] + offset_ticks],
			"Primary and splash damage resolve on the first physics tick after the authored Sabre notify")
		check(zombies[0].health == 8 and zombies[1].health == 36 and zombies[2].health == 48,
			"Medium Sabre landing deals 40 primary and 12 splash damage, with wall occlusion")
		print("SABRE_NOTIFY touchdown=", landings, " contacts=", contacts,
			" health=", zombies.map(func(zombie): return zombie.health), " directions=", directions)
		check(not directions.is_empty() and directions[0].dot(forward) > 0.999,
			"The launched target uses the saved landing origin")
	group.sabre_landing.disconnect(record_landing)
	group.sabre_contact.disconnect(record_hit)
	wall.free()
	group.land_sabre(origin, forward, 999, 0.25)
	lab.reset_player()
	await ticks(ceili(0.1 * Engine.physics_ticks_per_second) + 1)
	check(zombies[0].health == 8, "Reset cancels a pending Sabre landing hit")
	for zombie in zombies:
		zombie.free()

func check_coincident_sabre_landing(lab, group) -> void:
	lab.reset_player()
	await ticks(5)
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	var origin: Vector3 = lab.player.global_position
	zombie.global_position = origin
	zombie.health = 8
	# Inject the touchdown event to align both centres exactly, independent of
	# the living colliders' separation. Capture the ragdoll's actual impulse.
	group.land_sabre(origin, Vector3.RIGHT, 998, 0.25)
	await ticks(ceili(0.1 * Engine.physics_ticks_per_second) + 1)
	check(zombie.health == 0, "The coincident zombie takes the full landing hit")
	zombie.set_physics_process(true)
	await ticks(2)
	var impulse: Vector3 = zombie.ragdoll.total_applied_impulse
	check(zombie.ragdoll.running and impulse.x > 0.0 and absf(impulse.z) < 0.001,
		"A coincident zombie is launched in the saved facing direction")
	print("SABRE_COINCIDENT_LANDING impulse=", impulse)
	zombie.free()

func check_sabre_height_thresholds(lab, group) -> void:
	var original_rate := Engine.physics_ticks_per_second
	var floor: StaticBody3D = lab.get_node("Ground")
	var original_floor_y := floor.position.y
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		var damage: Array[int] = []
		for height: float in [3.99, 4.0, 4.01, 6.49, 6.5, 6.51, 7.0]:
			floor.position.y = original_floor_y
			lab.reset_player()
			await ticks(8)
			lab.get_node("HUD/SpawnZombie").pressed.emit()
			var zombie = group.get_child(0)
			zombie.set_physics_process(false)
			var raised_support := 3.0 if height == 7.0 else 0.0
			zombie.global_position = Vector3(0.0, raised_support, 1.5)
			zombie.health = 100
			zombie.max_health = 100
			check(lab.player.drop_for_lab(height), "Sabre threshold fixture starts a real drop")
			floor.position.y += raised_support
			# Delay the attack so the measured apex precedes its input.
			await ticks(ceili(0.12 * hz))
			attack(true)
			await ticks(1)
			attack(false)
			for i in hz:
				await physics_frame
				if zombie.health < 100:
					break
			damage.append(100 - int(zombie.health))
			zombie.free()
		check(damage == [20, 40, 40, 40, 60, 60, 40],
			"The 4 m and 6.5 m thresholds use the actual support height at %d Hz" % hz)
		print("SABRE_HEIGHT_THRESHOLDS hz=", hz, " damage=", damage)
	floor.position.y = original_floor_y
	Engine.physics_ticks_per_second = original_rate

func check_sabre_edge_support(lab, group) -> void:
	var damage: Array[int] = []
	var strengths: Array[float] = []
	var landed_hits: Array[int] = []
	for sample in [Vector2(3.99, 50.20), Vector2(4.0, 50.01), Vector2(6.49, 50.20), Vector2(6.5, 50.01)]:
		lab.reset_player()
		lab.player.global_position = Vector3(49.99, 0.03, 0.0)
		await ticks(8)
		lab.get_node("HUD/SpawnZombie").pressed.emit()
		var zombie = group.get_child(0)
		zombie.set_physics_process(false)
		zombie.collision_layer = 0
		zombie.global_position = Vector3(49.70, 0.0, 1.5)
		zombie.max_health = 100
		zombie.health = 100
		check(lab.player.drop_for_lab(sample.x), "The player starts on the grass before the edge drop")
		# Move the capsule centre off the edge without changing the drop height.
		lab.player.global_position.x = sample.y
		await ticks(6)
		attack(true)
		await ticks(1)
		attack(false)
		for i in 45:
			await physics_frame
			if not group._pending_landings.is_empty():
				damage.append(int(group._pending_landings[0].strike.damage))
				strengths.append(float(group._pending_landings[0].strike.strength))
				break
		for i in 12:
			await physics_frame
			if zombie.health < 100:
				break
		landed_hits.append(100 - int(zombie.health))
		zombie.free()
	check(damage == [20, 40, 40, 60] and strengths == [1150.0, 1380.0, 1380.0, 1610.0],
		"Near both thresholds, the measured edge support controls damage and weapon strength")
	check(landed_hits == damage, "The edge slam applies the selected damage once to a nearby zombie")
	print("SABRE_EDGE_SUPPORT damage=", landed_hits, " strengths=", strengths)

func check_crowd(lab, group) -> void:
	lab.reset_player()
	for i in 6:
		lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombies := group.get_children() as Array[Node]
	check(zombies.size() == 6, "The crowd fixture spawns six zombies")
	if zombies.size() != 6:
		return
	await ticks(35)
	var origin: Vector3 = lab.player.global_position
	var forward: Vector3 = lab.player.visual.global_basis.z
	var right := Vector3.UP.cross(forward)
	var centre := origin + forward * 2.15
	zombies[0].global_position = centre
	zombies[0].health = 8
	for i in range(1, zombies.size()):
		var angle := (i - 1) * TAU / 5.0
		zombies[i].global_position = centre + (right * cos(angle) + forward * sin(angle)) * 0.88
	group.land_sabre(origin, forward, 1000, 0.25)
	var rise := 0.0
	var corpse_contacts := 0
	for frame in 45:
		await physics_frame
		for i in range(1, zombies.size()):
			var survivor := zombies[i] as CharacterBody3D
			rise = maxf(rise, survivor.global_position.y - origin.y)
			for contact in survivor.get_slide_collision_count():
				if survivor.get_slide_collision(contact).get_collider() is PhysicalBone3D:
					corpse_contacts += 1
	check(zombies[0].health == 0 and zombies[1].health > 0 and zombies[1].health < 48,
		"The same heavy attack kills one zombie and damages a survivor")
	check(rise < 0.03 and corpse_contacts == 0,
		"Ragdoll cannot lift a living zombie. Peak rise %.3f m, corpse contacts %d" % [rise, corpse_contacts])
	var falling := zombies[1] as CharacterBody3D
	falling.global_position = origin + Vector3(12.0, 1.0, 0.0)
	falling.velocity = Vector3.ZERO
	var fall_ticks := 0
	for frame in 36:
		await physics_frame
		fall_ticks += 1
		if falling.global_position.y - origin.y < 0.02:
			break
	check(fall_ticks <= ceili(0.25 * Engine.physics_ticks_per_second),
		"A living zombie returns from a 1 m drop within 250 ms, measured ticks %d" % fall_ticks)
