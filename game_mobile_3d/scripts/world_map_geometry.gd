extends Node3D
## Reconstructs authored meshes on the schematic grid, without scattering or grading.
const CHUNK_SIZE := 10
const ASSET_DIRECTORY := "res://assets/environment/world_map_v1/"
const CUTAWAY_SHADER = preload("res://materials/world_map_cutaway.gdshader")
const EPSILON := 0.00001
const FACE_DIRECTIONS := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.DOWN, Vector3i.UP]

var cells: Dictionary[Vector3i, int] = {}
var terrain_triangles := 0
var terrain_face_area := 0.0
var placement_counts: Dictionary = {}
var terrain_chunks: Array[MeshInstance3D] = []
var vegetation_batches: Array[MultiMeshInstance3D] = []
var leaf_collision_count := 0
var build_errors: Array[String] = []

var _palette: Array = []
var _offset := Vector3.ZERO
var _occupied_halves: Dictionary[Vector3i, bool] = {}
var _leaf_halves: Dictionary[Vector3i, Vector3i] = {}
var _leaf_cluster_roots: Dictionary[Vector3i, float] = {}
var _parts: Dictionary = {}
var _terrain_sources: Dictionary = {}
var _leaf_sources: Dictionary = {}
var _leaf_variants: Dictionary = {}
var _cutaway_chunks: Array[Dictionary] = []


func build(runtime: Dictionary) -> void:
	_clear_geometry()
	_palette = runtime.get("palette", [])
	var translation: Array = runtime.get("offset", [])
	if translation.size() != 3 or _palette.is_empty():
		build_errors.append("Runtime must have a palette and a three-coordinate offset.")
		return
	_offset = Vector3(translation[0], translation[1], translation[2])
	var chunks: Dictionary = {}
	var used_kinds: Dictionary = {}
	for record: Array in runtime.get("cells", []):
		if record.size() != 4:
			build_errors.append("Cell must contain x, y, z and palette index.")
			continue
		var cell := Vector3i(record[0], record[1], record[2])
		var palette_index := int(record[3])
		if cells.has(cell) or palette_index < 0 or palette_index >= _palette.size():
			build_errors.append("Duplicate cell or invalid palette index at %s." % cell)
			continue
		cells[cell] = palette_index
		var entry: Dictionary = _palette[palette_index]
		var category := str(entry.get("category", ""))
		if category in ["marker", "paired_upper"]:
			continue
		if category not in ["terrain", "plant", "leaf"]:
			build_errors.append("Unsupported category %s at %s." % [category, cell])
			continue
		var kind := str(entry.get("kind", ""))
		used_kinds[kind] = category
		var chunk := _chunk_at(cell)
		if not chunks.has(chunk):
			chunks[chunk] = []
		chunks[chunk].append(cell)
		if category in ["terrain", "leaf"]:
			var height := float(entry.get("height", 1.0))
			var base := float(entry.get("base_y_offset", 0.0))
			if (not is_equal_approx(height, 0.5) and not is_equal_approx(height, 1.0)) or not is_equal_approx(base * 2.0, roundf(base * 2.0)):
				build_errors.append("Non half-grid block dimensions at %s." % cell)
				continue
			if category == "terrain":
				for half in roundi(height * 2.0):
					var key := Vector3i(cell.x, cell.y * 2 + roundi(base * 2.0) + half, cell.z)
					if _occupied_halves.has(key):
						build_errors.append("Overlapping terrain at half-cell %s." % key)
					_occupied_halves[key] = true
			else:
				for half in roundi(height * 2.0):
					_leaf_halves[Vector3i(cell.x, cell.y * 2 + roundi(base * 2.0) + half, cell.z)] = cell
	if not build_errors.is_empty():
		return
	for kind: String in used_kinds:
		_load_parts(kind)
		if used_kinds[kind] == "terrain" and _parts.has(kind):
			_cache_terrain(kind)
		elif used_kinds[kind] == "leaf" and _parts.has(kind):
			_cache_leaf(kind)
	if not build_errors.is_empty():
		return
	_index_leaf_clusters()
	for chunk: Vector2i in chunks:
		_build_chunk(chunk, chunks[chunk])
	set_meta("terrain_triangles", terrain_triangles)
	set_meta("terrain_face_area", terrain_face_area)
	set_meta("placement_counts", placement_counts.duplicate())


