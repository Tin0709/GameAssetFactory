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
	await check_crowd(lab, group)
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
	selector.select(0)
	selector.item_selected.emit(0)

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
