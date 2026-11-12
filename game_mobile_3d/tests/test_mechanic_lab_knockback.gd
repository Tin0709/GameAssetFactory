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
	lab.free()
	print("MECHANIC_LAB_KNOCKBACK first_chase_step=", first_chase_step,
		" travel=", furthest - at_contact, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
