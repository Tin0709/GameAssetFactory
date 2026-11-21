extends SceneTree

const Lab := preload("res://scenes/dev/MechanicLab.tscn")
const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")

func _initialize() -> void:
	run.call_deferred()

func add_face(wall: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = center
	wall.add_child(collider)

func run() -> void:
	var lab := Lab.instantiate()
	root.add_child(lab)
	current_scene = lab
	lab.player.set_physics_process(false)
	lab.player.position = Vector3(-8.0, 0.0, -8.0)
	var wall := StaticBody3D.new()
	add_face(wall, Vector3(4.5, 1.5, 0.0), Vector3(0.30, 3.0, 20.0))
	add_face(wall, Vector3(-2.0, 1.5, 4.5), Vector3(12.7, 3.0, 0.30))
	lab.add_child(wall)
	await physics_frame
	await physics_frame
	var group := lab.get_node("Zombies")
	group._spawn_serial = 3702
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		printerr("The balanced arm brace requires a source zombie")
		quit(1)
		return
	var zombie := group.get_child(0) as Zombie
	zombie.set_physics_process(false)
	zombie.position = Vector3(3.64464592933655, 0.0, 3.61663365364075)
	zombie.rotation.y = -0.64799427986145
	zombie.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	zombie.animation.stop()
	zombie.ragdoll.skeleton.reset_bone_poses()
	zombie.animation.play(&"Zombie_Walk_Variant2", 0.0)
	zombie.animation.advance(0.0)
	zombie.animation.seek(0.268070517546244, true)
	zombie.ragdoll.sample(1.0 / 60.0)
	zombie.ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, Vector3(0.698510825634003, 0.0, 0.715599477291107),
		Vector2.ZERO, 0.0, 800.0, Zombie.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)

	var balanced := false
	for tick in 294:
		await physics_frame
		if zombie._corpse_parked:
			break
		if tick < 200 or balanced or not zombie.ragdoll.running:
			continue
		var motion := zombie.ragdoll.contact_motion()
		balanced = motion.supports == 2 and motion.core_supports == 0 and motion.leg_supported \
			and zombie.ragdoll.terrain_support_margin(true) > 0.012 \
			and not zombie.ragdoll.has_flat_wall_rest_support(false)
	var passed := balanced and zombie._corpse_parked and zombie.ragdoll.bodies.is_empty()
	print("MECHANIC_LAB_BALANCED_ARM_REST balanced=", balanced, " parked=", zombie._corpse_parked,
		" seconds=", zombie._corpse_age, " passed=", passed)
	quit(0 if passed else 1)
