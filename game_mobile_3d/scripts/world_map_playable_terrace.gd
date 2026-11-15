extends Node3D
## An editor-only terrain insert. A map supplies the baked placement and support.

const AssetPackage := preload("res://scripts/world_map_distant_terrain.gd")
const TerrainShader := preload("res://materials/world_map_playable_terrace.gdshader")

var visual: MeshInstance3D
var collider: StaticBody3D
var material: ShaderMaterial
var support: Dictionary[Vector2i, float] = {}
var roots: Array[Dictionary] = []
var active := false
var requested := true
var _world: Node3D
var _plants: Node3D
var _refresh_pending := false
var _original_surface: Callable

static func read_profile(world: Node3D, relative_path: String, expected_sha: String) -> Dictionary:
	if relative_path.is_empty() or relative_path.is_absolute_path() or expected_sha.length() != 64:
		return {}
	if not OS.has_feature("editor") or RenderingServer.get_current_rendering_method() != "mobile" \
			or RenderingServer.get_rendering_device() == null:
		return {}
	var root := AssetPackage.research_root()
	if root.is_empty():
		return {}
	var path := root.path_join(relative_path.replace("\\", "/")).simplify_path()
	if not path.begins_with(root + "/") or FileAccess.get_sha256(path) != expected_sha:
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("layout_sha256", "") != FileAccess.get_sha256(world.map_layout_path):
		return {}
	return data

func configure(world: Node3D, plants: Node3D, source: Mesh, atlas: Texture2D, profile: Dictionary) -> bool:
	if source == null or atlas == null or not is_instance_valid(plants):
		return false
	var position := _vector(profile.get("position", []))
	var offset := _vector(profile.get("offset", []))
	var yaw := float(profile.get("yaw", NAN))
	if not position.is_finite() or not offset.is_finite() or not is_finite(yaw):
		return false
	var center := source.get_aabb().get_center()
	center.y = source.get_aabb().position.y
	var rotation := Basis(Vector3.UP, yaw)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.append_from(source, 0, Transform3D(rotation, position - rotation * center))
	var prepared := builder.commit()
	var streams := prepared.surface_get_arrays(0)
	var sky := PackedFloat32Array(profile.get("sky", []))
	if sky.size() != streams[Mesh.ARRAY_VERTEX].size():
		return false
	for sample: float in sky:
		if not is_finite(sample) or sample < 0. or sample > 1.:
			return false
	streams[Mesh.ARRAY_CUSTOM0] = sky
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, streams, [], {},
		Mesh.ARRAY_FORMAT_CUSTOM0 | (Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT))
	var raw: Array = profile.get("faces", [])
	if raw.is_empty() or raw.size() % 9 != 0:
		return false
	var faces := PackedVector3Array()
	for index in range(0, raw.size(), 3):
		var point := Vector3(raw[index], raw[index + 1], raw[index + 2])
		if not point.is_finite():
			return false
		faces.append(point)
	for row in profile.get("support", []):
		if row.size() != 3 or not is_finite(float(row[2])):
			return false
		support[Vector2i(row[0], row[1])] = float(row[2])
	if support.is_empty():
		return false
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collider = StaticBody3D.new()
	collider.name = "GroundSupport"
	collider.collision_layer = 0
	collider.collision_mask = 0
	collider.add_child(collision_shape)
	add_child(collider)
	material = ShaderMaterial.new()
	material.shader = TerrainShader
	material.set_shader_parameter("source_atlas", atlas)
	visual = MeshInstance3D.new()
	visual.name = "Surface"
	visual.mesh = mesh
	visual.material_override = material
	visual.hide()
	add_child(visual)
	_world = world
	_plants = plants
	self.position = offset
	return true

static func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2]) if values.size() == 3 else Vector3.INF

func _ready() -> void:
	_original_surface = _plants.interaction.surface_height_provider
	_plants.interaction.surface_height_provider = surface_height
	_plants.child_order_changed.connect(_queue_root_refresh)
	_refresh_roots()
	_sync()

func _process(_delta: float) -> void:
	_sync()

func set_requested(value: bool) -> void:
	requested = value
	_sync()

func _sync() -> void:
	var wanted: bool = requested and _world.look.stage == 2
	if wanted == active or (wanted and _would_intersect_player()):
		return
	active = wanted
	visual.visible = active
	collider.collision_layer = 1 if active else 0
	_place_roots(active)
	if _world.showcase.mist != null:
		_world.showcase.mist._process(0.)

func _would_intersect_player() -> bool:
	var at: Vector3 = _world.player.global_position
	var cell := Vector2i(floori(at.x * 2.), floori(at.z * 2.))
	for x in range(-1, 2):
		for z in range(-1, 2):
			var roof: float = support.get(cell + Vector2i(x, z), -INF)
			if at.y < roof - .015:
				return true
	return false

func surface_height(x: float, z: float) -> float:
	var floor: float = _original_surface.call(x, z)
	return support.get(Vector2i(floori(x * 2.), floori(z * 2.)), floor) if active else floor

func _queue_root_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	_refresh_roots.call_deferred()

func _refresh_roots() -> void:
	_refresh_pending = false
	_place_roots(false)
	roots.clear()
	var footprint := visual.global_transform * visual.get_aabb()
	for batch in _plants.get_children():
		if not batch is MultiMeshInstance3D or not batch.get_meta("green_grass", false):
			continue
		var batch_bounds: AABB = batch.global_transform * batch.get_aabb()
		if not footprint.grow(1.).intersects(batch_bounds):
			continue
		var population: MultiMesh = batch.multimesh
		var mesh_bounds := population.mesh.get_aabb()
		var foot := mesh_bounds.get_center()
		foot.y = mesh_bounds.position.y
		for index in population.instance_count:
			var original := population.get_instance_transform(index)
			var at: Vector3 = batch.to_global(original * foot)
			var top: float = support.get(Vector2i(floori(at.x * 2.), floori(at.z * 2.)), -INF)
			if top <= at.y + .07:
				continue
			var raised := original
			raised.origin += batch.global_basis.inverse() * Vector3(0., top - at.y, 0.)
			roots.append({"batch": batch, "mesh": population, "index": index, "original": original, "raised": raised})
			if active:
				population.set_instance_transform(index, raised)

func _place_roots(raised: bool) -> void:
	for root: Dictionary in roots:
		if is_instance_valid(root.batch) and root.batch.get_parent() == _plants:
			root.mesh.set_instance_transform(root.index, root.raised if raised else root.original)

func _exit_tree() -> void:
	if is_instance_valid(_plants) and _plants.interaction.surface_height_provider == surface_height:
		_plants.interaction.surface_height_provider = _original_surface
		_place_roots(false)
