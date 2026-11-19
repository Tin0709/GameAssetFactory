extends RefCounted
## Adapts three private ForestA1 meshes to the existing grass material and wind attributes.
const MANIFEST := "godot_lab/world_map_unified_showcase_v001/forest_cover_grass_v001/sources.private.json"
const PlantShader := preload("vegetation.gdshader")

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
	var material := ShaderMaterial.new()
	material.shader = PlantShader
	material.set_shader_parameter("atlas", ImageTexture.create_from_image(image))
	material.set_shader_parameter("tinted_grass", true)
	material.set_shader_parameter("native_grass_albedo", true)
	material.set_shader_parameter("cutoff", .5)
	var motion: Dictionary = bundle.data.motion
	material.set_shader_parameter("wind_intensity", float(motion.intensity))
	material.set_shader_parameter("wind_direction", Vector2(motion.direction[0], motion.direction[1]))
	material.set_shader_parameter("frequency", float(motion.frequency_adapter))
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

static func load_mesh(path: String, material: ShaderMaterial) -> ArrayMesh:
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
	var size := source.get_aabb().size
	if vertices.size() < 3 or size.y < .9 or size.y > 2.1:
		return null
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
