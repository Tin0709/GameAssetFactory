extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func run() -> void:
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var fern := world.find_child("ForestFernToggle", true, false) as CheckButton
	var vine := world.find_child("ForestWallVinesToggle", true, false) as CheckButton
	var wall := world.get_node_or_null("ForestWallVines") as Node3D
	if "absent" in OS.get_cmdline_user_args():
		check(fern == null and vine == null and wall == null, "Private flora is absent without supported local source")
	else:
		check(fern != null and fern.button_pressed, "F5 enables verified Forest ferns by default")
		check(vine != null and vine.button_pressed and wall != null, "F5 enables verified Forest wall vines by default")
		if fern != null:
			test_carpet(world, fern)
		if wall != null and vine != null:
			test_wall(world, wall, vine)
	world.free()
	await process_frame
	print("FOREST_FLORA failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func test_carpet(world: Node3D, toggle: CheckButton) -> void:
	var plants: Node3D = world.showcase.plants
	var sectors := {}
	var rooted := {}
	var count := 0
	var assets := {}
	for row: Dictionary in plants.placements:
		check(not rooted.has(row.cell), "Only one plant grows in each grass cell")
		rooted[row.cell] = row
		if not row.get("forest_fern", false):
			continue
		if not assets.has(row.asset):
			assets[row.asset] = {}
		assets[row.asset][Vector2i(signi(row.cell.x), signi(row.cell.y))] = true
		if not String(row.asset).ends_with("SM_SF_Fern_Small"):
			check(row.bounds.size.x <= 1. and row.bounds.size.z <= 1.,
				"New fern fronds fit within the cell occupied by their root")
		count += 1
		sectors[Vector2i(signi(row.cell.x), signi(row.cell.y))] = true
		var pixel := Vector2i(Vector2(row.cell) - world.look.path_map_origin)
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var flags := roundi(world.look.path_map_image.get_pixelv(pixel + offset).r) & 255
			check(flags == 0, "Ferns keep the path and its immediate margin clear")
		check(absf(world.surface_height(row.root.x, row.root.z) - row.bounds.position.y) < .002,
			"Fern roots rest on the terrain")
	check(count == 88 and assets.size() == 3 and sectors.size() == 4,
		"Three fern shapes occupy 88 authored cells across all four sectors")
	for asset: String in assets:
		check(assets[asset].size() == 4, "Each fern shape grows in all four sectors")
		var material: ShaderMaterial = plants.bundle.meshes[asset].surface_get_material(0)
		check(material.get_shader_parameter("native_grass_albedo") == true, "Fern keeps its verified source color")
		check(world.showcase._mist_materials().has(material), "Fern participates in shared mist")
		check(plants.grass_light._records.any(func(record: Dictionary) -> bool: return record.material == material),
			"Fern participates in shared grass lighting")
	test_fern_night_response(world, plants, assets)
	var spring = plants.interaction
	var point: Vector3 = world.player.global_position
	for step in 8:
		spring.advance(1. / 60., point + Vector3.RIGHT * float(step) * .1, Vector3.RIGHT * 6.)
	var motion: PackedByteArray = spring.pixels
	var previous: PackedByteArray = spring.previous_pixels
	var revision: int = spring.revision
	check(not spring.active.is_empty(), "The test generates live plant contact")
	toggle.button_pressed = false
	check(plants.placements.size() == rooted.size(), "Toggling ferns keeps the dense carpet")
	for row: Dictionary in plants.placements:
		var before: Dictionary = rooted.get(row.cell, {})
		check(not before.is_empty() and not row.get("forest_fern", false), "The former fern cells return to grass")
		if not before.is_empty() and not before.get("forest_fern", false):
			check(row.asset == before.asset and row.bounds == before.bounds, "Toggling ferns preserves other plants")
	toggle.button_pressed = true
	check(plants.placements.filter(func(row: Dictionary) -> bool: return row.get("forest_fern", false)).size() == count,
		"Restoring the ferns gives the same placement count")
	check(spring.revision == revision and spring.pixels == motion and spring.previous_pixels == previous,
		"Changing the fern comparison preserves the live grass bend")

func test_fern_night_response(world: Node3D, plants: Node3D, assets: Dictionary) -> void:
	var previous_hour: float = world.showcase.hour
	for hour: float in [12., 16.5, 19.5, 22.]:
		world.showcase.set_hour(hour)
		plants.grass_light.sync()
		var turf: float = world.showcase.grass_night_albedo_mix()
		check((turf == 0.) == (hour <= 16.5), "The turf tint runs only during twilight and night")
		for asset: String in assets:
			var material: ShaderMaterial = plants.bundle.meshes[asset].surface_get_material(0)
			var expected := turf if asset.ends_with("SM_SF_Fern_Small") else turf * .5
			check(is_equal_approx(material.get_shader_parameter("study_grass_night_albedo"), expected),
				"The two generic fern shapes retain more source pigment at %s" % hour)
		for asset: String in plants.forest_cover_species:
			var material: ShaderMaterial = plants.bundle.meshes[asset].surface_get_material(0)
			check(is_equal_approx(material.get_shader_parameter("study_grass_night_albedo"), turf),
				"The cover grass keeps its biome night tint")
	world.showcase.set_hour(previous_hour)
	plants.grass_light.sync()

func test_wall(world: Node3D, wall: Node3D, toggle: CheckButton) -> void:
	check(wall.find_children("*", "CollisionObject3D", true, false).is_empty(), "Wall vines are visual")
	var batch := wall.get_child(0) as MultiMeshInstance3D
	check(wall.get_child_count() == 1 and batch != null, "The vine placements use one instanced batch")
	if batch == null:
		return
	var sectors := {}
	for index in batch.multimesh.instance_count:
		var pose := batch.multimesh.get_instance_transform(index)
		var outward := pose.basis.y.normalized()
		var behind := pose.origin - outward * .12 + pose.basis.x * .5
		var ahead := behind + outward
		var drop: float = world.surface_height(behind.x, behind.z) - world.surface_height(ahead.x, ahead.z)
		check(drop >= 1. and pose.basis.z.length() * 3. < drop, "Every vine fits its stone drop above the lower floor")
		sectors[Vector2i(signf(behind.x), signf(behind.z))] = true
	check(batch.multimesh.instance_count == world.forest_wall_vine_placements.size() and sectors.size() == 4,
		"Wall vines cover all four map sectors at every authored anchor")
	check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Vines cast cutout shadows")
	check(world.showcase._mist_materials().has(batch.material_override), "Wall vines participate in shared mist")
	world.look.publish_render_wind(1.)
	check(is_equal_approx(batch.material_override.get_shader_parameter("wind_phase"), PI * .5),
		"Wall vines receive the map's animated wind")
	toggle.button_pressed = false
	check(not wall.visible and not world.showcase._mist_materials().has(batch.material_override), "Hiding wall vines removes them from rendering")
	toggle.button_pressed = true
	check(wall.visible, "Wall vines can be restored from settings")
