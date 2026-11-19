extends "res://scripts/world_map_exterior_ground.gd"
## Visual terrain behind the imported north and west crests. Source art stays outside the project.

const DistantTerrain := preload("res://scripts/world_map_distant_terrain.gd")
const RELIEF_SHADER := preload("res://materials/world_map_cliff_relief.gdshader")
const TREE_SOURCE := "Art/Environment/ForestA1/Nature/Meshes/Trees/"
const TREE_MESH_SHA := "0c021a9b8a74e2670a9a303461290e8a6abaf440f9904a485ddb661bed59fb2e"
const TREE_ATLAS_SHA := "7c4926e8b011c87592a3bf52ec2f247c1f0baa9feb2a765a5b6af5710131cd75"
const GRID_METRES := 2.

var _tree_material: ShaderMaterial
var _air_tint := Vector3.INF

func build_relief(world: Node3D, reach: int, tree_sites: PackedVector2Array) -> bool:
	var source: Array = world.geometry._terrain_sources.get("stone_block", [])
	if source.size() != 1 or not source[0].faces.has_all(SIDES + [Vector3i.UP]) or reach < 20 or reach > 80:
		return false
	var trees := _load_spruce()
	if trees.is_empty() or tree_sites.is_empty():
		return false
	var bounds: Dictionary = world.runtime.border
	var low := Vector2(float(bounds.min[0]), float(bounds.min[2]))
	var high := Vector2(float(bounds.max[0]), float(bounds.max[2]))
	if not low.is_finite() or not high.is_finite() or high.x <= low.x or high.y <= low.y \
			or (high - low).x > 270. or (high - low).y > 270.:
		return false
	var from_grid := Vector2i(floori((low.x - reach) / GRID_METRES), floori((low.y - reach) / GRID_METRES))
	var to_grid := Vector2i(ceili((high.x + 10.) / GRID_METRES), ceili((high.y + 10.) / GRID_METRES))
	var lower_y := floori(float(bounds.min[1])) + 1
	var rise_y := lower_y + 1.4
	var noise := FastNoiseLite.new()
	noise.seed = 881
	noise.frequency = .044
	var heights: Dictionary[Vector2i, int] = {}
	for z in range(from_grid.y, to_grid.y):
		for x in range(from_grid.x, to_grid.x):
			var point := Vector2(x, z) * GRID_METRES
			var outside := maxf(low.x + 2. - point.x, low.y + 2. - point.y)
			if outside <= 0.:
				continue
			var broad := noise.get_noise_2d(point.x * .60, point.y * .60)
			var detail := noise.get_noise_2d(point.x, point.y)
			var climb := smoothstep(4., 43., outside)
			var elevation := roundi(rise_y + (.5 + climb) * (broad * 6.8 + detail * 2.3) + 12.4 * climb)
			# The overlap under the existing crest is below the source map's bottom surfaces.
			if outside <= 8.:
				elevation = mini(elevation, lower_y)
			heights[Vector2i(x,z)] = clampi(elevation, lower_y - 1, lower_y + 23)
	var grove := _make_grove(trees.mesh, tree_sites, heights)
	if grove == null or heights.is_empty():
		return false
	material = _make_material(world, RELIEF_SHADER)
	var spruce_shader := Shader.new()
	spruce_shader.code = RELIEF_SHADER.code.replace("shader_type spatial;", "shader_type spatial;\n#define GAF_VISTA_SPRUCE")
	_tree_material = _make_material(world, spruce_shader)
	_tree_material.set_shader_parameter("tree_atlas", trees.atlas)
	grove.material_override = _tree_material
	grove.name = "DistantSpruce"
	var builder := _surface(material)
	var merged := {}
	var faces: Dictionary = source[0].faces
	for cell: Vector2i in heights:
		var height: int = heights[cell]
		if not merged.has(cell):
			var span := _merge_top(heights, merged, cell, height, to_grid.y)
			_emit_top(builder, faces[Vector3i.UP].whole, cell, height, span, GRID_METRES)
		var center := Vector3(cell.x * GRID_METRES + 1., height - 1., cell.y * GRID_METRES + 1.)
		for direction: Vector3i in SIDES:
			var neighbor := cell + Vector2i(direction.x,direction.z)
			var exposed := height - int(heights.get(neighbor, height))
			for step in exposed:
				for vertex: Array in faces[direction].whole:
					builder.set_normal(vertex[1])
					builder.add_vertex(Vector3(vertex[0]) * Vector3(2.,1.,2.) + center - Vector3.UP * step)
	_finish_strip(builder, &"Ridge")
	add_child(grove)
	world.look.materials["cliff-relief:stone"] = material
	world.look.materials["cliff-relief:spruce"] = _tree_material
	return true

