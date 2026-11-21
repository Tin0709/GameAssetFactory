extends SceneTree

const LAB = preload("res://scenes/dev/MechanicLab.tscn")
const Zombie = preload("res://scripts/mechanic_lab_zombie.gd")
const COUNT := 100
const WALK_COLLISION_MASK := Zombie.LEVEL_COLLISION_MASK | 2 | Zombie.LIVING_ZOMBIE_LAYER

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await check_patrol(119, 1)
	await check_patrol(127, 2)
	print("PATROL_FLOOR_REGRESSION failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_patrol(serial: int, start_phase: int) -> void:
	var lab := LAB.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.reset_player()
	lab.player.set_physics_process(false)
	var wall := StaticBody3D.new()
	var wall_collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.30, 3.0, 96.0)
	wall_collision.shape = box
	wall.add_child(wall_collision)
	wall.position = Vector3(4.5, 1.5, 0.0)
	lab.add_child(wall)
	await physics_frame

	var group := lab.get_node("Zombies")
	group._spawn_serial = serial
	# Start the entire patrol together regardless of when the HUD spawns each batch.
	var hold := func(zombie: Node):
		zombie.ready.connect(func(): zombie.set_physics_process(false), CONNECT_ONE_SHOT)
	group.child_entered_tree.connect(hold)
	lab.get_node("HUD/SpawnCrowd").pressed.emit()
	for frame in 180:
		await process_frame
		if group.get_child_count() == COUNT:
			break
	group.child_entered_tree.disconnect(hold)
	if group.get_child_count() != COUNT:
		failures.append("The floor fixture must spawn all 100 zombies")
		lab.free()
		return

	lab.player.global_position = Vector3(34.0, 0.02, 34.0)
	for frame in 16:
		if Engine.get_physics_frames() % 8 == start_phase:
			break
		await process_frame
	for zombie: Zombie in group.get_children():
		zombie.set_physics_process(true)

	var misses := PackedInt32Array()
	misses.resize(COUNT)
	var longest := 0
	var fastest_false_fall := 0.0
	for tick in 310:
		await physics_frame
		if tick < 79:
			continue
		for index in COUNT:
			var zombie := group.get_child(index) as Zombie
			if zombie.is_on_floor() or absf(zombie.global_position.y) > zombie.safe_margin:
				misses[index] = 0
				continue
			misses[index] += 1
			longest = maxi(longest, misses[index])
			fastest_false_fall = maxf(fastest_false_fall, -zombie.velocity.y)
	print("PATROL_FLOOR_SAMPLE serial=", serial, " missed_ticks=", longest,
		" max_false_fall_m_s=", fastest_false_fall)
	if longest > 2 or fastest_false_fall > 1.7:
		failures.append("A supported patrol should not accumulate a fall beside a neighboring capsule (%d)" % serial)
	for zombie: Zombie in group.get_children():
		if zombie.collision_mask != WALK_COLLISION_MASK:
			failures.append("The patrol keeps its movement collision mask")
			break

	# A new capsule starts without the patrol's stored floor or blocker contacts.
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var airborne := group.get_child(COUNT) as Zombie
	airborne.global_position = Vector3(20.0, 0.30, 20.0)
	airborne.animation.play(Zombie.IDLE)
	airborne.reset_physics_interpolation()
	for tick in 3:
		await physics_frame
	if airborne.is_on_floor() or airborne.global_position.y <= 0.1 or airborne.velocity.y >= 0.0:
		failures.append("A genuinely airborne patrol still falls")
	lab.free()
	await physics_frame