func _clear_geometry() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	cells.clear()
	_occupied_halves.clear()
	_leaf_halves.clear()
	_leaf_cluster_roots.clear()
	_parts.clear()
	_terrain_sources.clear()
	_leaf_sources.clear()
	_leaf_variants.clear()
	_cutaway_chunks.clear()
	terrain_chunks.clear()
	vegetation_batches.clear()
	placement_counts.clear()
	build_errors.clear()
	terrain_triangles = 0
	terrain_face_area = 0.0
	leaf_collision_count = 0


func _chunk_at(cell: Vector3i) -> Vector2i:
	return Vector2i(floori((cell.x + _offset.x) / CHUNK_SIZE), floori((cell.z + _offset.z) / CHUNK_SIZE))


func _placement(cell: Vector3i, entry: Dictionary) -> Vector3:
	return Vector3(cell) + _offset + Vector3(0.5, float(entry.get("base_y_offset", 0.0)), 0.5)


func _index_leaf_clusters() -> void:
	# Half-voxel adjacency joins touching full/slab modules, including stacked ones.
	# Every module in a cluster receives the same world-space wind root height.
	var visited: Dictionary[Vector3i, bool] = {}
	for first: Vector3i in _leaf_halves:
		if visited.has(first):
			continue
		var pending: Array[Vector3i] = [first]
		var owners: Dictionary[Vector3i, bool] = {}
		var minimum_y := first.y
		visited[first] = true
		while not pending.is_empty():
			var half: Vector3i = pending.pop_back()
			minimum_y = mini(minimum_y, half.y)
			owners[_leaf_halves[half]] = true
			for direction: Vector3i in FACE_DIRECTIONS:
				var neighbour := half + direction
				if _leaf_halves.has(neighbour) and not visited.has(neighbour):
					visited[neighbour] = true
					pending.append(neighbour)
		for owner: Vector3i in owners:
			_leaf_cluster_roots[owner] = minimum_y * 0.5 + _offset.y


func _leaf_contact_mask(cell: Vector3i, entry: Dictionary) -> int:
	var height_halves := roundi(float(entry.height) * 2.0)
	var base := Vector3i(cell.x, cell.y * 2 + roundi(float(entry.base_y_offset) * 2.0), cell.z)
	var mask := 0
	for face in FACE_DIRECTIONS.size():
		var direction: Vector3i = FACE_DIRECTIONS[face]
		if direction.y == 0:
			for half in height_halves:
				if _leaf_halves.has(base + direction + Vector3i(0, half, 0)):
					mask |= 1 << (face * 2 + half)
		else:
			var neighbour := base + Vector3i(0, height_halves if direction.y > 0 else -1, 0)
			if _leaf_halves.has(neighbour):
				mask |= 1 << (face * 2)
	return mask


func _load_parts(kind: String) -> void:
	var filename: String = {"leaf": "leaf_a", "leaf_slab": "leaf_slab_a"}.get(kind, kind)
	var path := ASSET_DIRECTORY + str(filename) + ".glb"
	if not ResourceLoader.exists(path):
		build_errors.append("Missing authored asset: " + path)
		return
	var scene := load(path) as PackedScene
	if scene == null:
		build_errors.append("Asset is not a PackedScene: " + path)
		return
	var source := scene.instantiate()
	var parts: Array[Dictionary] = []
	_collect_parts(source, Transform3D.IDENTITY, parts)
	source.free()
	if parts.is_empty():
		build_errors.append("Asset contains no meshes: " + path)
		return
	_parts[kind] = parts


