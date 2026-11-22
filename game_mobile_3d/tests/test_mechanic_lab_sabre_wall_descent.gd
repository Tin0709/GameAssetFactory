extends SceneTree

const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("FAIL ", label)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func check_sabre_sliding_down_one_wall() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.player.position = Vector3(-8, 0, -8)
	var wall := StaticBody3D.new()
	for dimensions in [[Vector3(4.5, 1.5, 0.0), Vector3(0.30, 3.0, 20.0)],
			[Vector3(-2.0, 1.5, 4.5), Vector3(12.7, 3.0, 0.30)]]:
		var shape := BoxShape3D.new()
		shape.size = dimensions[1]
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = dimensions[0]
		wall.add_child(collider)
	lab.add_child(wall)
	await ticks(2)
	var group := lab.get_node("Zombies")
	group._spawn_serial = 3711
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "The wall-slide fixture loads a source zombie")
		lab.free()
		return
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 402921
	var gap := rng.randf_range(0.85, 2.20)
	zombie.position = Vector3(4.35 - gap, 0.0, 4.35 - gap + rng.randf_range(-0.45, 0.45) * 0.12)
	zombie.rotation.y = rng.randf_range(-PI, PI)
	zombie.reset_physics_interpolation()
	var direction := Vector3(1, 0, 1).normalized().rotated(Vector3.UP, rng.randf_range(-0.20, 0.20))
	var phase := rng.randf_range(0.0, 1.0)
	await ticks(2)
	var clip: StringName = Zombie.WALK_CLIPS[2]
	zombie.animation.stop()
	zombie.ragdoll.skeleton.reset_bone_poses()
	zombie.animation.play(clip, 0.0)
	zombie.animation.advance(0.0)
	zombie.animation.seek(phase * zombie.animation.get_animation(clip).length, true)
	zombie.ragdoll.sample(1.0 / 60.0)
	zombie.ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, direction, Vector2.ZERO, 0.0, 800.0, Zombie.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)
	var landing := -1.0
	var maximum_gap := 0.0
	var floor_overlap := 0.0
	for tick in 224:
		await physics_frame
		if zombie._corpse_parked:
			break
		if not zombie.ragdoll.running:
			continue
		if landing < 0.0 and zombie._corpse_landed:
			landing = zombie._corpse_age
		maximum_gap = maxf(maximum_gap, zombie.ragdoll.max_anchor_error())
		floor_overlap = maxf(floor_overlap, -zombie.ragdoll.minimum_corner_y())
	check(is_equal_approx(landing, 68.0 / 60.0), "The slow wall slide keeps its original landing time")
	check(maximum_gap < 0.10 and floor_overlap < 0.013, "The wall slide keeps the joints and floor contact within tolerance")
	check(zombie._corpse_parked, "An unstable Sabre corpse rolls off the wall within 3.74 seconds")
	print("LAB_SABRE_SINGLE_WALL_SLIDE landing=", landing, " gap=", maximum_gap,
		" overlap=", floor_overlap, " parked=", zombie._corpse_parked, " seconds=", zombie._corpse_age)
	lab.free()


func run() -> void:
	await check_sabre_sliding_down_one_wall()
	quit(0 if failures.is_empty() else 1)
