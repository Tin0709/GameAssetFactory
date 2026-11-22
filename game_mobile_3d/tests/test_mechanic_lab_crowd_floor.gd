extends SceneTree

const LAB := preload("res://scenes/dev/MechanicLab.tscn")
const ZOMBIE := preload("res://scripts/mechanic_lab_zombie.gd")
const COUNT := 100

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.player_health = 10000
	var group := lab.get_node("Zombies")
	var result: Dictionary = group.spawn_batch(lab.player, Basis.IDENTITY, lab.get_node("CombatEffects"),
		true, COUNT, 9223372036854775807)
	if result.count != COUNT:
		printerr("Crowd floor fixture requires 100 zombies")
		quit(1)
		return

	# A narrow V approach and traffic from either side create the packed contact.
	for i in COUNT:
		var zombie := group.get_child(i) as ZOMBIE
		zombie.set_physics_process(false)
		if i < 16:
			zombie.global_position = Vector3((i % 4 - 1.5) * 1.15, 0.02, -3.25 - floorf(i / 4.0) * 1.2)
		else:
			var side := 1.0 if i % 2 == 0 else -1.0
			zombie.global_position = Vector3(side * (6.8 + i % 7 * 1.25), 0.02, 2.0 + floorf((i - 16) / 14.0) * 1.35)
		zombie.animation.play(ZOMBIE.IDLE, 0.0)
		zombie.animation.advance(0.0)
	var tip := Vector3(-0.093521, 0.0, -2.12)
	for end: Vector3 in [Vector3(-2.585104, 0.0, -3.993645), Vector3(2.028336, 0.0, -3.993645)]:
		add_wall(lab, tip, end)
	var stride := roundi(Engine.physics_ticks_per_second / ZOMBIE.LAB_CROWD_SIGHT_HZ)
	while Engine.get_physics_frames() % stride != 1:
		await physics_frame
	for zombie: ZOMBIE in group.get_children():
		zombie.set_physics_process(true)

	var streak := PackedInt32Array()
	streak.resize(COUNT)
	var max_streak := 0
	var max_fall_speed := 0.0
	for tick in 620:
		await physics_frame
		for zombie: ZOMBIE in group.get_children():
			var i := zombie.get_index()
			if zombie._target_aggressive and not zombie.is_on_floor() and absf(zombie.position.y) <= zombie.safe_margin:
				streak[i] += 1
				max_streak = maxi(max_streak, streak[i])
				max_fall_speed = maxf(max_fall_speed, -zombie.velocity.y)
			else:
				streak[i] = 0

	var passed := group.get_child_count() == COUNT and lab.player_health < 10000
	# Allow a brief physics contact transition, but no accumulating fall on the grass.
	passed = passed and max_streak <= 2 and max_fall_speed <= 2.6
	print("CROWD_PURSUIT_FLOOR living=", group.get_child_count(), " player_hp=", lab.player_health,
		" max_off_floor_ticks=", max_streak, " fall_mps=", max_fall_speed, " passed=", passed)
	lab.free()
	quit(0 if passed else 1)

func add_wall(lab: Node3D, start: Vector3, end: Vector3) -> void:
	var side := end - start
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(side.length(), 0.43, 0.22)
	collider.shape = box
	wall.add_child(collider)
	wall.position = (start + end) * 0.5 + Vector3.UP * 0.215
	wall.rotation.y = atan2(-side.z, side.x)
	lab.add_child(wall)
