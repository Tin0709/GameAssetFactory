extends Node3D
## Private ForestA1 understory. Slots belong to the map, while lighting belongs to the biome.

const ResearchRoot := preload("res://scripts/world_map_forest_path_light.gd")
const LeafShader := preload("res://materials/world_map_forest_understory.gdshader")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment/ForestA1"
const ATLASES := [
	["Nature/Foliage/CaveFungus/T_SC_Fungus_D.png", "f99d48a3944fe3a06ab41254c224bd5e10197fee4141ec4dee289b58d6c174fd", 64],
	["Props/Webs/T_SpiderCavePropAtlas_D.png", "d09274d23b20d9d4b5d8ab07dd19e9dcda6699312b34260ef116ed0a62ef2207", 128],
]
const MODELS := [
	["Nature/Foliage/CaveFungus/SM_SC_FungusGrass_S.glb", "bbc0b352489822293e7ee342b5387a4275f4f2225835c0f2b47e69122e259b0a"],
	["Nature/Foliage/CaveFungus/SM_SC_FungusPads_01.glb", "8fc13ab607fe79629c2e0ea0a4927e84d8e8b627fb3c327ee8fe96f6bb6bcb2b"],
	["Nature/Meshes/Moss/SM_SC_HangingMoss_01.glb", "62b74269a7f50e3330fd19f366c44e7db3476e654af1d4deaea4a15d41ab9462"],
	["Nature/Meshes/Moss/SM_SC_HangingMoss_03.glb", "b8f7e391837901f1be358b4c105e8325d48eee61810d383728da9a251ad2a104"],
]
const BATCH_NAMES := ["FungusStems", "FungusPads", "CornerMoss", "LedgeMoss"]

var materials: Array[ShaderMaterial] = []

func configure(world: Node3D, placements: PackedVector4Array, verified_moss_atlas: Texture2D) -> bool:
	var root := ResearchRoot.research_root()
	if root.is_empty() or placements.is_empty() or RenderingServer.get_rendering_device() == null:
		return false
	var directory := root.path_join(SOURCE)
	var occupied := {}
	var batches := {}
	for slot: Vector4 in placements:
		if not slot.is_finite() or slot.w < 0. or slot.w >= MODELS.size() or slot.w != floorf(slot.w):
			return false
		var variant := int(slot.w)
		var anchor := Vector2(slot.x, slot.y)
		var cell := Vector2i(floori(slot.x), floori(slot.y))
		var ground: float = world.surface_height(anchor.x, anchor.y)
		if occupied.has(cell) or not is_finite(ground) or not _stone_cap(world, cell, ground):
			return false
		var basis := Basis(Vector3.UP, deg_to_rad(slot.z))
		var origin := Vector3(anchor.x, ground, anchor.y)
		if variant >= 2:
			# The source stems hang toward local -X. Seat them on the top lip of a real step.
			var outward := -basis.x
			var direction := Vector2i(roundi(outward.x), roundi(outward.z))
			if not Vector3(direction.x, 0, direction.y).is_equal_approx(outward):
				return false
			var lower: float = world.surface_height(anchor.x + direction.x, anchor.y + direction.y)
			if not is_finite(lower) or ground - lower < 0.99:
				return false
			origin += outward * .29
			origin.y -= .05
			basis = basis.scaled(Vector3.ONE * .72)
		else:
			origin.y -= .028 if variant == 1 else .008
			basis = basis.scaled(Vector3.ONE * .76)
		occupied[cell] = true
		if not batches.has(variant):
			batches[variant] = []
		batches[variant].append(Transform3D(basis, origin))

	var shared_materials := {}
	for variant: int in batches:
		var atlas_index := 0 if variant < 2 else 1
		if not shared_materials.has(atlas_index):
			var atlas := verified_moss_atlas if atlas_index == 1 else null
			if atlas == null:
				atlas = _load_atlas(directory, ATLASES[atlas_index])
			if atlas == null:
				return false
			var material := ShaderMaterial.new()
			material.shader = LeafShader
			material.set_shader_parameter("source_atlas", atlas)
			shared_materials[atlas_index] = material
		var mesh := _load_mesh(directory, MODELS[variant])
		if mesh == null:
			return false
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		instances.mesh = mesh
		instances.instance_count = batches[variant].size()
		for i in instances.instance_count:
			instances.set_instance_transform(i, batches[variant][i])
			# Red weights upward stems and green weights descending moss. Pads stay rigid.
			instances.set_instance_custom_data(i, Color(float(variant == 0), float(variant >= 2), 0., 1.))
		var batch := MultiMeshInstance3D.new()
		batch.name = BATCH_NAMES[variant]
		batch.multimesh = instances
		batch.material_override = shared_materials[atlas_index]
		batch.extra_cull_margin = .08
		add_child(batch)
	for material: ShaderMaterial in shared_materials.values():
		materials.append(material)
	return true

func _stone_cap(world: Node3D, cell: Vector2i, height: float) -> bool:
	var offset: Array = world.runtime.offset
	var key := Vector3i(cell.x - int(offset[0]), floori(height - float(offset[1]) - .01), cell.y - int(offset[2]))
	var index: int = world.geometry.cells.get(key, -1)
	return index >= 0 and String(world.runtime.palette[index].kind).begins_with("stone_")

func _load_atlas(directory: String, entry: Array) -> ImageTexture:
	var path := _checked_path(directory, entry)
	if path.is_empty():
		return null
	var image := Image.load_from_file(path)
	if image == null or image.get_size() != Vector2i(entry[2], entry[2]):
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _load_mesh(directory: String, entry: Array) -> Mesh:
	var path := _checked_path(directory, entry)
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
	var mesh: Mesh = nodes[0].mesh if nodes.size() == 1 else null
	imported.free()
	if mesh == null or mesh.get_surface_count() != 1:
		return null
	mesh.surface_set_material(0, null)
	return mesh

func _checked_path(directory: String, entry: Array) -> String:
	var path := directory.path_join(entry[0])
	return path if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == entry[1] else ""
