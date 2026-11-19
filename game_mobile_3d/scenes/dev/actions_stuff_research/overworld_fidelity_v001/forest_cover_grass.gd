extends RefCounted
## Adapts private Forest ground plants to the shared grass material and wind attributes.
const MANIFEST := "godot_lab/world_map_unified_showcase_v001/forest_cover_grass_v001/sources.private.json"
const PlantShader := preload("vegetation.gdshader")
const ResearchRoot := preload("res://scripts/world_map_forest_path_light.gd")
const ENVIRONMENT := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment"
const FOREST_ATLAS := "ForestA1/Props/Boulder"
const FOREST_ATLAS_ENTRY := {"file": "T_TreesBoulders.png",
	"sha256": "9b596a2149fcaf999178d6a5557cda9677c204f21848c84c9a30425ad1d850f6"}
const FERN_DIRECTORY := "Generic/Nature/Foliage/Ferns"
const FERN_VARIANTS := [
	{"file": "SM_Fern_02_Small.glb", "sha256": "9a913d07388d03126054307edbb32aca8a07ab0e42a8e9c737954c7147df9bed", "height": .72},
	{"file": "SM_Fern_01_Large.glb", "sha256": "2d8a465d2cc3956e691e46e7c3ea542af5d66933823925311aa00607a745f8c5", "height": .89},
]

