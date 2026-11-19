extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	var fallback := "fallback" in OS.get_cmdline_user_args()
	if fallback:
		world.set("forest_moss_placements", PackedVector4Array())
	root.add_child(world)
	current_scene = world
	await process_frame
	var moss := world.get_node_or_null("ForestLedgeMoss") as Node3D
	var toggle := world.find_child("ForestLedgeMossToggle", true, false) as CheckButton
	if fallback:
		check(moss == null and toggle == null, "An unconfigured map adds no moss or settings row")
	else:
		check(moss != null and toggle != null and toggle.button_pressed, "F5 places verified moss and enables its settings row")
		if moss != null and toggle != null:
			var quadrants := {}
			var total := 0
			var materials := {}
			for batch: MultiMeshInstance3D in moss.get_children():
				var mesh: MultiMesh = batch.multimesh
				var material := batch.material_override as ShaderMaterial
				materials[material] = true
				check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Moss casts alpha-tested shadows")
				for i in mesh.instance_count:
					var pose := mesh.get_instance_transform(i)
					var bounds := pose * mesh.mesh.get_aabb()
					var center := bounds.get_center()
					quadrants[Vector2i(signf(center.x), signf(center.z))] = true
					var ground: float = world.surface_height(center.x, center.z)
					check(bounds.position.y < ground and bounds.end.y > ground and bounds.end.y - ground < .3, "Moss straddles its ledge surface")
				total += mesh.instance_count
			check(total == 14 and quadrants.size() == 4 and moss.get_child_count() == 2, "Two source meshes form 14 grounded patches in four sectors")
			check(materials.size() == 1, "Both batches share one lit material and atlas")
			if materials.size() == 1:
				check(world.showcase._mist_materials().has(materials.keys()[0]), "The default foliage receives the shared mist")
			toggle.button_pressed = false
			check(not moss.visible and not world.showcase._mist_materials().has(materials.keys()[0]), "Comparison disables the moss and removes its receiver")
			toggle.button_pressed = true
			check(moss.visible, "The settings row restores both batches")
	world.free()
	await process_frame
	print("FOREST_LEDGE_MOSS failures=", JSON.stringify(failures), " count=", failures.size())
	quit(0 if failures.is_empty() else 1)
