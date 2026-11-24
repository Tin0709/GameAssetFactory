extends Node3D
## Visual foothills below the imported east and south edges, built from the map's existing stone faces.

const SIDES := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
const TOP_SPAN := 8
const PORTABLE_GRID_M := 3.
const PORTABLE_MATERIAL_KEY := "exterior-ground:portable-stone"
const SHADER := preload("res://materials/world_map_exterior_ground.gdshader")

var material: ShaderMaterial

func build(world: Node3D, reach: int) -> bool:
	var bounds: Dictionary = world.runtime.border
	var east := roundi(float(bounds.max[0])) - 5
	var south := roundi(float(bounds.max[2])) - 5
	var floor_y := floori(float(bounds.min[1])) + 1
	var min_x := floori(float(bounds.min[0])) - 18
	var min_z := floori(float(bounds.min[2])) - 18
	var source: Array = world.geometry._terrain_sources.get("stone_block", [])
	if source.size() != 1 or reach <= 0 or reach > 48 or east <= min_x or south <= min_z \
			or east - min_x > 270 or south - min_z > 270:
		return false
	var stone: Dictionary = source[0]
	if not stone.faces.has_all(SIDES + [Vector3i.UP]):
		return false
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("cloud_field", world.look.cloud_texture)
	material.set_shader_parameter("cloud_shape", world.look._cloud_shape)
	material.set_shader_parameter("clouds_enabled", true)
	world.look.materials["exterior-ground:stone"] = material
	var noise := FastNoiseLite.new()
	noise.seed = 622
	noise.frequency = .035
	var heights: Dictionary[Vector2i, int] = {}
	for z in range(min_z, south + reach + 3):
		for x in range(min_x, east + reach + 3):
			var strip_distance := maxi(x - east, z - south)
			if strip_distance < 0:
				continue
			var distance := maxi(strip_distance - 3, 0)
			var broad := noise.get_noise_2d(x, z)
			var detail := noise.get_noise_2d(x * 2.7 + 43., z * 2.7)
			var rise := broad * 3.25 + detail * .36
			var fall := .40 + 4.1 * smoothstep(0., 23., distance)
			heights[Vector2i(x, z)] = clampi(floori(floor_y - fall + rise), floor_y - 8, floor_y)

	# The two strips have separate bounds, so the renderer can cull them independently.
	var east_strip := _surface(material)
	var south_strip := _surface(material)
	var merged := {}
	for cell: Vector2i in heights:
		var tool := east_strip if cell.y < south else south_strip
		var height: int = heights[cell]
		var top := Vector3(cell.x + .5, height - 1., cell.y + .5)
		if not merged.has(cell):
			var end_z := south if cell.y < south else south + reach + 3
			var span := _merge_top(heights, merged, cell, height, end_z)
			_emit_top(tool, stone.faces[Vector3i.UP].whole, cell, height, span)
		for direction: Vector3i in SIDES:
			var neighbor := cell + Vector2i(direction.x, direction.z)
			var exposed := height - int(heights.get(neighbor, height))
			for step in exposed:
				world.geometry._emit_triangles(tool, stone.faces[direction].whole, top - Vector3.UP * step, false)
	_finish_strip(east_strip, &"EastFoothills")
	_finish_strip(south_strip, &"SouthFoothills")
	return true

