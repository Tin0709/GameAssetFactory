extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	var absent := "absent" in OS.get_cmdline_user_args()
	root.add_child(world)
	current_scene = world
	await process_frame
	var plants := world.get_node_or_null("ForestUnderstory") as Node3D
	var toggle := world.find_child("ForestUnderstoryToggle", true, false) as CheckButton
	if absent:
		check(plants == null and toggle == null, "Unsupported or missing source adds no private assets")
	else:
		check(plants != null and toggle != null and toggle.button_pressed, "WorldMap enables the Forest understory by default")
		if plants != null and toggle != null:
			check(plants.find_children("*", "CollisionObject3D", true, false).is_empty(), "Private vegetation leaves collision unchanged")
			var sectors := {}
			var materials := {}
			var cells := {}
			var total := 0
			var mushrooms := {}
			var mushroom_material: ShaderMaterial
			for child in plants.get_children():
				var batch := child as MultiMeshInstance3D
				check(batch != null, "The understory adds only instanced visuals")
				if batch == null:
					continue
				materials[batch.material_override] = true
				check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Cutout plants cast shadows")
				var mushroom := batch.name in [&"BrownMushrooms", &"RedMushrooms"]
				if mushroom:
					mushroom_material = batch.material_override
					mushrooms[batch.name] = {}
				for index in batch.multimesh.instance_count:
					var pose := batch.multimesh.get_instance_transform(index)
					var center := (pose * batch.multimesh.mesh.get_aabb()).get_center()
					sectors[Vector2i(signf(center.x), signf(center.z))] = true
					var slot := Vector2i(floori(center.x), floori(center.z))
					check(not cells.has(slot), "Each placement has its own cell")
					cells[slot] = true
					if mushroom:
						mushrooms[batch.name][Vector2i(signf(center.x), signf(center.z))] = true
						var ground: float = world.surface_height(pose.origin.x, pose.origin.z)
						check(is_equal_approx(pose.origin.y, ground), "Mushrooms are seated on the rock cap")
						check(batch.multimesh.get_instance_custom_data(index) == Color(0., 0., 0., 0.),
							"Rigid mushrooms keep their mesh normals and receive no plant sway")
					total += 1
			check(total == 42 and sectors.size() == 4 and plants.get_child_count() == 6, "Six variants cover all four sectors")
			check(mushrooms.size() == 2, "Both source mushroom shapes appear")
			for coverage: Dictionary in mushrooms.values():
				check(coverage.size() == 4, "Each mushroom shape appears in all four sectors")
			check(materials.size() == 3, "Variants share three material/atlas sets")
			var grass = world.showcase.plants
			var fern_material: ShaderMaterial = grass.bundle.meshes[grass.forest_fern_asset].surface_get_material(0)
			check(mushroom_material != null and mushroom_material.get_shader_parameter("source_atlas") ==
				fern_material.get_shader_parameter("atlas"), "Mushrooms reuse the verified ForestA1 atlas")
			var moss_atlas: Texture2D = world.showcase.forest_moss.material.get_shader_parameter("source_atlas")
			var shared_atlas_count := 0
			for material in materials:
				check(world.showcase._mist_materials().has(material), "The material receives the shared fog")
				if material.get_shader_parameter("source_atlas") == moss_atlas:
					shared_atlas_count += 1
			check(shared_atlas_count == 1, "The hanging moss reuses the verified ledge moss texture")
			toggle.button_pressed = false
			check(not plants.visible, "Settings can isolate the understory")
			for material in materials:
				check(not world.showcase._mist_materials().has(material), "Hidden plants are removed from fog updates")
			toggle.button_pressed = true
			check(plants.visible, "Settings restore the understory")
	world.free()
	await process_frame
	print("FOREST_UNDERSTORY failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
