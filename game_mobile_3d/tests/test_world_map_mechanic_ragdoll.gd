extends SceneTree

const Zombies := preload("res://scripts/mechanic_lab_zombies.gd")
const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func launch(world: Node3D, group: Node3D, effects: Node3D, start: Vector3, direction: Vector3) -> Node3D:
	if not group.spawn(world.player, Basis.IDENTITY, effects):
		check(false, "The verified zombie is available on WorldMap")
		return null
	var zombie = group.get_child(0)
	zombie.set_physics_process(false)
	zombie.global_position = start + Vector3.UP * 0.02
	zombie.rotation.y = 0.0
	zombie.animation.play(Zombie.IDLE)
	zombie.animation.advance(0.2)
	zombie.reset_physics_interpolation()
	await ticks(2)
	for i in 2:
		zombie.ragdoll.sample(1.0 / 60.0)
	zombie.take_hit(100, direction, Vector2.ZERO, 0.0, 800.0, Zombie.DeathStrike.SABRE_FINISHER)
	zombie.set_physics_process(true)
	return zombie

func cliff_case(world: Node3D, group: Node3D, effects: Node3D) -> void:
	var zombie = await launch(world, group, effects, Vector3(-37.5, 3.0, -33.5), Vector3.FORWARD)
	if zombie == null:
		return
	var first_wall := -1
	var first_landing := -1
	var supported_without_torso := false
	var wall_gravity := 0.0
	var settled_gravity := 0.0
	for frame in 135:
		await physics_frame
		if not zombie.ragdoll.running:
			break
		var contact: Dictionary = zombie.ragdoll.contact_motion()
		supported_without_torso = supported_without_torso or (contact.supports >= 2 and contact.core_supports == 0)
		if zombie._corpse_landed and first_landing < 0:
			first_landing = frame
		var chest: PhysicalBone3D = zombie.ragdoll.bodies.Chest
		var chest_state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
		settled_gravity = chest_state.total_gravity.y
		for part: PhysicalBone3D in zombie.ragdoll.bodies.values():
			var state := PhysicsServer3D.body_get_direct_state(part.get_rid())
			for i in state.get_contact_count():
				var collider := state.get_contact_collider_object(i) as Node
				var is_wall := absf(state.get_contact_local_normal(i).y) < 0.05
				if first_wall < 0 and collider != null and collider.name == "WorldCollision" and is_wall:
					first_wall = frame
					wall_gravity = chest_state.total_gravity.y
	check(first_wall >= 0 and is_equal_approx(wall_gravity, -50.0),
		"The authored rock wall transfers a side impact while flight gravity is active")
	check(supported_without_torso and first_landing > first_wall and first_landing < 90,
		"Stable support at the foot of the cliff starts landing within 1.5 s")
	check(settled_gravity > -30.0, "A supported body leaves its flight-gravity state")
	print("WORLDMAP_CLIFF wall=", first_wall, " landing=", first_landing, " gravity=", settled_gravity)
	zombie.free()
	await ticks(2)

func ledge_case(world: Node3D, group: Node3D, effects: Node3D) -> void:
	var zombie = await launch(world, group, effects, Vector3(-33.5, 9.0, -39.5), Vector3.RIGHT)
	if zombie == null:
		return
	var first_landing := -1
	var chest_height := INF
	var worst_anchor := 0.0
	var ledge_contact := false
	for frame in 72:
		await physics_frame
		if not zombie.ragdoll.running:
			continue
		worst_anchor = maxf(worst_anchor, zombie.ragdoll.max_anchor_error())
		var chest: PhysicalBone3D = zombie.ragdoll.bodies.Chest
		chest_height = minf(chest_height, chest.global_position.y)
		for name in ["Head", "Chest"]:
			var part: PhysicalBone3D = zombie.ragdoll.bodies[name]
			var state := PhysicsServer3D.body_get_direct_state(part.get_rid())
			for i in state.get_contact_count():
				var collider := state.get_contact_collider_object(i) as Node
				if collider != null and collider.name == "WorldCollision" and state.get_contact_local_normal(i).y > 0.8:
					ledge_contact = true
		if zombie._corpse_landed and first_landing < 0:
			first_landing = frame
	check(first_landing > 25 and first_landing < 55 and ledge_contact and chest_height < 6.0,
		"The corpse crosses the authored ledge and contacts the lower terrain")
	check(worst_anchor < 0.085, "The first impact on the lower terrace keeps the limb anchors connected")
	print("WORLDMAP_LEDGE landing=", first_landing, " minimum_chest_y=", chest_height, " peak_anchor_m=", worst_anchor)
	zombie.free()

func run() -> void:
	var world = preload("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(12)
	check(world.map_ready, "The real WorldMap collision geometry loads")
	if world.map_ready:
		var group := Zombies.new()
		var effects := Node3D.new()
		world.add_child(effects)
		world.add_child(group)
		await cliff_case(world, group, effects)
		await ledge_case(world, group, effects)
	world.free()
	print("WORLD_MAP_MECHANIC_RAGDOLL failures=", failures)
	quit(0 if failures.is_empty() else 1)
