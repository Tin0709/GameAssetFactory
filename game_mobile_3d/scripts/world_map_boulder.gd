extends Node3D
## The source is private. The map owns its placement, and the shared mist owns fog reception.

const ResearchRoot := preload("res://scripts/world_map_forest_path_light.gd")
const StoneMaterial := preload("res://materials/world_map_stone_prop.gdshader")
const FOLDER := "extracted/2026-10-25 19-26-25/Game/Spicewood/Art/Environment/ForestA1/Props/Boulder"
const MESH := "SM_SF_Boulder_03.glb"
const ATLAS := "T_TreesBoulders.png"
const MESH_SHA := "a40fb5003107558f437e7c262bc923641447ce63dc00c3edf1708dba7d715739"
const ATLAS_SHA := "9b596a2149fcaf999178d6a5557cda9677c204f21848c84c9a30425ad1d850f6"

var collider: StaticBody3D
var visual: MeshInstance3D
var material: ShaderMaterial
var requested := true
var active := false
var roots: Array[Dictionary] = []
var _world: Node3D
var _plants: Node3D
var _rebinding := false
var _bounds: AABB
var _triangles: PackedVector3Array

func configure(world: Node3D, plants: Node3D, anchor: Vector2, yaw_degrees: float, layout_sha: String) -> bool:
	if plants == null or not anchor.is_finite() or not is_finite(yaw_degrees) or layout_sha.length() != 64:
		return false
	if RenderingServer.get_rendering_device() == null or FileAccess.get_sha256(world.map_layout_path) != layout_sha:
		return false
	var root := ResearchRoot.research_root()
	var ground: float = world.surface_height(anchor.x, anchor.y)
	if root.is_empty() or not is_finite(ground):
		return false
	var directory := root.path_join(FOLDER)
	var mesh_path := directory.path_join(MESH)
	var atlas_path := directory.path_join(ATLAS)
	if FileAccess.get_sha256(mesh_path) != MESH_SHA or FileAccess.get_sha256(atlas_path) != ATLAS_SHA:
		return false
	var atlas := Image.load_from_file(atlas_path)
	var mesh := _load_mesh(mesh_path)
	if mesh == null or atlas == null or atlas.get_size() != Vector2i(128, 128):
		return false
	_triangles = mesh.get_faces()
	if _triangles.is_empty():
		return false
	_bounds = mesh.get_aabb()
	var seat := _bounds.get_center()
	seat.y = _bounds.position.y
	var rotation := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	transform = Transform3D(rotation, Vector3(anchor.x, ground - .04, anchor.y) - rotation * seat)

	atlas.generate_mipmaps()
	material = ShaderMaterial.new()
	material.shader = StoneMaterial
	material.set_shader_parameter("source_atlas", ImageTexture.create_from_image(atlas))
	visual = MeshInstance3D.new()
	visual.name = "Stone"
	visual.mesh = mesh
	visual.material_override = material
	visual.hide()
	add_child(visual)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_triangles)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collider = StaticBody3D.new()
	collider.name = "StoneSupport"
	collider.collision_layer = 0
	collider.collision_mask = 0
	collider.add_child(collision)
	add_child(collider)
	_world = world
	_plants = plants
	return true

func _load_mesh(path: String) -> Mesh:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var scene := document.generate_scene(state)
	if scene == null:
		return null
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var result: Mesh
	if meshes.size() == 1:
		var source := meshes[0] as MeshInstance3D
		if source.mesh != null and source.mesh.get_surface_count() == 1:
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.append_from(source.mesh, 0, source.transform)
			builder.set_material(null)
			result = builder.commit()
	scene.free()
	return result

func _ready() -> void:
	_plants.child_order_changed.connect(_queue_roots)
	_resolve_roots()
	_sync()

func _process(_delta: float) -> void:
	_sync()

func set_requested(value: bool) -> void:
	requested = value
	_sync()

func _sync() -> void:
	var wanted: bool = requested and _world.look.stage == 2
	if wanted == active or (wanted and _overlaps_player()):
		return
	active = wanted
	visual.visible = active
	collider.collision_layer = 1 if active else 0
	_apply_roots(active)
	if _world.showcase.mist != null:
		_world.showcase.mist._process(0.)

func _overlaps_player() -> bool:
	# Leave space for the capsule before introducing a solid collider.
	var clearance := _bounds.grow(.55)
	clearance.position.y = _bounds.position.y - 2.
	clearance.size.y = _bounds.end.y - clearance.position.y - .015
	return clearance.has_point(to_local(_world.player.global_position))

func _queue_roots() -> void:
	if _rebinding:
		return
	_rebinding = true
	_resolve_roots.call_deferred()

func _resolve_roots() -> void:
	_rebinding = false
	_apply_roots(false)
	roots.clear()
	var footprint := global_transform * _bounds
	for child in _plants.get_children():
		var batch := child as MultiMeshInstance3D
		if batch == null or not batch.get_meta("green_grass", false) or batch.multimesh == null:
			continue
		if not (batch.global_transform * batch.get_aabb()).intersects(footprint.grow(.75)):
			continue
		var population := batch.multimesh
		var mesh_bounds := population.mesh.get_aabb()
		var foot := mesh_bounds.get_center()
		foot.y = mesh_bounds.position.y
		for index in population.instance_count:
			var stock := population.get_instance_transform(index)
			var point := to_local(batch.to_global(stock * foot))
			if not _covers_root(point):
				continue
			var hidden := stock
			hidden.origin -= batch.global_basis.inverse() * Vector3.UP * 6.
			roots.append({"batch": weakref(batch), "population": population, "index": index, "stock": stock, "hidden": hidden})
	_apply_roots(active)

func _covers_root(point: Vector3) -> bool:
	if point.x < _bounds.position.x or point.x > _bounds.end.x or point.z < _bounds.position.z or point.z > _bounds.end.z:
		return false
	var start := Vector3(point.x, _bounds.end.y + 1., point.z)
	for index in range(0, _triangles.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(start, Vector3.DOWN,
			_triangles[index], _triangles[index + 1], _triangles[index + 2])
		if hit != null and hit.y > point.y + .08:
			return true
	return false

func _apply_roots(hide_covered: bool) -> void:
	for row in roots:
		var batch: MultiMeshInstance3D = row.batch.get_ref()
		if is_instance_valid(batch) and batch.multimesh == row.population and row.index < row.population.instance_count:
			row.population.set_instance_transform(row.index, row.hidden if hide_covered else row.stock)

func _exit_tree() -> void:
	_apply_roots(false)
