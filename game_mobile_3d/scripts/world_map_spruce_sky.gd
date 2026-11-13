extends Node
## Original diffuse sky visibility field derived from the fixed private grove.

const PROOF := "godot_lab/world_map_unified_showcase_v001/forest_spruce_layout_v002/field.private.json"
const PROOF_SHA := "155d6221f111ab2479aba2dae86841cf33055f5adf351789b61781eab2959d14"
const PHASE := preload("res://scripts/world_map_phase_finish.gd")
static var _owner: WeakRef

var proof_ready := false
var applied_strength := 0.
var applied_tree_strength := 0.
var applied_edge_fill := 0.
var applied_sky_color := 0.
var applied_pre_twilight := 0.
var _level: Node3D
var _camera: Camera3D
var _texture: ImageTexture3D
var _origin: Vector3
var _dimensions: Vector3i
var _casters: Array[Dictionary] = []
var _published_camera := Vector3.INF

func setup(level: Node3D) -> void:
	_level = level
	_camera = level.get_node("Camera3D")
	process_priority = 90
	set_process(false)
	var grove = level.grove
	if not OS.has_feature("editor") or grove == null or not grove.spruce_available():
		return
	if RenderingServer.get_current_rendering_method() != "mobile" or RenderingServer.get_rendering_device() == null:
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	var path := root.path_join(PROOF)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != PROOF_SHA:
		return
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if proof.map_sha256 != FileAccess.get_sha256(level.DATA) or proof.sources_sha256 != grove.SPRUCE_MANIFEST_SHA:
		return
	for row: Dictionary in proof.trees:
		var tree: Node3D = grove._spruce_root.get_node_or_null(row.name)
		if tree == null or tree.get_meta("source_glb", "") != row.source:
			return
		var matched: MeshInstance3D
		for caster: MeshInstance3D in grove._spruce_casters:
			if tree.is_ancestor_of(caster):
				matched = caster
				break
		if matched == null:
			return
		var columns: Array = row.transform
		var transform := Transform3D(Basis(_vector(columns[0]), _vector(columns[1]), _vector(columns[2])), _vector(columns[3]))
		if not matched.global_transform.is_equal_approx(transform):
			return
		_casters.append({"node": matched, "transform": transform, "mesh": matched.mesh})
	if _casters.size() != grove._spruce_casters.size():
		return
	var payload := path.get_base_dir().path_join("canopy.private.r8")
	if not FileAccess.file_exists(payload) or FileAccess.get_sha256(payload) != proof.payload_sha256:
		return
	_origin = _vector(proof.origin)
	_dimensions = Vector3i(_vector(proof.dimensions))
	var bytes := FileAccess.get_file_as_bytes(payload)
	var slice_size := _dimensions.x * _dimensions.y
	if bytes.size() != slice_size * _dimensions.z:
		return
	var slices: Array[Image] = []
	for z in _dimensions.z:
		slices.append(Image.create_from_data(_dimensions.x, _dimensions.y, false, Image.FORMAT_R8,
			bytes.slice(z * slice_size, (z + 1) * slice_size)))
	_texture = ImageTexture3D.new()
	if _texture.create(Image.FORMAT_R8, _dimensions.x, _dimensions.y, _dimensions.z, false, slices) != OK:
		return
	_owner = weakref(self)
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_region", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_grove_sky_strength", 0.)
	RenderingServer.global_shader_parameter_set("gaf_canopy_edge_fill", 0.)
	RenderingServer.global_shader_parameter_set("gaf_canopy_sky_color", 0.)
	RenderingServer.global_shader_parameter_set("gaf_pre_twilight_receiver", 0.)
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_extent", Vector3(_dimensions))
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_volume", _texture)
	proof_ready = true
	set_process(true)

func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func _geometry_current() -> bool:
	for row in _casters:
		var caster: MeshInstance3D = row.node
		if not is_instance_valid(caster) or caster.mesh != row.mesh or not caster.global_transform.is_equal_approx(row.transform):
			return false
	return true

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not proof_ready or _owner == null or _owner.get_ref() != self:
		applied_strength = 0.
		applied_tree_strength = 0.
		applied_edge_fill = 0.
		applied_sky_color = 0.
		applied_pre_twilight = 0.
		return
	var strength := 0.
	var review = _level.showcase
	if _level.view_mode == "gameplay" and _level.grove.spruce_visible() and review.forest_spatial_sky_context():
		strength = review._lighting_scale(&"spruce_sky") * PHASE.phase_weight(review.hour)
		if strength > 0. and not _geometry_current():
			strength = 0.
	if strength != applied_strength:
		applied_strength = strength
		RenderingServer.global_shader_parameter_set("gaf_spruce_sky_region", Vector4(_origin.x, _origin.y, _origin.z, strength))
	var tree_strength := 0.
	if strength > 0.:
		tree_strength = review._lighting_scale(&"tree_shade") * review._balanced_daylight_weight()
	if tree_strength != applied_tree_strength:
		applied_tree_strength = tree_strength
		RenderingServer.global_shader_parameter_set("gaf_grove_sky_strength", tree_strength)
	var edge_fill := 0.
	if strength > 0. and not review._balanced_preview:
		edge_fill = review._lighting_scale(&"canopy_edge_fill") * review._balanced_daylight_weight()
	if edge_fill != applied_edge_fill:
		applied_edge_fill = edge_fill
		RenderingServer.global_shader_parameter_set("gaf_canopy_edge_fill", edge_fill)
	var sky_color := 0.
	if strength > 0. and not review._balanced_preview and review.atmosphere_review == "combined":
		sky_color = review._lighting_scale(&"canopy_sky_color") * PHASE.phase_weight(review.hour) * review._balanced_daylight_weight()
	if sky_color != applied_sky_color:
		applied_sky_color = sky_color
		RenderingServer.global_shader_parameter_set("gaf_canopy_sky_color", sky_color)
	var receiver: float = review.pre_twilight_receiver_weight()
	if receiver != applied_pre_twilight:
		applied_pre_twilight = receiver
		RenderingServer.global_shader_parameter_set("gaf_pre_twilight_receiver", receiver)
	if (strength > 0. or receiver > 0.) and _published_camera != _camera.global_position:
		_published_camera = _camera.global_position
		RenderingServer.global_shader_parameter_set("gaf_spruce_sky_camera", _published_camera)

func _exit_tree() -> void:
	if _owner != null and _owner.get_ref() == self:
		RenderingServer.global_shader_parameter_set("gaf_spruce_sky_region", Vector4.ZERO)
		RenderingServer.global_shader_parameter_set("gaf_grove_sky_strength", 0.)
		RenderingServer.global_shader_parameter_set("gaf_canopy_edge_fill", 0.)
		RenderingServer.global_shader_parameter_set("gaf_canopy_sky_color", 0.)
		RenderingServer.global_shader_parameter_set("gaf_pre_twilight_receiver", 0.)
		RenderingServer.global_shader_parameter_set("gaf_spruce_sky_volume", null)
		_owner = null