func _collect_parts(node: Node, parent_transform: Transform3D, result: Array[Dictionary]) -> void:
	var local_transform := parent_transform
	if node is Node3D:
		local_transform = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		# A local mesh copy retains effective material overrides without editing imports.
		var mesh: Mesh = node.mesh
		for surface in mesh.get_surface_count():
			if node.get_active_material(surface) != mesh.surface_get_material(surface):
				mesh = mesh.duplicate()
				for index in mesh.get_surface_count():
					mesh.surface_set_material(index, node.get_active_material(index))
				break
		result.append({"mesh": mesh, "transform": local_transform})
	for child in node.get_children():
		_collect_parts(child, local_transform, result)


func _cache_terrain(kind: String) -> void:
	var surfaces: Array[Dictionary] = []
	for part: Dictionary in _parts[kind]:
		var mesh: Mesh = part.mesh
		var transform: Transform3D = part.transform
		for surface_index in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var faces: Dictionary = {}
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for index in range(0, count, 3):
				var triangle: Array = []
				for corner in 3:
					var source_index := indices[index + corner] if not indices.is_empty() else index + corner
					triangle.append(_source_vertex(arrays, source_index, transform))
				var normal: Vector3 = triangle[0][1]
				var direction := Vector3i(roundi(normal.x), roundi(normal.y), roundi(normal.z))
				if Vector3(direction).length_squared() != 1.0 or normal.dot(Vector3(direction)) < 0.999:
					build_errors.append("Terrain asset %s has a non-axis-aligned face." % kind)
					return
				if not faces.has(direction):
					faces[direction] = {"whole": [], "lower": [], "upper": []}
				faces[direction].whole.append_array(triangle)
				if direction.y == 0:
					faces[direction].lower.append_array(_clip_triangle(triangle, 0.5, true))
					faces[direction].upper.append_array(_clip_triangle(triangle, 0.5, false))
			var material := mesh.surface_get_material(surface_index)
			if material == null:
				build_errors.append("Terrain asset %s surface %d has no native material." % [kind, surface_index])
				return
			surfaces.append({"material": material, "faces": faces})
	_terrain_sources[kind] = surfaces


func _source_vertex(arrays: Array, index: int, transform: Transform3D) -> Array:
	var vertex: Vector3 = transform * arrays[Mesh.ARRAY_VERTEX][index]
	var normal: Vector3 = (transform.basis.inverse().transposed() * arrays[Mesh.ARRAY_NORMAL][index]).normalized()
	var uv := Vector2.ZERO
	var uv2 := Vector2.ZERO
	var color := Color.WHITE
	var tangent := Plane(1, 0, 0, 1)
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		uv = arrays[Mesh.ARRAY_TEX_UV][index]
	if arrays[Mesh.ARRAY_TEX_UV2] != null:
		uv2 = arrays[Mesh.ARRAY_TEX_UV2][index]
	if arrays[Mesh.ARRAY_COLOR] != null:
		color = arrays[Mesh.ARRAY_COLOR][index]
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var values: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var axis := (transform.basis * Vector3(values[index * 4], values[index * 4 + 1], values[index * 4 + 2])).normalized()
		tangent = Plane(axis, values[index * 4 + 3])
	return [vertex, normal, uv, uv2, color, tangent]


func _cache_leaf(kind: String) -> void:
	var parts: Array = []
	var height := 0.5 if kind == "leaf_slab" else 1.0
	for part: Dictionary in _parts[kind]:
		var mesh: Mesh = part.mesh
		var surfaces: Array[Dictionary] = []
		for surface_index in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var faces: Dictionary = {}
			var interior: Array = []
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for index in range(0, count, 3):
				var triangle: Array = []
				for corner in 3:
					var source_index := indices[index + corner] if not indices.is_empty() else index + corner
					triangle.append(_source_vertex(arrays, source_index, part.transform))
				var face := _leaf_boundary_face(triangle, height)
				if face < 0:
					interior.append_array(triangle)
					continue
				if not faces.has(face):
					faces[face] = {"whole": [], "lower": [], "upper": []}
				faces[face].whole.append_array(triangle)
				if FACE_DIRECTIONS[face].y == 0:
					faces[face].lower.append_array(_clip_triangle(triangle, 0.5, true))
					faces[face].upper.append_array(_clip_triangle(triangle, 0.5, false))
			surfaces.append({"material": mesh.surface_get_material(surface_index), "interior": interior, "faces": faces})
		parts.append(surfaces)
	_leaf_sources[kind] = parts


