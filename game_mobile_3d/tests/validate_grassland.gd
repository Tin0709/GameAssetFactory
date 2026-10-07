extends SceneTree
## Real scene/controller contract, including seeded scattering and planted geometry.
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("GRASSLAND: " + message)

func tick(count: int) -> void:
	for i in range(count): await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://scenes/Grassland.tscn"), "Playable Grassland scene exists")
	if not failures.is_empty():
		quit(1)
		return
	var level = load("res://scenes/Grassland.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await tick(8)
	check(level.cell_count == 1600, "Exactly 1600 terrain cells")
	check(level.get_node("Terrain").get_child_count() == 16, "16 combined terrain chunks")
	var ground = level.get_node("Ground/CollisionShape3D")
	check(ground.shape.size == Vector3(40, 1, 40), "One continuous 40x1x40 collision surface")
	check(ground.global_position == Vector3(0, 0.5, 0), "Ground top is exactly Y=1")
	check(level.grass_transforms.size() == 400, "Default 400 patches / 25 percent coverage")
	var rendered_count := 0
	for patch in level.get_node("Grass").get_children():
		rendered_count += patch.multimesh.instance_count
	check(rendered_count == 400, "All 400 grass instances rendered")
	var arrays = level.grass_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var masks: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var roots: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	check(not masks.is_empty() and roots.size() == vertices.size(), "Imported bend data and blade-root UV2 preserved")
	var root_vertices := 0
	var min_height := INF
	var max_height := 0.0
	for i in range(vertices.size()):
		if vertices[i].y < 0.0001:
			root_vertices += 1
			check(masks[i].r == 0 and masks[i].g == 0, "Exported roots have exactly zero bend mask")
		max_height = maxf(max_height, vertices[i].y)
		if masks[i].g > 0.999: min_height = minf(min_height, vertices[i].y)
	check(root_vertices >= 98 and min_height > 0.48 and max_height < 0.70, "Approved 49-blade geometry and heights retained")
	check(level.grass_mesh.get_faces().size() / 3 == 294, "Actual 294 triangle grass patch")
	check(level.terrain_triangles < 16000, "Internal terrain faces removed for efficient rendering")
	var top_cells := {}
	var top_triangles := 0
	var top_area := 0.0
	for chunk in level.get_node("Terrain").get_children():
		var faces: PackedVector3Array = chunk.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var a := faces[i]
			var b := faces[i + 1]
			var c := faces[i + 2]
			if a.y > 0.9999 and b.y > 0.9999 and c.y > 0.9999:
				top_triangles += 1
				top_area += (b - a).cross(c - a).length() * 0.5
				var center := (a + b + c) / 3
				var cell := Vector2i(floori(center.x + 20), floori(center.z + 20))
				top_cells[cell] = int(top_cells.get(cell, 0)) + 1
	check(top_triangles == 3200 and is_equal_approx(top_area, 1600), "Rendered top covers exactly 1600 square metres with two triangles per cell")
	check(top_cells.size() == 1600, "Rendered geometry contains all 1600 distinct cells")
	for z in range(40):
		for x in range(40): check(top_cells.get(Vector2i(x, z), 0) == 2, "Each one-metre grid cell has exactly one source top")
	for i in range(vertices.size()):
		if vertices[i].y < 0.0001:
			var decoded := Vector3(roots[i].x - 0.5, 0, roots[i].y - 0.5)
			check(decoded.distance_to(vertices[i]) < 0.046, "Imported blade root UV2 maps back within the half blade width")
	for transform: Transform3D in level.grass_transforms:
		check(is_equal_approx(transform.origin.y, 1.0), "Grass root plane planted at Y=1")
		check(Vector2(transform.origin.x, transform.origin.z).length() > 1.4, "Spawn clearing excludes grass")
		check(absf(transform.origin.x) < 19.5 and absf(transform.origin.z) < 19.5, "Grass bounds stay inside terrain")
	var repeat = load("res://scripts/grassland.gd").new()
	repeat.build_distribution()
	check(repeat.grass_transforms == level.grass_transforms, "Seed produces identical transforms")
	repeat.grass_seed += 1
	repeat.build_distribution()
	check(repeat.grass_transforms != level.grass_transforms, "Different seed changes distribution")
	repeat.grass_instance_count = 100
	repeat.build_distribution()
	check(repeat.grass_transforms.size() == 100, "Explicit grass instance count configurable")
	repeat.grass_instance_count = 0
	repeat.build_distribution()
	check(repeat.grass_transforms.is_empty(), "Zero instances supported")
	repeat.free()
	check(get_nodes_in_group("zombies").is_empty(), "No enemies")
	check(level.find_child("SpawnDirector", true, false) == null, "No spawner in Grassland scene")
	check(level.find_children("*", "StaticBody3D", true, false).size() == 1, "No per-grass/block physics bodies")
	var player = level.get_node("Actors/Player")
	check(player.get_script().resource_path == "res://scripts/cuboid_player.gd", "Production controller reused")
	check(player.is_on_floor() and absf(player.global_position.y - 1.0) < 0.02, "Player settles on ground")
	var start: Vector3 = player.global_position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await tick(45)
	var walk_speed: float = player.current_speed
	check(player.global_position.z < start.z - 1.0, "W traverses terrain using existing input")
	check(absf(walk_speed - player.walk_speed) < 0.05, "Existing walk speed retained")
	check(level.motion.active_count > 0, "Walking publishes movement samples")
	key.pressed = false
	Input.parse_input_event(key)
	Input.action_press("move_right")
	await tick(30)
	check(player.velocity.x > 4.0 and absf(player.velocity.z) < 0.05, "Sideways movement direction published")
	Input.action_press("sprint")
	await tick(30)
	check(player.fast_sprinting and player.current_speed > walk_speed + 1.0, "Sprint is faster using production controller")
	check(level.motion.active_count <= 8, "History bounded to eight segments")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await tick(20)
	check(player.velocity.x < -6.0, "Direction reversal traverses without collision snagging")
	Input.action_release("move_left")
	Input.action_release("sprint")
	await tick(100)
	check(player.current_speed < 0.01 and level.motion.active_count == 0, "Stationary player stops adding disturbance; trail expires")
	for point in [Vector3(-19, 1.02, -19), Vector3(19, 1.02, 19), Vector3(-0.5, 1.02, 0.5)]:
		player.global_position = point
		player.velocity = Vector3.ZERO
		await tick(5)
		check(player.is_on_floor() and absf(player.global_position.y - 1) < 0.02, "Collision works across map and cell seams")
	check(level.get_node("Camera3D").current, "Production camera active and following")
	check(get_nodes_in_group("zombies").is_empty(), "No enemies after sustained play")
	var report := {"checks": checks, "failures": failures, "grass_instances": rendered_count, "terrain_cells": level.cell_count}
	print(JSON.stringify(report))
	var file := FileAccess.open("res://.validation/grassland_contract.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t"))
	quit(0 if failures.is_empty() else 1)
