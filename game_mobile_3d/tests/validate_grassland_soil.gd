extends SceneTree
## The requested soil sample must use the real imported asset, stay flat and
## restore the exact all-grass comparison without accumulating geometry.
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://assets/environment/grassland/dirt_block_v4.glb"), "Authored bare dirt block is available")
	if not failures.is_empty():
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	var production = load("res://scenes/Grassland.tscn").instantiate()
	root.add_child(production)
	check(production.find_child("SoilReview", true, false) == null, "Actual game keeps the all-grass map")
	production.queue_free()
	await process_frame
	var review = load("res://scenes/GrasslandLookDev.tscn").instantiate()
	root.add_child(review)
	for i in range(8): await physics_frame
	var soil: Node3D = review.get_node_or_null("SoilReview")
	check(soil != null, "Look-dev has the requested soil sample")
	if soil == null:
		print(JSON.stringify({"checks": checks, "failures": failures}))
		quit(1)
		return
	check(soil.get_child_count() == 8 and soil.visible, "New review starts with the 4 by 2 soil strip")
	var nodes: int = review.find_children("*", "Node", true, false).size()
	var top_area := 0.0
	var top_cells := {}
	for cell in soil.get_children():
		check(cell.scene_file_path == "res://assets/environment/grassland/dirt_block_v4.glb", "Soil strip instances the actual authored dirt GLB")
		for mesh in cell.find_children("*", "MeshInstance3D", true, false):
			for vertex in mesh.mesh.get_faces():
				check(vertex.y <= 1.0001 and vertex.y >= -0.0001, "Soil stays within original unit-height block")
		var center: Vector3 = cell.position
		check(center.y == 0.0 and absf(center.x) <= 1.5 and absf(center.z) == 0.5, "Soil strip remains flat inside cleared spawn")
	for container in [review.get_node("Terrain"), soil]:
		for mesh in container.find_children("*", "MeshInstance3D", true, false):
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			for i in range(0, faces.size(), 3):
				var a: Vector3 = mesh.global_transform * faces[i]
				var b: Vector3 = mesh.global_transform * faces[i + 1]
				var c: Vector3 = mesh.global_transform * faces[i + 2]
				if a.y > 0.9999 and b.y > 0.9999 and c.y > 0.9999:
					top_area += (b - a).cross(c - a).length() * 0.5
					var midpoint := (a + b + c) / 3.0
					var key := Vector2i(floori(midpoint.x + 20.0), floori(midpoint.z + 20.0))
					top_cells[key] = int(top_cells.get(key, 0)) + 1
	check(is_equal_approx(top_area, 1600.0) and top_cells.size() == 1600, "Soil replaces eight grass tops without holes or coplanar overlap")
	for cell in top_cells: check(top_cells[cell] == 2, "Each terrain cell is rendered exactly once")
	for i in range(5):
		review.set_look(false)
		check(not soil.visible, "Previous v3 hides soil")
		review.set_look(true)
		check(soil.visible, "New v4 restores soil")
		review.set_soil_review(false)
		check(not soil.visible, "Soil toggle restores grass surface")
		review.set_soil_review(true)
	check(review.grass_transforms.size() == 400 and review.find_children("*", "StaticBody3D", true, false).size() == 1, "Soil does not change scatter or collision")
	var soil_key := InputEventKey.new()
	soil_key.physical_keycode = KEY_F4
	soil_key.pressed = true
	Input.parse_input_event(soil_key)
	await physics_frame
	check(not soil.visible, "F4 actually toggles the soil sample")
	check(review.find_children("*", "Node", true, false).size() == nodes, "Repeated soil/A-B switches reuse nodes")
	var report := {"checks": checks, "failures": failures}
	FileAccess.open("res://.validation/grassland_soil_contract.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