func _leaf_boundary_face(triangle: Array, height: float) -> int:
	# Only exact core boundary faces participate. Foliage overhang and interior
	# cards keep the native geometry even when two neighbouring bushes interleave.
	for vertex: Array in triangle:
		var point: Vector3 = vertex[0]
		if absf(point.x) > 0.5 + EPSILON or absf(point.z) > 0.5 + EPSILON or point.y < -EPSILON or point.y > height + EPSILON:
			return -1
	for face in FACE_DIRECTIONS.size():
		var direction: Vector3 = FACE_DIRECTIONS[face]
		var coordinate := height if direction.y > 0 else (0.0 if direction.y < 0 else 0.5)
		var on_plane := true
		for vertex: Array in triangle:
			if absf(direction.dot(vertex[0]) - coordinate) > EPSILON:
				on_plane = false
				break
		if on_plane:
			return face
	return -1


func _leaf_parts_for_contacts(kind: String, mask: int) -> Array:
	if mask == 0:
		return _parts[kind]
	var key := "%s:%d" % [kind, mask]
	if _leaf_variants.has(key):
		return _leaf_variants[key]
	var parts: Array[Dictionary] = []
	for part_index in _parts[kind].size():
		var surfaces: Array = _leaf_sources[kind][part_index]
		var changed := false
		for surface: Dictionary in surfaces:
			for face: int in surface.faces:
				if ((mask >> (face * 2)) & 3) != 0:
					changed = true
		if not changed:
			parts.append(_parts[kind][part_index])
			continue
		var mesh := ArrayMesh.new()
		for surface: Dictionary in surfaces:
			var selected: Array = surface.interior.duplicate()
			for face: int in surface.faces:
				var hidden: int = (mask >> (face * 2)) & 3
				var triangles: Dictionary = surface.faces[face]
				if hidden == 0:
					selected.append_array(triangles.whole)
				elif FACE_DIRECTIONS[face].y == 0 and kind != "leaf_slab":
					if hidden == 1:
						selected.append_array(triangles.upper)
					elif hidden == 2:
						selected.append_array(triangles.lower)
			if selected.is_empty():
				continue
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(surface.material)
			_emit_triangles(st, selected, Vector3.ZERO, false)
			st.index()
			st.commit(mesh)
		parts.append({"mesh": mesh, "transform": Transform3D.IDENTITY})
	_leaf_variants[key] = parts
	return parts


func _clip_triangle(triangle: Array, height: float, keep_below: bool) -> Array:
	# Sutherland-Hodgman clipping interpolates authored UVs at the half-block seam.
	var polygon: Array = []
	var previous: Array = triangle.back()
	var previous_inside: bool = previous[0].y <= height + EPSILON if keep_below else previous[0].y >= height - EPSILON
	for current: Array in triangle:
		var current_inside: bool = current[0].y <= height + EPSILON if keep_below else current[0].y >= height - EPSILON
		if current_inside != previous_inside:
			var weight: float = (height - previous[0].y) / (current[0].y - previous[0].y)
			var point: Array = []
			for channel in 5:
				point.append(previous[channel].lerp(current[channel], weight))
			var tangent_axis: Vector3 = previous[5].normal.lerp(current[5].normal, weight).normalized()
			point.append(Plane(tangent_axis, previous[5].d))
			polygon.append(point)
		if current_inside:
			polygon.append(current)
		previous = current
		previous_inside = current_inside
	var result: Array = []
	for index in range(1, polygon.size() - 1):
		result.append_array([polygon[0], polygon[index], polygon[index + 1]])
	return result


