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

func wait_for_windup(zombie) -> void:
	for i in 120:
		if zombie.animation.current_animation == ZOMBIE.ATTACK and zombie.animation.current_animation_position >= 0.15:
			return
		await physics_frame

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group := lab.get_node("Zombies")
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	check(group.get_child_count() == 1, "A verified zombie is available in the lab")
	if group.get_child_count() != 1:
		lab.free()
		quit(1)
		return
	var zombie = group.get_child(0)
	zombie.health = 100
	zombie.max_health = 100
	await wait_for_windup(zombie)
	check(zombie.animation.current_animation == ZOMBIE.ATTACK, "The zombie starts a real melee windup")
	zombie.take_hit(12, Vector3.BACK, Vector2.ZERO, 23.0)
	check(zombie.animation.current_animation == ZOMBIE.ATTACK, "A single Sabre hit stays below 28 poise")
	zombie.take_hit(14, Vector3.BACK, Vector2.ZERO, 23.0)
	check(zombie.animation.current_animation == ZOMBIE.STAGGER, "The second Sabre hit breaks poise and cancels the windup")
	var start_frame := Engine.get_physics_frames()
	var half_duration := roundi(0.25 * Engine.physics_ticks_per_second)
	await ticks(half_duration)
	var pose_time: float = zombie.animation.current_animation_position
	zombie.take_hit(20, Vector3.BACK, Vector2.ZERO, 37.0)
	check(zombie.health == 54 and is_equal_approx(zombie.animation.current_animation_position, pose_time),
		"Another poise-breaking hit deals damage without restarting stagger")
	for i in Engine.physics_ticks_per_second:
		if zombie.animation.current_animation != ZOMBIE.STAGGER:
			break
		await physics_frame
	var elapsed := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second
	check(absf(elapsed - 0.65) <= 1.0 / Engine.physics_ticks_per_second + 0.0001,
		"The original stagger ends after 0.65 s (measured %.4f)" % elapsed)
	check(lab.player_health == 100, "The interrupted windup never damages the player")
	await wait_for_windup(zombie)
	check(zombie.animation.current_animation == ZOMBIE.ATTACK, "Zombie resumes attacking after stagger")
	lab.free()
	print("MECHANIC_LAB_STAGGER duration=", elapsed, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
