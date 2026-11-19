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
			var sectors := {}
			var materials := {}
			var cells := {}
			var total := 0
			for child in plants.get_children():
				var batch := child as MultiMeshInstance3D
				check(batch != null, "The understory adds only instanced visuals")
				if batch == null:
					continue
				materials[batch.material_override] = true
				check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Cutout plants cast shadows")
				for index in batch.multimesh.instance_count:
					var pose := batch.multimesh.get_instance_transform(index)
					var center := (pose * batch.multimesh.mesh.get_aabb()).get_center()
					sectors[Vector2i(signf(center.x), signf(center.z))] = true
					var slot := Vector2i(floori(center.x), floori(center.z))
					check(not cells.has(slot), "Each placement has its own cell")
					cells[slot] = true
					total += 1
			check(total >= 20 and sectors.size() == 4 and plants.get_child_count() == 4, "Four variants are scattered across all four sectors")
			check(materials.size() == 2, "Variants share two material/atlas sets")
			for material in materials:
				check(world.showcase._mist_materials().has(material), "The material receives the shared fog")
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
