extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var plants = world.showcase.plants
	check(plants != null and plants.has_method("set_forest_cover"), "F5 Forest can toggle the extra source plants")
	if plants != null and plants.has_method("set_forest_cover"):
		var batches: int = plants.batch_count
		var by_asset := {}
		var occupied := {}
		var quadrants := {}
		var saved := {}
		for row: Dictionary in plants.placements:
			check(not occupied.has(row.cell), "Each terrain block has one rooted plant")
			occupied[row.cell] = true
			if not row.get("forest_cover", false):
				saved[row.cell] = row
				continue
			by_asset[row.asset] = int(by_asset.get(row.asset, 0)) + 1
			quadrants[Vector2i(signi(row.cell.x), signi(row.cell.y))] = true
			var surface: float = world.surface_height(row.root.x, row.root.z)
			var map_pixel := Vector2i(Vector2(row.cell) - world.look.path_map_origin)
			var path_mask := int(roundf(world.look.path_map_image.get_pixelv(map_pixel).r)) & 255
			check(path_mask == 0 and absf(surface - row.bounds.position.y) < .002, "Every added asset sits on its grass block off the path")
			check(row.bounds.size.y > .7 and row.bounds.size.y < 1.8, "Cover grass is proportional to the player")
		check(by_asset.size() == 3 and quadrants.size() >= 4, "Medium and tall ForestA1 species appear across the map")
		check(occupied.size() == plants.eligible_grass_cells, "Dense coverage stays consistent")
		for asset: String in by_asset:
			var material: ShaderMaterial = plants.bundle.meshes[asset].surface_get_material(0)
			check(material.get_shader_parameter("native_grass_albedo") == true, "The plant uses verified Forest atlas color")
			if plants.grass_light.supported():
				check(plants.grass_light._records.any(func(row: Dictionary) -> bool: return row.material == material),
					"Every ForestA1 species uses the shared grass lighting pipeline")
		plants.set_forest_cover(false)
		check(plants.placements.size() == occupied.size(), "Disabling replaces the variants with regular dense grass")
		check(batches <= plants.batch_count + by_asset.size(), "Sparse additions use one batch per species")
		for row: Dictionary in plants.placements:
			if saved.has(row.cell):
				var before: Dictionary = saved[row.cell]
				check(row.asset == before.asset and row.root == before.root and row.bounds == before.bounds, "A/B keeps other plant transforms")
		plants.set_forest_cover(true)
		check(plants.snapshot().get("forest_cover_species", {}) == by_asset, "Restoring cover is deterministic")
	world.free()
	await process_frame
	print("FOREST_COVER_PLANTING failures=", JSON.stringify(failures.slice(0, 10)), " count=", failures.size())
	quit(0 if failures.is_empty() else 1)
