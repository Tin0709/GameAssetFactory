extends RefCounted
## Editor-only decoration. Meshes and atlas data never become project resources.

const SHADER := preload("res://materials/world_map_forest_accents.gdshader")
const FOLDER := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment/DeepDark/Nature/Meshes/Mushrooms"
const MODELS := [
	["SM_DD_Shroom_L_B.glb", "c9a3fd1844e68678549b678cf05a4b2f041c9ebaf2f1c0ce09552959e092cb47"],
	["SM_DD_Shroom_M_B.glb", "98320423668d1470782dd7c3b55afa49e534f335bf15041d0968ccb01e21db95"],
	["SM_DD_Shroom_S_B.glb", "bfde799e1e3e8e96cb1d2b20fddf06130ede6084771cf64a4e6b34275c808190"],
]
const TEXTURES := [
	["T_CW_GlowingBlueMushrooms_d.png", "99b8ad1cb1a591e622e66d099edcc1bc01e06e8eee2a3e06b6213563537171f4"],
	["T_CW_GlowingBlueMushrooms_e.png", "1aab467f60ae4ac9479d32e7917ce83cfbcbaab93c6c4b58d8cc8c8bcde87d8c"],
]
const PLACEMENT := [
	[Vector2(-21.76, 14.18), 1, 0.15], [Vector2(-21.82, 14.59), 2, 1.14],
	[Vector2(-22.82, 20.76), 2, 2.7],
	[Vector2(-23.75, 25.50), 0, 0.34], [Vector2(-23.80, 25.86), 2, 2.28], [Vector2(-23.47, 25.71), 1, 3.11],
]
const EMISSION_GAIN := 0.40

var group: Node3D
var _material: ShaderMaterial
var _attempted := false
var _submitted := Vector2.INF

func update(world: Node3D, phase: float, strength: float) -> void:
	var visible := phase > 0.0 and strength > 0.0
	if visible and not _attempted:
		_attempted = true
		_load(world)
	if not is_instance_valid(group):
		return
	if group.visible != visible:
		group.visible = visible
	if not visible:
		return
	var parameters := Vector2(phase, EMISSION_GAIN * strength * phase)
	if parameters != _submitted:
		_submitted = parameters
		_material.set_shader_parameter("phase_coverage", parameters.x)
		_material.set_shader_parameter("emission_gain", parameters.y)

func _load(world: Node3D) -> void:
	if not OS.has_feature("editor") or RenderingServer.get_current_rendering_method() != "mobile":
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return
	var directory := root.path_join(FOLDER)
	var textures: Array[ImageTexture] = []
	for entry: Array in TEXTURES:
		var path := _checked_path(directory, entry)
		if path.is_empty():
			return
		var image := Image.load_from_file(path)
		if image == null or image.get_size() != Vector2i(32, 32):
			return
		textures.append(ImageTexture.create_from_image(image))
	var meshes: Array[Mesh] = []
	for entry: Array in MODELS:
		var mesh := _load_mesh(_checked_path(directory, entry))
		if mesh == null:
			return
		meshes.append(mesh)
	var placements: Array[Vector3] = []
	for slot: Array in PLACEMENT:
		var xz: Vector2 = slot[0]
		var height: float = world.surface_height(xz.x, xz.y)
		if not is_finite(height):
			return
		placements.append(Vector3(xz.x, height + 0.004, xz.y))
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("mushroom_diffuse", textures[0])
	_material.set_shader_parameter("mushroom_emission", textures[1])
	group = Node3D.new()
	group.name = "PrivateForestAccents"
	group.hide()
	for index in meshes.size():
		var transforms: Array[Transform3D] = []
		for slot in PLACEMENT.size():
			if PLACEMENT[slot][1] == index:
				transforms.append(Transform3D(Basis(Vector3.UP, PLACEMENT[slot][2]), placements[slot]))
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = meshes[index]
		instances.instance_count = transforms.size()
		for i in transforms.size():
			instances.set_instance_transform(i, transforms[i])
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = instances
		batch.material_override = _material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(batch)
	world.add_child(group)

func _checked_path(directory: String, entry: Array) -> String:
	var path := directory.path_join(entry[0])
	return path if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == entry[1] else ""

func _load_mesh(path: String) -> Mesh:
	if path.is_empty():
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var tree := document.generate_scene(state)
	if tree == null:
		return null
	var instances := tree.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = instances[0].mesh if instances.size() == 1 else null
	tree.free()
	if mesh == null or mesh.get_surface_count() != 1:
		return null
	# Release the GLTF importer material. Only the shared bound atlas pair is used.
	mesh.surface_set_material(0, null)
	return mesh
