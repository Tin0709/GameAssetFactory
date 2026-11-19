extends SceneTree

const KEYS := [&"forest_canopy_extension_profile", &"forest_canopy_extension_sha256"]
const ROOTS := [Vector3(27.5, 3., -28.5), Vector3(32.5, 3., -17.5),
	Vector3(25.5, 3., 20.5), Vector3(38.5, 3., 33.5)]
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func make_world(invalid_hash: bool) -> Node3D:
	var world := (load("res://scenes/WorldMap.tscn") as PackedScene).instantiate() as Node3D
	if invalid_hash and world.get(KEYS[0]) != null:
		world.set(KEYS[1], "f".repeat(64))
	root.add_child(world)
	current_scene = world
	return world

func run() -> void:
	var world := make_world(false)
	await process_frame
	var native := RenderingServer.get_current_rendering_method() == &"mobile" and RenderingServer.get_rendering_device() != null
	check(world.get(KEYS[0]) is String and not String(world.get(KEYS[0])).is_empty(), "F5 requests the verified east canopy")
	var sky := world.get_node("SpruceSkyVisibility")
	var grove: Node3D = world.grove
	if native and sky.proof_ready:
		await physics_frame
		check(sky._dimensions.x == 104 and sky._dimensions.z == 99, "F5 publishes the expanded field")
		check(sky._geometry_current() and world.showcase.directional_air._geometry_current(), "Both light proofs match their geometry")
		for i in ROOTS.size():
			var tree := world.get_node_or_null("ForestSpruce/EastSpruce%02d" % (i + 1)) as Node3D
			check(tree != null and tree.global_position == ROOTS[i], "F5 places the validated tree %d" % (i + 1))
			if tree != null:
				var trunk := tree.get_node("Trunk") as StaticBody3D
				check(trunk.collision_layer == 1, "A visible tree has a solid trunk")
				var midpoint := tree.global_position + Vector3.UP
				var query := PhysicsRayQueryParameters3D.create(midpoint + Vector3.BACK, midpoint + Vector3.FORWARD, 1)
				var contact := world.get_world_3d().direct_space_state.intersect_ray(query)
				check(contact.get("collider") == trunk, "The trunk stops a horizontal probe above the grass")
				var shadows := tree.find_children("*Shadow", "MeshInstance3D", true, false)
				check(shadows.size() == 1 and shadows[0].material_override == grove._spruce_shadow,
					"East spruce reuses the live Forest shadow caster")
		check(world.showcase.mist.effect.sky_grid == sky._texture, "Fog samples the same field as vegetation")
	elif grove != null and grove.spruce_available():
		check(world.get_node_or_null("ForestSpruce/EastSpruce01") == null, "Unsupported renderer retains its existing grove")
	world.free()
	await process_frame
	if native:
		var fallback := make_world(true)
		await process_frame
		var fallback_sky := fallback.get_node("SpruceSkyVisibility")
		if fallback_sky.proof_ready:
			check(fallback_sky._dimensions.x == 53 and fallback.get_node_or_null("ForestSpruce/EastSpruce01") == null,
				"Corrupt profile falls back to the complete original grove")
		fallback.free()
		await process_frame
	print("EAST_CANOPY_TEST failures=", JSON.stringify(failures), " renderer=", RenderingServer.get_current_rendering_method())
	quit(0 if failures.is_empty() else 1)