func build_portable(world: Node3D, reach: int) -> bool:
	var source: Array = world.geometry._terrain_sources.get("stone_block", [])
	if source.size() != 1 or reach <= 0 or reach > 48:
		return false
	var stone: BaseMaterial3D = source[0].material as BaseMaterial3D
	var faces: Dictionary = source[0].faces
	if stone == null or stone.albedo_texture == null or not faces.has_all(SIDES + [Vector3i.UP]):
		return false
	var bounds: Dictionary = world.runtime.border
	var low := Vector2(bounds.min[0], bounds.min[2])
	var high := Vector2(bounds.max[0], bounds.max[2])
	var span := high - low
	if not low.is_finite() or not high.is_finite() or span.x <= 0. or span.y <= 0. or maxf(span.x, span.y) > 270.:
		return false
	var outer := Vector2.ONE * reach
	var first := Vector2i(((low - outer) / PORTABLE_GRID_M).floor())
	var last := Vector2i(((high + outer) / PORTABLE_GRID_M).ceil())
	var floor_y := floori(float(bounds.min[1])) - 1
	var noise := FastNoiseLite.new()
	noise.seed = 622
	noise.frequency = .037
	var heights: Dictionary[Vector2i, int] = {}
	for z in range(first.y, last.y):
		for x in range(first.x, last.x):
			var point := (Vector2(x, z) + Vector2.ONE * .5) * PORTABLE_GRID_M
			var displacement := (low - point).max(point - high)
			var outside := maxf(displacement.x, displacement.y)
			# Extend a few metres under the map, entirely below its base.
			if outside < -7.:
				continue
			var relief := smoothstep(-2., 21., outside) * 4. * noise.get_noise_2d(point.x, point.y)
			var fall := 3. * smoothstep(0., 28., outside)
			heights[Vector2i(x, z)] = floor_y + mini(0, roundi(relief - fall))
	var shader := Shader.new()
	shader.code = SHADER.code.replace("shader_type spatial;", "shader_type spatial;\n#define GAF_PORTABLE_FOOTHILLS")
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("portable_stone", stone.albedo_texture)
	material.set_shader_parameter("portable_stone_tint", stone.albedo_color)
	material.set_shader_parameter("cloud_field", world.look.cloud_texture)
	material.set_shader_parameter("cloud_shape", world.look._cloud_shape)
	material.set_shader_parameter("clouds_enabled", true)
	var strip := _surface(material)
	var merged := {}
	for cell: Vector2i in heights:
		var height: int = heights[cell]
		if not merged.has(cell):
			var top_span := _merge_top(heights, merged, cell, height, last.y)
			_emit_top(strip, faces[Vector3i.UP].whole, cell, height, top_span, PORTABLE_GRID_M)
		for direction: Vector3i in SIDES:
			var other := cell + Vector2i(direction.x, direction.z)
			var side_height := height - int(heights.get(other, height))
			if side_height <= 0:
				continue
			var scale := Vector3(PORTABLE_GRID_M, side_height, PORTABLE_GRID_M)
			var center := Vector3((cell.x + .5) * PORTABLE_GRID_M, height - side_height, (cell.y + .5) * PORTABLE_GRID_M)
			for vertex: Array in faces[direction].whole:
				strip.set_normal(vertex[1])
				strip.add_vertex(Vector3(vertex[0]) * scale + center)
	_finish_strip(strip, &"Foothills")
	world.look.materials[PORTABLE_MATERIAL_KEY] = material
	return true

func _merge_top(heights: Dictionary, merged: Dictionary, cell: Vector2i, height: int, end_z: int) -> Vector2i:
	var span := Vector2i.ONE
	while span.x < TOP_SPAN and _same_top(heights, merged, cell + Vector2i(span.x, 0), height):
		span.x += 1
	while span.y < TOP_SPAN and cell.y + span.y < end_z:
		var matches := true
		for x in span.x:
			if not _same_top(heights, merged, cell + Vector2i(x, span.y), height):
				matches = false
				break
		if not matches:
			break
		span.y += 1
	for z in span.y:
		for x in span.x:
			merged[cell + Vector2i(x, z)] = true
	return span

func _same_top(heights: Dictionary, merged: Dictionary, cell: Vector2i, height: int) -> bool:
	return heights.get(cell) == height and not merged.has(cell)

func _emit_top(tool: SurfaceTool, face: Array, cell: Vector2i, height: int, span: Vector2i, pitch := 1.) -> void:
	# The approved source atlas is sampled from world position, so merging does not stretch it.
	var center := Vector3((cell.x + span.x * .5) * pitch, height - 1., (cell.y + span.y * .5) * pitch)
	var scale := Vector3(span.x * pitch, 1., span.y * pitch)
	for vertex: Array in face:
		tool.set_normal(vertex[1])
		tool.set_uv(vertex[2])
		tool.set_uv2(vertex[3])
		tool.set_color(vertex[4])
		tool.set_tangent(vertex[5])
		tool.add_vertex(Vector3(vertex[0]) * scale + center)

func _surface(material: Material) -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	return tool

func _finish_strip(tool: SurfaceTool, node_name: StringName) -> void:
	tool.index()
	var strip := MeshInstance3D.new()
	strip.name = node_name
	strip.mesh = tool.commit()
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)
