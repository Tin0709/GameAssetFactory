extends Node3D
## Visual foothills below the imported east and south edges, built from the map's existing stone faces.

const SIDES := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]

func build(world: Node3D, reach: int) -> bool:
	var bounds: Dictionary = world.runtime.border
	var east := roundi(float(bounds.max[0])) - 2
	var south := roundi(float(bounds.max[2])) - 2
	var floor_y := floori(float(bounds.min[1])) + 1
	var min_x := floori(float(bounds.min[0])) - 18
	var min_z := floori(float(bounds.min[2])) - 18
	var source: Array = world.geometry._terrain_sources.get("stone_block", [])
	if source.size() != 1 or east <= min_x or south <= min_z or east - min_x > 270 or south - min_z > 270:
		return false
	var stone: Dictionary = source[0]
	var material: ShaderMaterial = world.look.make_material(stone.material, "terrain")
	var noise := FastNoiseLite.new()
	noise.seed = 622
	noise.frequency = .035
	var heights: Dictionary[Vector2i, int] = {}
	for z in range(min_z, south + reach):
		for x in range(min_x, east + reach):
			var distance := maxi(x - east, z - south)
			if distance < 0:
				continue
			var broad := noise.get_noise_2d(x, z)
			var detail := noise.get_noise_2d(x * 2.7 + 43., z * 2.7)
			var rise := broad * 3.25 + detail * .36
			var fall := .40 + 4.1 * smoothstep(0., 23., distance)
			heights[Vector2i(x, z)] = clampi(floori(floor_y - fall + rise), floor_y - 8, floor_y)

	# The two strips have separate bounds, so the renderer can cull them independently.
	var east_strip := _surface(material)
	var south_strip := _surface(material)
	for cell: Vector2i in heights:
		var tool := east_strip if cell.y < south else south_strip
		var height: int = heights[cell]
		var top := Vector3(cell.x + .5, height - 1., cell.y + .5)
		world.geometry._emit_triangles(tool, stone.faces[Vector3i.UP].whole, top, false)
		for direction: Vector3i in SIDES:
			var neighbor := cell + Vector2i(direction.x, direction.z)
			var exposed := height - int(heights.get(neighbor, height))
			for step in exposed:
				world.geometry._emit_triangles(tool, stone.faces[direction].whole, top - Vector3.UP * step, false)
	_finish_strip(east_strip, &"EastFoothills")
	_finish_strip(south_strip, &"SouthFoothills")
	return true

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
