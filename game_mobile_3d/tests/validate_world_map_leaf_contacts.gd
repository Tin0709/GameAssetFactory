extends SceneTree
## Measures rendered triangles, including contacts that span spatial chunks.
const GEOMETRY = preload("res://scripts/world_map_geometry.gd")
const FULL := {"kind": "leaf", "category": "leaf", "height": 1.0, "base_y_offset": 0.0}
const SLAB := {"kind": "leaf_slab", "category": "leaf", "height": 0.5, "base_y_offset": 0.0}
var failures: Array[String] = []
var measurements: Dictionary = {}
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func fixture(records: Array, palette: Array = [FULL, SLAB]):
	var geometry := GEOMETRY.new()
	root.add_child(geometry)
	geometry.build({"offset": [0, 0, 0], "palette": palette, "cells": records})
	check(geometry.build_errors.is_empty(), "Fixture builds: " + str(records))
	await process_frame
	return geometry

func plane_area(geometry, axis: int, coordinate: float, lower_y: float, upper_y: float) -> float:
	var area := 0.0
	for batch: MultiMeshInstance3D in geometry.vegetation_batches:
		var mesh: Mesh = batch.multimesh.mesh
		for instance in batch.multimesh.instance_count:
			var transform := batch.transform * batch.multimesh.get_instance_transform(instance)
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for index in range(0, indices.size(), 3):
					var a := transform * vertices[indices[index]]
					var b := transform * vertices[indices[index + 1]]
					var c := transform * vertices[indices[index + 2]]
					if absf(a[axis] - coordinate) > 0.00001 or absf(b[axis] - coordinate) > 0.00001 or absf(c[axis] - coordinate) > 0.00001:
						continue
					# Clip the measured triangle to the requested vertical interval.
					var polygon: Array[Vector3] = [a, b, c]
					polygon = clip_y(polygon, lower_y, false)
					polygon = clip_y(polygon, upper_y, true)
					for corner in range(1, polygon.size() - 1):
						area += (polygon[corner] - polygon[0]).cross(polygon[corner + 1] - polygon[0]).length() * 0.5
	return area

func clip_y(input: Array[Vector3], height: float, below: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if input.is_empty():
		return result
	var previous: Vector3 = input.back()
	var previous_inside: bool = previous.y <= height if below else previous.y >= height
	for current: Vector3 in input:
		var inside: bool = current.y <= height if below else current.y >= height
		if inside != previous_inside:
			result.append(previous.lerp(current, (height - previous.y) / (current.y - previous.y)))
		if inside:
			result.append(current)
		previous = current
		previous_inside = inside
	return result

func check_pair(records: Array, contact_x: float, label: String, expected_upper: float = 0.0, palette: Array = [FULL, SLAB]) -> void:
	var geometry = await fixture(records, palette)
	var lower := plane_area(geometry, 0, contact_x, 0.0, 0.5)
	var upper := plane_area(geometry, 0, contact_x, 0.5, 1.0)
	measurements[label] = {"lower_contact_area": lower, "upper_contact_area": upper}
	check(lower < 0.00001, label + " removes hidden lower contact")
	check(absf(upper - expected_upper) < 0.00001, label + " preserves only exposed upper contact")
	check(geometry.leaf_collision_count == 0, label + " leaves are walk-through")
	check(geometry.terrain_triangles == 0 and geometry.terrain_face_area == 0, label + " leaves terrain counters unchanged")
	var source_core_count := 0
	for batch: MultiMeshInstance3D in geometry.vegetation_batches:
		if batch.get_meta("source_part") == 0:
			source_core_count += batch.multimesh.instance_count
	check(source_core_count == 2, label + " keeps both logical core instances")
	geometry.free()

func run() -> void:
	var isolated = await fixture([[0, 0, 0, 0]])
	for batch: MultiMeshInstance3D in isolated.vegetation_batches:
		print("LEAF_SOURCE ", batch.name, " transform=", batch.transform * batch.multimesh.get_instance_transform(0), " aabb=", batch.multimesh.mesh.get_aabb(), " vertices=", batch.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].slice(0, 4))
	var upper_baseline := plane_area(isolated, 0, 1.0, 0.5, 1.0)
	var lower_baseline := plane_area(isolated, 0, 1.0, 0.0, 0.5)
	check(upper_baseline > 0.1 and lower_baseline > 0.1, "Source leaf has measurable contact geometry")
	isolated.free()
	await check_pair([[0, 0, 0, 0], [1, 0, 0, 0]], 1.0, "Full/full")
	await check_pair([[0, 0, 0, 0], [1, 0, 0, 1]], 1.0, "Full/bottom slab", upper_baseline)
	await check_pair([[9, 0, 0, 0], [10, 0, 0, 1]], 10.0, "Across chunk", upper_baseline)
	var upper_slab: Dictionary = SLAB.duplicate()
	upper_slab.base_y_offset = 0.5
	var upper_pair = await fixture([[0, 0, 0, 0], [1, 0, 0, 1]], [FULL, upper_slab])
	check(plane_area(upper_pair, 0, 1.0, 0.5, 1.0) < 0.00001, "Full/top slab removes upper contact")
	check(absf(plane_area(upper_pair, 0, 1.0, 0.0, 0.5) - lower_baseline) < 0.00001, "Full/top slab keeps lower exposed core")
	upper_pair.free()
	var stacked = await fixture([[0, 0, 0, 0], [0, 1, 0, 1]])
	check(plane_area(stacked, 1, 1.0, 0.0, 2.0) < 0.00001, "Vertical full/slab removes shared top/bottom")
	stacked.free()
	var actual = GEOMETRY.new()
	root.add_child(actual)
	actual.build(JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/world_map/runtime.json")))
	await process_frame
	check(actual.build_errors.is_empty(), "Actual map builds")
	check(actual.leaf_collision_count == 0, "Actual map leaves are walk-through")
	# The reported adjacent source pair is translated by (-77,0,-56).
	var actual_contact := plane_area(actual, 0, -31.0, 3.0, 4.0)
	# Other exposed faces can share X; verify this pair in an isolated exact fixture.
	measurements["actual_map_plane_area_including_unrelated_faces"] = actual_contact
	var real_pair = await fixture([[45, 3, 63, 0], [46, 3, 63, 0]])
	check(plane_area(real_pair, 0, 46.0, 3.0, 4.0) < 0.00001, "Reported actual pair has no coplanar contact")
	real_pair.free()
	actual.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("WORLD_MAP_LEAF_CONTACTS " + JSON.stringify({"checks": checks, "failures": failures, "measurements": measurements}))
	quit(0 if failures.is_empty() else 1)
