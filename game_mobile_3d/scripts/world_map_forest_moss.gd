extends Node3D
## Private ForestA1 ledge plants. Placement is visual and never changes terrain or collision.

const ResearchRoot := preload("res://scripts/world_map_forest_path_light.gd")
const SurfaceShader := preload("res://materials/world_map_stone_prop.gdshader")
const SOURCE := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment/ForestA1"
const ATLAS := "Props/Webs/T_SpiderCavePropAtlas_D.png"
const ATLAS_SHA := "d09274d23b20d9d4b5d8ab07dd19e9dcda6699312b34260ef116ed0a62ef2207"
const MESHES := {
	1: ["SM_Moss1x1.glb", "32adaaabf9a4e63a8e5524abf41b60591e4560636e6cba8ae7492f4a3b0a9e2b"],
	2: ["SM_Moss2x1.glb", "e2c2b22d858e558eba9e9cc2741c434160d3a053fcfa9408bcb3f27864728653"],
}

var material: ShaderMaterial

func configure(world: Node3D, placements: PackedVector4Array) -> bool:
	var root := ResearchRoot.research_root()
	if root.is_empty() or placements.is_empty() or RenderingServer.get_rendering_device() == null:
		return false
	var directory := root.path_join(SOURCE)
	var atlas_path := directory.path_join(ATLAS)
	if not FileAccess.file_exists(atlas_path) or FileAccess.get_sha256(atlas_path) != ATLAS_SHA:
		return false
	var image := Image.load_from_file(atlas_path)
	if image == null or image.get_size() != Vector2i(128, 128):
		return false
	image.generate_mipmaps()
	var meshes := {}
	var poses := {}
	var occupied := {}
	for placement: Vector4 in placements:
		var variant := int(placement.w)
		if not placement.is_finite() or placement.w != float(variant) or not MESHES.has(variant):
			return false
		if not meshes.has(variant):
			var entry: Array = MESHES[variant]
			var mesh := _load_mesh(directory.path_join("Nature/Meshes/Moss").path_join(entry[0]), entry[1])
			if mesh == null:
				return false
			meshes[variant] = mesh
			poses[variant] = []
		var bounds: AABB = meshes[variant].get_aabb()
		var anchor := Vector2(placement.x, placement.y)
		var ground: float = world.surface_height(anchor.x, anchor.y)
		if not is_finite(ground):
			return false
		var fit := minf(.92 / bounds.size.x, (float(variant) - .08) / bounds.size.z)
		var basis := Basis(Vector3.UP, deg_to_rad(placement.z)).scaled(Vector3.ONE * fit)
		var center := bounds.get_center()
		center.y = 0.
		var pose := Transform3D(basis, Vector3(anchor.x, ground + .012, anchor.y) - basis * center)
		if not _reserve_ledge(world, pose * bounds, ground, occupied):
			return false
		poses[variant].append(pose)

	material = ShaderMaterial.new()
	material.shader = SurfaceShader
	material.set_shader_parameter("source_atlas", ImageTexture.create_from_image(image))
	material.set_shader_parameter("source_cutout", true)
	for variant: int in poses:
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = meshes[variant]
		instances.instance_count = poses[variant].size()
		for i in instances.instance_count:
			instances.set_instance_transform(i, poses[variant][i])
		var batch := MultiMeshInstance3D.new()
		batch.name = "Moss%d" % variant
		batch.multimesh = instances
		batch.material_override = material
		add_child(batch)
	return true

func _reserve_ledge(world: Node3D, bounds: AABB, ground: float, occupied: Dictionary) -> bool:
	var offset: Array = world.runtime.offset
	var x0 := floori(bounds.position.x - float(offset[0]))
	var x1 := ceili(bounds.end.x - float(offset[0]))
	var z0 := floori(bounds.position.z - float(offset[2]))
	var z1 := ceili(bounds.end.z - float(offset[2]))
	var y := floori(ground - float(offset[1]) - .01)
	for z in range(z0, z1):
		for x in range(x0, x1):
			var cell := Vector3i(x, y, z)
			var tile_index: int = world.geometry.cells.get(cell, -1)
			var height: float = world.columns.get(Vector2i(x, z), NAN)
			if tile_index < 0 or occupied.has(cell) or not is_equal_approx(height + float(offset[1]), ground):
				return false
			if not String(world.runtime.palette[tile_index].kind).begins_with("stone_"):
				return false
			occupied[cell] = true
	return true

func _load_mesh(path: String, sha: String) -> Mesh:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != sha:
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var scene := document.generate_scene(state)
	if scene == null:
		return null
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	if scene is MeshInstance3D:
		meshes.push_front(scene)
	var mesh: Mesh = meshes[0].mesh if meshes.size() == 1 else null
	scene.free()
	if mesh == null or mesh.get_surface_count() != 1:
		return null
	return mesh
