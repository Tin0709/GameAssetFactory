extends Node
## Original diffuse sky visibility field derived from the fixed private grove.

const PROOF := "godot_lab/world_map_unified_showcase_v001/forest_spruce_layout_v002/field.private.json"
const PROOF_SHA := "155d6221f111ab2479aba2dae86841cf33055f5adf351789b61781eab2959d14"
const PHASE := preload("res://scripts/world_map_phase_finish.gd")
const MistSkyField = preload("res://scripts/mist_sky_field.gd")
const ActorBounce = preload("res://scripts/world_map_actor_bounce.gd")
static var _owner: WeakRef

var proof_ready := false
var applied_strength := 0.
var applied_tree_strength := 0.
var applied_edge_fill := 0.
var applied_sky_color := 0.
var applied_edge_return := 0.
var applied_ground_fill := Vector2.ZERO
var applied_terrain_contrast := 1.0
var applied_turf_reflection_color := 0.0
var applied_directional_ground := 0.0
var _directional_ground_rect := Vector4.ZERO
var _directional_ground_texture: ImageTexture
var applied_pre_twilight := 0.
var _level: Node3D
var _camera: Camera3D
var _texture: ImageTexture3D
var _origin: Vector3
var _dimensions: Vector3i
var _casters: Array[Dictionary] = []
var _east_casters: Array[MeshInstance3D] = []
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
	if proof.map_sha256 != FileAccess.get_sha256(level.map_layout_path) or proof.sources_sha256 != grove.SPRUCE_MANIFEST_SHA:
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
	RenderingServer.global_shader_parameter_set("gaf_canopy_edge_return", 0.)
	RenderingServer.global_shader_parameter_set("gaf_canopy_ground_fill", Vector2.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_canopy_terrain_contrast", 1.)
	RenderingServer.global_shader_parameter_set("gaf_canopy_turf_reflection_color", 0.)
	RenderingServer.global_shader_parameter_set("gaf_pre_twilight_receiver", 0.)
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_extent", Vector3(_dimensions))
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_volume", _texture)
	RenderingServer.global_shader_parameter_set("gaf_directional_ground_rect", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("gaf_directional_ground_sky", null)
	proof_ready = true
	set_process(true)

func apply_layout(relative: String, digest: String) -> bool:
	# Called synchronously during level setup, before either texture is sampled.
	if OS.get_environment("GAF_FOREST_BASIN_BASELINE") == "1":
		return false
	var air = _level.showcase.directional_air
	if not air.region_available():
		return false
	var root: String = air.research_root
	var profile := _layout_profile(root, relative, digest)
	var schema: String = profile.get("schema", "")
	if schema not in ["private_spruce_layout/1", "private_spruce_layout/2", "private_spruce_layout/3"] \
			or profile.map_sha256 != FileAccess.get_sha256(_level.map_layout_path) or profile.base_sky_profile_sha256 != PROOF_SHA \
			or profile.base_air_profile_sha256 != _level.directional_air_region_sha256:
		return false
	var position_world := _vector(profile.root)
	var grove = _level.grove
	var source: Node3D = grove._spruce_root.get_node_or_null(profile.source_tree)
	if source == null or source.get_meta("source_glb", "") != profile.source_glb \
			or not is_equal_approx(_level.surface_height(position_world.x, position_world.z), position_world.y):
		return false
	var mover: Node3D
	var move_to := Vector3.ZERO
	var bounce_layout_sha := digest
	var bounce_air_sha: String = profile.air_sha256
	var matched_bounce := schema == "private_spruce_layout/3"
	if schema != "private_spruce_layout/1":
		var basin_profile: String = profile.get("basin_profile", "") if matched_bounce else _level.forest_basin_layout_profile
		bounce_layout_sha = profile.get("previous_layout_sha256", "") if matched_bounce else _level.forest_basin_layout_sha256
		var previous := _layout_profile(root, basin_profile, bounce_layout_sha)
		if previous.get("schema") != "private_spruce_layout/1" or profile.get("previous_layout_sha256") != bounce_layout_sha:
			return false
		# This layout changes the main grove. The pinned parent identifies the unchanged
		# northwest basin and its local actor-bounce bake.
		for key: String in ["map_sha256", "base_sky_profile_sha256", "base_air_profile_sha256",
				"root", "source_tree", "source_glb", "sky_origin", "sky_dimensions"]:
			if profile.get(key) != previous.get(key):
				return false
		bounce_air_sha = previous.air_sha256
		mover = grove._spruce_root.get_node_or_null(profile.get("move_tree", "")) as Node3D
		if mover == null or mover.get_meta("source_glb", "") != profile.get("move_source"):
			return false
		var before: Array = profile.get("move_from", [])
		var after: Array = profile.get("move_to", [])
		if before.size() != 3 or after.size() != 3 or not mover.global_position.is_equal_approx(_vector(before)):
			return false
		move_to = _vector(after)
		if not move_to.is_finite() or not is_equal_approx(_level.surface_height(move_to.x, move_to.z), move_to.y) \
				or not _geometry_current() or not air._geometry_current():
			return false
	var dimensions := Vector3i(_vector(profile.sky_dimensions))
	var origin := _vector(profile.sky_origin)
	var air_shape := Vector3i(air.texture.get_width(), air.texture.get_height(), air.texture.get_depth())
	var directory := root.path_join(relative).get_base_dir()
	var directional: ImageTexture3D = _layout_texture(directory.path_join("directional_compact.private.r8"), profile.air_sha256, air_shape)
	var sky := _layout_texture(directory.path_join("sky.private.r8"), profile.sky_sha256, dimensions)
	if directional == null or sky == null:
		return false
	var player_light = _level.player_light
	var candidate_bounce: ActorBounce
	if matched_bounce:
		if player_light == null or not player_light.cache_ready:
			return false
		# Keep the previous placement and fields available if a matched asset is missing.
		candidate_bounce = ActorBounce.new()
		candidate_bounce.setup_region(_level, profile.get("actor_bounce_profile", ""),
			profile.get("actor_bounce_sha256", ""), bounce_layout_sha, bounce_air_sha, false)
		if not candidate_bounce.available() or not candidate_bounce._load():
			return false
	if mover != null:
		mover.global_position = move_to
		for row: Dictionary in _casters:
			if mover.is_ancestor_of(row.node):
				row.transform = row.node.global_transform
		for row: Dictionary in air._casters:
			if mover.is_ancestor_of(row.node):
				row.pose = row.node.global_transform
	for caster: MeshInstance3D in grove.place_additional_spruce(source, position_world):
		_casters.append({"node": caster, "transform": caster.global_transform, "mesh": caster.mesh})
		air._casters.append({"node": caster, "pose": caster.global_transform, "mesh": caster.mesh})
	_texture = sky
	_origin = origin
	_dimensions = dimensions
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_extent", Vector3(dimensions))
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_volume", sky)
	air.texture = directional
	_level.showcase.mist.effect.directional_grid = directional
	if _level.terrain_light != null:
		_level.terrain_light.set_day_bounce_layout(digest, air._geometry_current)
	if candidate_bounce != null:
		player_light.local_phase_bounce = candidate_bounce
	elif player_light != null and player_light.cache_ready:
		player_light.local_phase_bounce.setup_region(_level, _level.local_actor_bounce_profile,
			_level.local_actor_bounce_sha256, bounce_layout_sha, bounce_air_sha,
			_level.showcase._lighting_scale(&"player_bounce") > 0.)
	return true

func apply_canopy_extension(relative: String, digest: String, parent_path: String, parent_digest: String) -> bool:
	var air = _level.showcase.directional_air
	if not proof_ready or not air.region_available() or not _geometry_current() or not air._geometry_current():
		return false
	var root: String = air.research_root
	var profile := _layout_profile(root, relative, digest)
	if profile.get("schema") != "private_forest_sky_extension/1" or profile.get("parent") != parent_path \
			or profile.get("parent_sha256") != parent_digest:
		return false
	var parent := _layout_profile(root, parent_path, parent_digest)
	if parent.is_empty() or profile.get("parent_sky_sha256") != parent.get("sky_sha256") \
			or profile.get("base_air_sha256") != parent.get("air_sha256"):
		return false
	var coordinates := _checked_vector(profile.get("origin"))
	var extent := _checked_vector(profile.get("dimensions"))
	if not coordinates.is_equal_approx(_origin) or not extent.is_finite() or extent != extent.floor() \
			or extent.x <= _dimensions.x or extent.y != _dimensions.y or extent.z < _dimensions.z \
			or extent.x > 128. or extent.z > 128.:
		return false
	var rows: Variant = profile.get("placements")
	if not rows is Array or rows.is_empty() or rows.size() > 8:
		return false
	var placements: Array[Dictionary] = []
	for row: Variant in rows:
		var placed := _check_extension_tree(row, extent)
		if placed.is_empty():
			return false
		for previous: Dictionary in placements:
			if placed.position.distance_to(previous.position) < 4.:
				return false
		placements.append(placed)
	var directory := root.path_join(relative).get_base_dir()
	var field := _layout_texture(directory.path_join("sky.private.r8"), profile.get("sky_sha256", ""), Vector3i(extent))
	if field == null:
		return false
	# The matched directional-air atlas only traces rays toward the west.
	# Its receivers are west of these trees. The wider field adds diffuse sky
	# occlusion for foliage, terrain and mist without changing that atlas.
	var grove = _level.grove
	for i in placements.size():
		var placed := placements[i]
		for caster: MeshInstance3D in grove.place_additional_spruce(placed.source, placed.position, "EastSpruce%02d" % (i + 1)):
			_casters.append({"node": caster, "transform": caster.global_transform, "mesh": caster.mesh})
			_east_casters.append(caster)
	_texture = field
	_dimensions = Vector3i(extent)
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_extent", extent)
	RenderingServer.global_shader_parameter_set("gaf_spruce_sky_volume", field)
	return true

func _check_extension_tree(row: Variant, extent: Vector3) -> Dictionary:
	if not row is Dictionary or not row.get("source") is String or not row.source.begins_with("MD2Spruce") \
			or row.source.get_file() != row.source:
		return {}
	var position := _checked_vector(row.get("root"))
	if not position.is_finite() or position.x <= _origin.x + _dimensions.x + 4. \
			or position.x >= _origin.x + extent.x - 1. \
			or position.z <= _origin.z or position.z >= _origin.z + extent.z - 1. \
			or not is_equal_approx(_level.surface_height(position.x, position.z), position.y):
		return {}
	var source := _level.grove._spruce_root.get_node_or_null(NodePath(row.source)) as Node3D
	if source == null or source.get_meta("source_glb", "") != row.get("glb"):
		return {}
	var pose: Variant = row.get("pose")
	if not pose is Array or pose.size() != 4:
		return {}
	var basis := Basis(_checked_vector(pose[0]), _checked_vector(pose[1]), _checked_vector(pose[2]))
	var expected := Transform3D(basis, _checked_vector(pose[3]))
	for record: Dictionary in _casters:
		var caster: MeshInstance3D = record.node
		if not source.is_ancestor_of(caster):
			continue
		var current := caster.global_transform
		current.origin += position - source.global_position
		if not expected.is_finite() or not current.is_equal_approx(expected) \
				or caster.mesh.surface_get_array_index_len(0) != 3. * float(row.get("triangles", -1)):
			return {}
		return {"source":source, "position":position}
	return {}

func _checked_vector(value: Variant) -> Vector3:
	if not value is Array or value.size() != 3:
		return Vector3.INF
	for component: Variant in value:
		if not (component is float or component is int) or not is_finite(component):
			return Vector3.INF
	return _vector(value)

func _layout_profile(root: String, relative: String, digest: String) -> Dictionary:
	if relative.is_empty() or relative.is_absolute_path():
		return {}
	var path := root.path_join(relative).simplify_path()
	if not path.begins_with(root + "/") or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != digest:
		return {}
	var profile: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return profile if profile is Dictionary else {}

func load_directional_ground(relative: String, digest: String, canopy_digest: String) -> bool:
	if not proof_ready or relative.is_empty() or _owner == null or _owner.get_ref() != self:
		return false
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var profile := _layout_profile(root, relative, digest)
	if profile.get("schema") != "terrain_directional_canopy_sky/1" or profile.get("canopy_sha256") != canopy_digest \
			or profile.get("map_sha256") != FileAccess.get_sha256(_level.map_layout_path):
		return false
	var grid := _checked_vector(profile.get("grid"))
	var origin := _checked_vector(profile.get("origin"))
	var height_span: Variant = profile.get("height_span")
	if not grid.is_finite() or not origin.is_finite() or grid.x != floorf(grid.x) or grid.y != floorf(grid.y) \
			or grid.x < 2.0 or grid.y < 2.0 or grid.x > 256.0 or grid.y > 256.0 or grid.z < .25 or grid.z > 2.0 \
			or not (height_span is float or height_span is int) or not is_finite(height_span) or height_span <= 0.0:
		return false
	var size := Vector2i(int(grid.x), int(grid.y))
	var path := root.path_join(relative).get_base_dir().path_join("terrain_canopy_sky.rg8")
	if not FileAccess.file_exists(path):
		return false
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() != size.x * size.y * 2 or FileAccess.get_sha256(path) != profile.get("payload_sha256"):
		return false
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RG8, data)
	_directional_ground_texture = ImageTexture.create_from_image(image)
	if _directional_ground_texture == null:
		return false
	_directional_ground_rect = Vector4(origin.x, origin.z, grid.z, 0.0)
	RenderingServer.global_shader_parameter_set("gaf_directional_ground_height", Vector2(origin.y, height_span))
	RenderingServer.global_shader_parameter_set("gaf_directional_ground_sky", _directional_ground_texture)
	return true


func _layout_texture(path: String, digest: String, dimensions: Vector3i) -> ImageTexture3D:
	if not FileAccess.file_exists(path):
		return null
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() != dimensions.x * dimensions.y * dimensions.z or FileAccess.get_sha256(path) != digest:
		return null
	return _level.showcase.directional_air._make_texture(data, dimensions)

func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func _geometry_current() -> bool:
	for row in _casters:
		var caster: MeshInstance3D = row.node
		if not is_instance_valid(caster) or caster.mesh != row.mesh or not caster.global_transform.is_equal_approx(row.transform):
			return false
	return true

func mist_sky_field() -> MistSkyField:
	var field := MistSkyField.new()
	field.texture = _texture
	field.origin = _origin
	return field

func mist_sky_current() -> bool:
	return proof_ready and _level.grove.visible and _level.grove.spruce_visible() and _geometry_current()

func east_casters_current() -> bool:
	return not _east_casters.is_empty() and _geometry_current() and _east_casters.all(
		func(caster: MeshInstance3D) -> bool: return caster.is_visible_in_tree())

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not proof_ready or _owner == null or _owner.get_ref() != self:
		applied_strength = 0.
		applied_tree_strength = 0.
		applied_edge_fill = 0.
		applied_sky_color = 0.
		applied_edge_return = 0.
		applied_ground_fill = Vector2.ZERO
		applied_terrain_contrast = 1.0
		applied_turf_reflection_color = 0.0
		applied_directional_ground = 0.0
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
	var edge_return := 0.
	if sky_color > 0.:
		var hour: float = review.hour
		var early := 1. - smoothstep(7., 11.5, hour)
		var late := smoothstep(12.5, 16.5, hour) * (1. - smoothstep(16.5, 18.5, hour))
		edge_return = review._lighting_scale(&"canopy_edge_return") * maxf(early, late)
	if edge_return != applied_edge_return:
		applied_edge_return = edge_return
		RenderingServer.global_shader_parameter_set("gaf_canopy_edge_return", edge_return)
	var ground_fill: Vector2 = review.canopy_ground_fill_strength() if strength > 0. else Vector2.ZERO
	if ground_fill != applied_ground_fill:
		applied_ground_fill = ground_fill
		RenderingServer.global_shader_parameter_set("gaf_canopy_ground_fill", ground_fill)
	var contrast: float = review.canopy_terrain_contrast() if ground_fill.x > 0. else 1.
	if contrast != applied_terrain_contrast:
		applied_terrain_contrast = contrast
		RenderingServer.global_shader_parameter_set("gaf_canopy_terrain_contrast", contrast)
	var turf_reflection_color := 0.0
	if ground_fill.x > 0.0 and review._biome_profile != null:
		var profile_strength: float = review._biome_profile.canopy_turf_reflection_color
		if is_finite(profile_strength):
			turf_reflection_color = clampf(profile_strength, 0.0, 1.0) * minf(ground_fill.x / .55, 1.0)
	if turf_reflection_color != applied_turf_reflection_color:
		applied_turf_reflection_color = turf_reflection_color
		RenderingServer.global_shader_parameter_set("gaf_canopy_turf_reflection_color", turf_reflection_color)
	var directional_ground := 0.0
	if ground_fill.x > 0.0 and _directional_ground_rect.z > 0.0 and review._biome_profile != null:
		var profile: Resource = review._biome_profile
		var curve: Curve = profile.directional_ground_sky_by_hour
		if curve != null:
			var weather := lerpf(1.0, profile.directional_ground_sky_overcast, review._weather.weight)
			directional_ground = clampf(curve.sample(review.hour / 24.0), 0.0, 1.0) * weather
			directional_ground *= review._lighting_scale(&"canopy_ground_fill")
	if directional_ground != applied_directional_ground:
		applied_directional_ground = directional_ground
		_directional_ground_rect.w = directional_ground
		RenderingServer.global_shader_parameter_set("gaf_directional_ground_rect", _directional_ground_rect)
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
		RenderingServer.global_shader_parameter_set("gaf_canopy_edge_return", 0.)
		RenderingServer.global_shader_parameter_set("gaf_canopy_ground_fill", Vector2.ZERO)
		RenderingServer.global_shader_parameter_set("gaf_canopy_terrain_contrast", 1.)
		RenderingServer.global_shader_parameter_set("gaf_canopy_turf_reflection_color", 0.)
		RenderingServer.global_shader_parameter_set("gaf_pre_twilight_receiver", 0.)
		RenderingServer.global_shader_parameter_set("gaf_spruce_sky_volume", null)
		RenderingServer.global_shader_parameter_set("gaf_directional_ground_rect", Vector4.ZERO)
		RenderingServer.global_shader_parameter_set("gaf_directional_ground_sky", null)
		_owner = null
