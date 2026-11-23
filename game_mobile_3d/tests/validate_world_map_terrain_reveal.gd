extends SceneTree

const GateCases := [
	[Vector2(42.5, 33.5), 0.0],
	[Vector2(44.5, -10.5), 0.0],
	[Vector2(44.5, 34.5), 1.0],
	[Vector2(45.5, -16.5), 1.0],
	[Vector2(-7.5, 45.5), 1.0],
	[Vector2(-21.5, 13.5), 0.0],
]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = world.get_node("Camera3D")
	var geometry: Node = world.geometry
	var failures: Array[String] = []
	if geometry.has_method("cutaway_visibility"):
		for item: Array in GateCases:
			var at: Vector2 = item[0]
			var feet := Vector3(at.x, world.surface_height(at.x, at.y) + .02, at.y)
			camera.position = feet + world.CAMERA_OFFSET
			var actual: float = geometry.cutaway_visibility(feet, camera)
			if not is_equal_approx(actual, item[1]):
				failures.append("%s uses weight %s, expected %s" % [at, actual, item[1]])
	else:
		failures.append("The cutaway does not evaluate upper-body occlusion.")
	print("TERRAIN_REVEAL cases=", GateCases.size(), " failures=", failures)
	world.free()
	quit(0 if failures.is_empty() else 1)
