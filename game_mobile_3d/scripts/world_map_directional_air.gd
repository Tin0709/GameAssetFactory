extends RefCounted
## Shared directional visibility for the private WorldMap canopy and terrain.
const Phase := preload("res://scripts/world_map_phase_finish.gd")
const FOLDER := "godot_lab/world_map_unified_showcase_v001/forest_foliage_key_balance_v001/"
const PROOF := "daylight_cycle_v002/bake.private.json"
const PROOF_SHA := "b42714324d7bf272d0680ead4b1c4877e80851f4cdef509324d47ee6b4d82627"
const OAK_MANIFEST_SHA := "a0c313c78d5a729f0fd14b245ae0f164d657afa6d6b3a9389e04cb5ad0089cf6"
const MAX_GAIN := .42
const ZERO := [0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.]

var texture: ImageTexture3D
var research_root: String
var payload_sha256: String
var _level: Node3D
var _review: Node
var _sun: DirectionalLight3D
var _hours: Array[float] = []
var _directions: Array[Vector3] = []
var _slots: Array[int] = []
var _casters: Array[Dictionary] = []
var _origin: Vector3
var _tile: Vector3
var _step: float
var _columns: int
var _region: PackedFloat32Array

func setup(level: Node3D, review: Node) -> void:
	if not OS.has_feature("editor") or RenderingServer.get_current_rendering_method() != "mobile" \
		or RenderingServer.get_rendering_device() == null or level.grove == null \
		or not level.grove.source_oaks or not level.grove.spruce_available():
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return
	var folder := root.path_join(FOLDER)
	var proof_path := folder.path_join(PROOF)
	if not FileAccess.file_exists(proof_path) or FileAccess.get_sha256(proof_path) != PROOF_SHA:
		return
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(proof_path))
	var geometry_path := folder.path_join("geometry.private.json")
	if proof.map_sha256 != FileAccess.get_sha256(level.map_layout_path) or FileAccess.get_sha256(geometry_path) != proof.geometry_sha256 \
		or FileAccess.get_sha256(root.path_join(level.grove.SOURCE_MANIFEST)) != OAK_MANIFEST_SHA:
		return
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
	var nodes: Dictionary = {}
	for caster: MeshInstance3D in level.find_children("*Shadow", "MeshInstance3D", true, false):
		if caster.material_override not in [level.grove._canopy_shadow, level.grove._spruce_shadow]:
			continue
		var tree := caster.get_parent()
		while tree != level and not str(tree.name).begins_with("MD2Oak") and not str(tree.name).begins_with("MD2Spruce"):
			tree = tree.get_parent()
		if tree != level:
			nodes[str(tree.name)] = [caster, tree.get_meta("source_glb", "")]
	if nodes.size() != geometry.trees.size():
		return
	for row: Dictionary in geometry.trees:
		if not nodes.has(row.name) or nodes[row.name][1] != row.source:
			return
		var caster: MeshInstance3D = nodes[row.name][0]
		var m: Array = row.transform
		var pose := Transform3D(Basis(_vector(m[0]), _vector(m[1]), _vector(m[2])), _vector(m[3]))
		if not caster.global_transform.is_equal_approx(pose) or caster.mesh.surface_get_array_len(0) != int(row.vertices) \
			or caster.mesh.surface_get_array_index_len(0) != int(row.indices):
			return
		_casters.append({"node": caster, "pose": pose, "mesh": caster.mesh})
	var path := proof_path.get_base_dir().path_join("daylight.private.r8")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != proof.sha256:
		return
	var shape := Vector3i(_vector(proof.dimensions))
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() != shape.x * shape.y * shape.z:
		return
	_origin = _vector(proof.origin)
	_tile = _vector(proof.size)
	_step = proof.step
	_columns = int(proof.columns)
	var extension := _load_region(level, root, proof, data, shape)
	if not extension.is_empty():
		var extended: ImageTexture3D = _make_texture(extension.data, extension.shape)
		if extended != null:
			texture = extended
			_region = extension.parameters
	if texture == null:
		texture = _make_texture(data, shape)
	if texture == null:
		return
	_hours.assign(proof.hours)
	_slots.assign(proof.slots)
	for row: Array in proof.directions:
		_directions.append(_vector(row).normalized())
	_level = level
	_review = review
	_sun = level.get_node("Sun")
	research_root = root
	payload_sha256 = proof.sha256