func set_air(environment: Environment, hour: float) -> void:
	var color := environment.fog_light_color.srgb_to_linear()
	var daylight := smoothstep(5.2, 7., hour) * (1. - smoothstep(17.5, 19.5, hour))
	var tint := Vector3(color.r,color.g,color.b) * lerpf(.107, .169, daylight)
	if tint == _air_tint:
		return
	_air_tint = tint
	material.set_shader_parameter("distant_air_color", tint)
	_tree_material.set_shader_parameter("distant_air_color", tint * .97)

func _make_material(world: Node3D, shader: Shader) -> ShaderMaterial:
	var layer := ShaderMaterial.new()
	layer.shader = shader
	layer.set_shader_parameter("cloud_field", world.look.cloud_texture)
	layer.set_shader_parameter("cloud_shape", world.look._cloud_shape)
	layer.set_shader_parameter("clouds_enabled", true)
	return layer

func _make_grove(mesh: Mesh, tree_sites: PackedVector2Array, heights: Dictionary) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = tree_sites.size()
	for i in tree_sites.size():
		var at := tree_sites[i]
		var cell := Vector2i(floori(at.x / GRID_METRES), floori(at.y / GRID_METRES))
		if not at.is_finite() or not heights.has(cell):
			return null
		var height: float = heights[cell]
		var scale_value := .48 + .17 * sin(i * 5.48)
		var basis := Basis(Vector3.UP, float(i) * .25).scaled(Vector3.ONE * scale_value)
		batch.set_instance_transform(i, Transform3D(basis, Vector3(at.x, height -.12, at.y)))
	var result := MultiMeshInstance3D.new()
	result.multimesh = batch
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

func _load_spruce() -> Dictionary:
	var folder := DistantTerrain.research_root().path_join(DistantTerrain.ROOT).path_join(TREE_SOURCE)
	var mesh_path := folder.path_join("SM_Tree_Spruce_1x1_Var3.glb")
	var atlas_path := folder.path_join("T_TreeAtlas_Spruce.png")
	if FileAccess.get_sha256(mesh_path) != TREE_MESH_SHA or FileAccess.get_sha256(atlas_path) != TREE_ATLAS_SHA:
		return {}
	var document := GLTFDocument.new()
	var import_state := GLTFState.new()
	if document.append_from_file(mesh_path, import_state) != OK:
		return {}
	var tree := document.generate_scene(import_state)
	if tree == null:
		return {}
	var parts := tree.find_children("*","MeshInstance3D",true,false)
	if tree is MeshInstance3D:
		parts.push_front(tree)
	var mesh: Mesh = parts[0].mesh if parts.size() == 1 and parts[0].transform == Transform3D.IDENTITY else null
	tree.free()
	if mesh == null or mesh.get_surface_count() != 1:
		return {}
	mesh.surface_set_material(0, null)
	var image := Image.load_from_file(atlas_path)
	if image == null or image.is_empty():
		return {}
	image.generate_mipmaps()
	return {"mesh":mesh, "atlas":ImageTexture.create_from_image(image)}