func _build_chunk(chunk: Vector2i, chunk_cells: Array) -> void:
	var origin := Vector3(chunk.x * CHUNK_SIZE, 0, chunk.y * CHUNK_SIZE)
	var builders: Dictionary = {}
	var plants: Dictionary = {}
	for cell: Vector3i in chunk_cells:
		var entry: Dictionary = _palette[cells[cell]]
		var kind := str(entry.kind)
		placement_counts[kind] = int(placement_counts.get(kind, 0)) + 1
		var placement := _placement(cell, entry) - origin
		if entry.category == "terrain":
			_emit_cell(builders, kind, cell, entry, placement)
		else:
			var mask := _leaf_contact_mask(cell, entry) if entry.category == "leaf" else -1
			var group := "%s:%d" % [kind, mask]
			if not plants.has(group):
				plants[group] = {"kind": kind, "mask": mask, "placements": [], "roots": []}
			plants[group].placements.append(placement)
			if entry.category == "leaf":
				plants[group].roots.append(_leaf_cluster_roots[cell])
	_finish_terrain(chunk, origin, builders)
	for group: Dictionary in plants.values():
		_build_multimeshes(chunk, origin, group.kind, group.placements, group.mask, group.roots)


func _emit_cell(builders: Dictionary, kind: String, cell: Vector3i, entry: Dictionary, placement: Vector3) -> void:
	var height_halves := roundi(float(entry.height) * 2.0)
	var base := Vector3i(cell.x, cell.y * 2 + roundi(float(entry.get("base_y_offset", 0.0)) * 2.0), cell.z)
	var source_surfaces: Array = _terrain_sources[kind]
	for surface_index in source_surfaces.size():
		var surface: Dictionary = source_surfaces[surface_index]
		var key := "%s:%d" % [kind, surface_index]
		for direction: Vector3i in surface.faces:
			var face: Dictionary = surface.faces[direction]
			var selected: Array = []
			if direction.y != 0:
				var neighbour := base + Vector3i(0, height_halves if direction.y > 0 else -1, 0)
				if not _occupied_halves.has(neighbour):
					selected = face.whole
			else:
				var lower_open := not _occupied_halves.has(base + direction)
				var upper_open := height_halves == 2 and not _occupied_halves.has(base + direction + Vector3i.UP)
				if lower_open and (height_halves == 1 or upper_open):
					selected = face.whole
				elif lower_open:
					selected = face.lower
				elif upper_open:
					selected = face.upper
			if selected.is_empty():
				continue
			if not builders.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(surface.material)
				builders[key] = st
			_emit_triangles(builders[key], selected, placement)


func _emit_triangles(st: SurfaceTool, vertices: Array, placement: Vector3, count_terrain: bool = true) -> void:
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index][0]
		var b: Vector3 = vertices[index + 1][0]
		var c: Vector3 = vertices[index + 2][0]
		var area := (b - a).cross(c - a).length() * 0.5
		if area < EPSILON * EPSILON:
			continue
		for corner in 3:
			var vertex: Array = vertices[index + corner]
			st.set_normal(vertex[1])
			st.set_uv(vertex[2])
			st.set_uv2(vertex[3])
			st.set_color(vertex[4])
			st.set_tangent(vertex[5])
			st.add_vertex(vertex[0] + placement)
		if count_terrain:
			terrain_triangles += 1
			terrain_face_area += area


func _finish_terrain(chunk: Vector2i, origin: Vector3, builders: Dictionary) -> void:
	if builders.is_empty():
		return
	var mesh := ArrayMesh.new()
	for st: SurfaceTool in builders.values():
		st.index()
		st.commit(mesh)
	var visual := MeshInstance3D.new()
	visual.name = "Terrain_%d_%d" % [chunk.x, chunk.y]
	visual.mesh = mesh
	visual.position = origin
	add_child(visual)
	terrain_chunks.append(visual)
	var body := StaticBody3D.new()
	body.name = "WorldCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	visual.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	var caster := MeshInstance3D.new()
	caster.name = "NativeShadowCaster"
	caster.mesh = mesh
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	caster.visible = false
	visual.add_child(caster)
	_cutaway_chunks.append({"visual": visual, "caster": caster, "active": false, "materials": []})