func _load_region(level: Node3D, root: String, proof: Dictionary, base: PackedByteArray, base_shape: Vector3i) -> Dictionary:
	var relative: String = level.get("directional_air_region_profile") if level.get("directional_air_region_profile") is String else ""
	var digest: String = level.get("directional_air_region_sha256") if level.get("directional_air_region_sha256") is String else ""
	if relative.is_empty() or relative.is_absolute_path() or not digest.is_valid_hex_number() or digest.length() != 64:
		return {}
	var path := root.path_join(relative).simplify_path()
	if not path.begins_with(root + "/") or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != digest:
		return {}
	var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not profile is Dictionary or profile.get("schema") != "private_directional_air_region/1" or profile.get("base_sha256") != proof.sha256:
		return {}
	var shape := Vector3i(_vector(profile.dimensions))
	var local := Vector3i(_vector(profile.local_tile))
	var origin := _vector(profile.local_origin)
	var offset := int(profile.local_z_offset)
	var columns := int(profile.local_columns)
	if shape.x != base_shape.x or shape.y != base_shape.y or shape.z != offset + local.z or offset != base_shape.z \
			or shape.z > 256 or local.x < 2 or local.y < 2 or local.z < 2 or columns < 1 or columns * local.x > shape.x \
			or ceili(float(proof.unique) / columns) * local.y > shape.y or not origin.is_finite():
		return {}
	# The two volumes may share an atlas but their world-space samples must be disjoint.
	if origin.z + (local.z - 1) * _step >= _origin.z:
		return {}
	var payload := path.get_base_dir().path_join("directional.private.r8")
	if not FileAccess.file_exists(payload) or FileAccess.get_sha256(payload) != profile.sha256:
		return {}
	var bytes := FileAccess.get_file_as_bytes(payload)
	if bytes.size() != shape.x * shape.y * shape.z or bytes.slice(0, base.size()) != base:
		return {}
	return {"data": bytes, "shape": shape, "parameters": PackedFloat32Array([
		origin.x, origin.y, origin.z, offset, local.x, local.y, local.z, columns])}

func _make_texture(data: PackedByteArray, shape: Vector3i) -> ImageTexture3D:
	var slice_size := shape.x * shape.y
	var slices: Array[Image] = []
	for z in shape.z:
		slices.append(Image.create_from_data(shape.x, shape.y, false, Image.FORMAT_R8, data.slice(z * slice_size, (z + 1) * slice_size)))
	var image := ImageTexture3D.new()
	return image if image.create(Image.FORMAT_R8, shape.x, shape.y, shape.z, false, slices) == OK else null

func available() -> bool:
	return texture != null

func region_available() -> bool:
	return _region.size() == 8

func volume_parameters() -> PackedFloat32Array:
	var values := parameters()
	if region_available():
		values[15] = _review._lighting_scale(&"basin_sunlit_mist")
		values.append_array(_region)
	return values

func parameters() -> PackedFloat32Array:
	if not available() or not is_instance_valid(_review):
		return PackedFloat32Array(ZERO)
	var gain: float = _review._lighting_scale(&"sunlit_mist")
	if gain <= 0.:
		return PackedFloat32Array(ZERO)
	var slots := sun_slots()
	if slots.w <= 0.:
		return PackedFloat32Array(ZERO)
	var c := _sun.light_color.srgb_to_linear()
	var rgb := Vector3(c.r, c.g, c.b) * _sun.light_energy
	return PackedFloat32Array([rgb.x, rgb.y, rgb.z, gain * slots.w,
		slots.x, slots.y, slots.z, _columns,
		_origin.x, _origin.y, _origin.z, _step, _tile.x, _tile.y, _tile.z, 0.])

func sun_slots() -> Vector4:
	if not available() or not is_instance_valid(_review) or not _review.forest_active() \
		or _review.atmosphere_review != "combined" or not _level.grove.visible or not _level.grove.spruce_visible() \
		or not _level.grove.spruce_shadows or not _sun.shadow_enabled or not _sun.is_visible_in_tree():
		return Vector4.ZERO
	var h: float = _review.hour
	var gain := Phase.phase_weight(h) * smoothstep(5.5, 6.5, h) * (1. - smoothstep(18.5, 19.5, h))
	gain *= smoothstep(0., .2, _sun.shadow_opacity)
	if gain <= 0. or _sun.light_energy <= 0.:
		return Vector4.ZERO
	var sample_hour := h
	if _review.sunrise_elevation_active:
		sample_hour = _hour_for_elevation(_sun.global_basis.z.y, h)
	var high := clampi(_hours.bsearch(sample_hour), 1, _hours.size() - 1)
	var low := high - 1
	var weight := inverse_lerp(_hours[low], _hours[high], sample_hour)
	var expected := _directions[low].slerp(_directions[high], weight)
	var error := expected.angle_to(_sun.global_basis.z.normalized())
	gain *= 1. - smoothstep(deg_to_rad(.45), deg_to_rad(1.35), error)
	if gain <= 0. or not _geometry_current():
		return Vector4.ZERO
	return Vector4(_slots[low], _slots[high], weight, gain)

func _hour_for_elevation(up: float, fallback: float) -> float:
	# Find a morning bracket in the existing visibility atlas. The azimuth
	# guard in sun_slots still rejects directions not supported by this bake.
	for i in range(1, _directions.size()):
		if _hours[i] > 12.0:
			break
		var low := _directions[i - 1].y
		var high := _directions[i].y
		if high > low and up >= low and up <= high:
			return lerpf(_hours[i - 1], _hours[i], inverse_lerp(low, high, up))
	return fallback


func _geometry_current() -> bool:
	for row: Dictionary in _casters:
		var node: MeshInstance3D = row.node
		if not is_instance_valid(node) or node.mesh != row.mesh or not node.is_visible_in_tree() \
			or not node.global_transform.is_equal_approx(row.pose):
			return false
	return true

func _vector(row: Array) -> Vector3:
	return Vector3(row[0], row[1], row[2])