static func load_into(bundle: RefCounted) -> Array[String]:
	var manifest_path: String = bundle.root.path_join(MANIFEST)
	if not bundle.permitted(manifest_path) or not FileAccess.file_exists(manifest_path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not data is Dictionary or data.get("schema") != "private_forest_cover_grass/1":
		return []
	var directory: String = bundle.root.path_join(String(data.get("source", ""))).simplify_path()
	if not directory.replace("\\", "/").begins_with(bundle.root + "/extracted/"):
		return []
	var atlas_path := checked_file(bundle, directory, data.get("atlas"), "png")
	var entries: Variant = data.get("meshes")
	if atlas_path.is_empty() or not entries is Array or entries.size() != 3:
		return []
	var image := Image.load_from_file(atlas_path)
	if image == null or image.is_empty():
		return []
	var material := plant_material(bundle, image)
	var names: Array[String] = []
	var loaded := {}
	for entry: Variant in entries:
		var path := checked_file(bundle, directory, entry, "glb")
		var mesh := load_mesh(path, material)
		if mesh == null:
			return []
		var key := "ForestA1 | " + path.get_file().get_basename()
		if loaded.has(key):
			return []
		names.append(key)
		loaded[key] = mesh
	bundle.meshes.merge(loaded)
	bundle.materials.append(material)
	return names

static func load_forest_fern(bundle: RefCounted) -> String:
	if ResearchRoot.research_root().is_empty() or RenderingServer.get_rendering_device() == null:
		return ""
	var directory: String = bundle.root.path_join(ENVIRONMENT)
	var atlas_path := checked_file(bundle, directory.path_join(FOREST_ATLAS), FOREST_ATLAS_ENTRY, "png")
	var mesh_path := checked_file(bundle, directory.path_join(FERN_DIRECTORY), {
		"file": "SM_SF_Fern_Small.glb",
		"sha256": "46ebb26dff1711472085ed6dea1a2c52e56aa04d9087ebfba4312a6d6fa5876f"}, "glb")
	if atlas_path.is_empty() or mesh_path.is_empty():
		return ""
	var image := Image.load_from_file(atlas_path)
	if image == null or image.get_size() != Vector2i(128, 128):
		return ""
	var material := plant_material(bundle, image)
	var mesh := load_mesh(mesh_path, material)
	if mesh == null:
		return ""
	var key := "ForestA1 | SM_SF_Fern_Small"
	bundle.meshes[key] = mesh
	bundle.materials.append(material)
	return key

static func load_fern_variants(bundle: RefCounted) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	if ResearchRoot.research_root().is_empty() or RenderingServer.get_rendering_device() == null:
		return result
	var directory: String = bundle.root.path_join(ENVIRONMENT).path_join(FERN_DIRECTORY)
	var atlas_path := checked_file(bundle, directory, {"file": "T_Ferns_01.png",
		"sha256": "ffe2b5d7d75975a00b4cf7bdad2201c377f2f4492f260369f46698df203aaee8"}, "png")
	if atlas_path.is_empty():
		return result
	var image := Image.load_from_file(atlas_path)
	if image == null or image.get_size() != Vector2i(64, 64):
		return result
	var material := plant_material(bundle, image)
	material.set_meta("limit_motion_to_cell", true)
	for index: int in FERN_VARIANTS.size():
		var entry: Dictionary = FERN_VARIANTS[index]
		var path := checked_file(bundle, directory, entry, "glb")
		var mesh := load_mesh(path, material, entry.height)
		if mesh != null:
			var key := "MD2 | " + path.get_file().get_basename()
			bundle.meshes[key] = mesh
			result[index] = key
	if not result.is_empty():
		bundle.materials.append(material)
	return result

static func plant_material(bundle: RefCounted, image: Image) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PlantShader
	material.set_shader_parameter("atlas", ImageTexture.create_from_image(image))
	material.set_shader_parameter("tinted_grass", true)
	material.set_shader_parameter("native_grass_albedo", true)
	material.set_shader_parameter("cutoff", .5)
	var wind: Dictionary = bundle.data.motion
	material.set_shader_parameter("wind_intensity", float(wind.intensity))
	material.set_shader_parameter("wind_direction", Vector2(wind.direction[0], wind.direction[1]))
	material.set_shader_parameter("frequency", float(wind.frequency_adapter))
	return material

static func checked_file(bundle: RefCounted, directory: String, entry: Variant, extension: String) -> String:
	if not entry is Dictionary or not entry.get("file") is String or not entry.get("sha256") is String:
		return ""
	var file: String = entry.file
	if file != file.get_file() or file.get_extension() != extension:
		return ""
	var path := directory.path_join(file)
	if bundle.permitted(path) and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == entry.sha256:
		return path
	return ""

static func load_mesh(path: String, material: ShaderMaterial, fitted_height := 0.) -> ArrayMesh:
	if path.is_empty():
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var imported := document.generate_scene(state)
	if imported == null:
		return null
	var nodes := imported.find_children("*", "MeshInstance3D", true, false)
	if imported is MeshInstance3D:
		nodes.push_front(imported)
	var source: Mesh = nodes[0].mesh if nodes.size() == 1 else null
	imported.free()
	if source == null or source.get_surface_count() != 1:
		return null
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bounds := source.get_aabb()
	var size := bounds.size
	if vertices.size() < 3 or size.y < .9 or size.y > 2.1:
		return null
	if fitted_height > 0.:
		var radius := 0.
		for vertex in vertices:
			radius = maxf(radius, Vector2(vertex.x, vertex.z).length())
		if radius <= 0.:
			return null
		# Keep the entire rest pose and a small wind margin within one block.
		var horizontal := .42 / radius
		var fit := Vector3(horizontal, fitted_height / size.y, horizontal)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			vertices[index] = (vertices[index] - Vector3.UP * bounds.position.y) * fit
			normals[index] = (normals[index] / fit).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		size.y = fitted_height
	var roots := PackedVector2Array()
	roots.resize(vertices.size())
	var motion := PackedFloat32Array()
	for vertex: Vector3 in vertices:
		motion.append_array(PackedFloat32Array([clampf(vertex.y / size.y, 0., 1.), size.y, 0., .85]))
	arrays[Mesh.ARRAY_TEX_UV2] = roots
	arrays[Mesh.ARRAY_CUSTOM0] = motion
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	if result.get_surface_count() == 0:
		return null
	result.surface_set_material(0, material)
	return result