func _build_multimeshes(chunk: Vector2i, origin: Vector3, kind: String, placements: Array, contact_mask: int = -1, wind_roots: Array = []) -> void:
	var part_index := 0
	var parts: Array = _parts[kind] if contact_mask < 0 else _leaf_parts_for_contacts(kind, contact_mask)
	for part: Dictionary in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = not wind_roots.is_empty()
		mm.mesh = part.mesh
		mm.instance_count = placements.size()
		for index in placements.size():
			mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, placements[index]) * part.transform)
			if mm.use_custom_data:
				mm.set_instance_custom_data(index, Color(wind_roots[index], 0, 0, 0))
		var visual := MultiMeshInstance3D.new()
		visual.name = "%s_%d_%d_%d_%d" % [kind, chunk.x, chunk.y, part_index, contact_mask]
		visual.multimesh = mm
		visual.position = origin
		visual.set_meta("kind", kind)
		visual.set_meta("source_part", part_index)
		if contact_mask >= 0:
			visual.set_meta("leaf_contact_mask", contact_mask)
		add_child(visual)
		vegetation_batches.append(visual)
		part_index += 1


func update_cutaway(player_position: Vector3, camera_position: Vector3, enabled: bool = true) -> void:
	# Coincident endpoints are the overview/controller contract for restoring imports.
	enabled = enabled and player_position.distance_squared_to(camera_position) > EPSILON
	var start := player_position + Vector3(0, 0.9, 0)
	for item: Dictionary in _cutaway_chunks:
		var visual: MeshInstance3D = item.visual
		var bounds: AABB = visual.global_transform * visual.mesh.get_aabb()
		var active := enabled and bounds.end.y > player_position.y + 0.15 and bounds.grow(3.4).intersects_segment(start, camera_position) != null
		if active and item.materials.is_empty():
			for surface in visual.mesh.get_surface_count():
				item.materials.append(_make_cutaway_material(visual.mesh.surface_get_material(surface)))
		if active != item.active:
			for surface in visual.mesh.get_surface_count():
				visual.set_surface_override_material(surface, item.materials[surface] if active else null)
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if active else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			item.caster.visible = active
			item.active = active
		if active:
			for material: ShaderMaterial in item.materials:
				material.set_shader_parameter("cutaway_start", start)
				material.set_shader_parameter("cutaway_end", camera_position)


func _make_cutaway_material(native: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CUTAWAY_SHADER
	material.set_shader_parameter("cutaway_enabled", true)
	if native is BaseMaterial3D:
		material.set_shader_parameter("use_albedo_texture", native.albedo_texture != null)
		material.set_shader_parameter("atlas", native.albedo_texture)
		material.set_shader_parameter("albedo_tint", native.albedo_color)
		material.set_shader_parameter("native_roughness", native.roughness)
		material.set_shader_parameter("native_metallic", native.metallic)
		material.set_shader_parameter("native_specular", native.metallic_specular)
		material.set_shader_parameter("use_vertex_color", native.vertex_color_use_as_albedo)
	elif native is ShaderMaterial:
		for parameter: String in ["atlas", "smooth_atlas", "smooth_sampling", "use_albedo_texture", "albedo_tint", "native_roughness", "native_metallic", "native_specular", "use_vertex_color", "ground_grade", "texture_contrast"]:
			var value: Variant = native.get_shader_parameter(parameter)
			if value != null:
				material.set_shader_parameter(parameter, value)
	return material


func reset_cutaway_materials() -> void:
	# Scene-local A/B material edits must also invalidate any cached fade copies.
	for item: Dictionary in _cutaway_chunks:
		var visual: MeshInstance3D = item.visual
		for surface in visual.mesh.get_surface_count():
			visual.set_surface_override_material(surface, null)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		item.caster.visible = false
		item.active = false
		item.materials.clear()
