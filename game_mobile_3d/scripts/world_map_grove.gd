extends Node3D
## Woodland planting. Editor research trees are loaded from the private workspace.
const SOURCE_MANIFEST := "godot_lab/world_map_unified_showcase_v001/grove_mist_continuity_v001/native_oaks/sources.private.json"
const SPRUCE_MANIFEST := "godot_lab/world_map_unified_showcase_v001/forest_spruce_shadow_v001/sources.private.json"
const SPRUCE_MANIFEST_SHA := "e26848637c3c3d700d3f9bf7d0197b9da96ccbd492fdce4cdcd387246dc577c7"
const SPRUCE_PLACEMENTS := [
	Vector4(-37.5, 5.5, 0, 0), Vector4(-31.5, -2.5, 1, 1),
	Vector4(-22.5, 0.5, 2, 3), Vector4(-16.5, 7.5, 3, 0),
	Vector4(-35.5, 15.5, 1, 2), Vector4(-26.0, 19.0, 4, 1),
	Vector4(-40.5, 22.5, 2, 0),
]
const LEAF_PROOF := "godot_lab/leaf_vertex_material_v001/profile.private.json"
const LEAF_PROOF_SHA := "b4f10be37bfc16bab2b8c06a669619dafe5b9c5942b157421c4fe1cb30f56444"
const LEAF_DRAW_CONSTANTS := "graphics_vfx/gpu_capture_20261029/terrain_foliage_reconstruction/bindings/event879_PIX_GENERIC_PIPELINE_STAGE_PS_r2.bin"
const LEAF_DRAW_SHA := "5c4234fad3f6a08209897ef737b638a7e8086b5459b79d9cbecd86cafaa24966"
const OAKS := [
	"res://assets/environment/forest_canopy_v3/tree_oak_a.glb",
	"res://assets/environment/forest_canopy_v3/tree_oak_b.glb",
]
const PLACEMENTS := [
	Vector4(-33.4, 5.7, 0.88, 0.6),
	Vector4(-29.0, 1.3, 0.78, 1.25),
	Vector4(-25.0, 3.7, 0.91, 2.0),
	Vector4(-17.8, 11.5, 0.82, 0.1),
	Vector4(-4.6, -3.5, 0.89, 0.7),
	Vector4(4.45, -8.45, 0.90, 2.1),
	Vector4(-9.45, 3.65, 0.82, 0.35),
	Vector4(5.54, -0.55, 0.76, 1.5),
	Vector4(21.5, 7.6, 0.91, 2.65),
	Vector4(26.35, 12.35, 0.84, 0.96),
]
const REVIEW_POSITION := Vector2(-27.5, 8.0)
# Small authored pockets on the meadow approaches and east path. The schematic and its
# vegetation batches remain separately inspectable.
const UNDERSTORY := {
	Vector2i(0, -4): {
		"short_grass": [Vector2(-5.75,-3.18), Vector2(-4.16,-4.47), Vector2(-3.64,-2.36), Vector2(-2.72,-4.52), Vector2(1.82,-5.42), Vector2(2.43,-4.65), Vector2(3.29,-5.51), Vector2(4.37,-4.77), Vector2(5.30,-8.63)],
		"tall_grass": [Vector2(-5.47,-4.36), Vector2(-3.36,-3.57), Vector2(-2.47,-6.41), Vector2(2.37,-5.63), Vector2(5.28,-4.27)],
		"flower_white": [Vector2(-3.41,-4.62), Vector2(-2.38,-3.58), Vector2(-1.76,-4.33), Vector2(2.68,-6.33)],
		"flower_blue": [Vector2(2.64,-3.28), Vector2(3.27,-3.61), Vector2(3.74,-4.32), Vector2(4.75,-5.64)],
		"flower_yellow": [Vector2(-6.32,-3.63), Vector2(-5.43,-2.53), Vector2(-4.19,-2.54), Vector2(-2.75,-5.48)],
		"flower_red": [Vector2(5.51,-5.35), Vector2(6.37,-6.65)],
	},
	Vector2i(-27, 7): {
		"short_grass": [Vector2(-34.72,5.36), Vector2(-33.43,4.38), Vector2(-34.63,6.34), Vector2(-30.62,6.43), Vector2(-28.26,9.41), Vector2(-27.41,9.63), Vector2(-25.62,7.37), Vector2(-25.37,6.62), Vector2(-24.59,8.49), Vector2(-17.66,10.44), Vector2(-17.56,12.64), Vector2(-18.38,10.52)],
		"tall_grass": [Vector2(-32.57,4.42), Vector2(-28.57,10.44), Vector2(-26.62,8.62), Vector2(-24.73,7.55), Vector2(-16.68,11.63)],
		"flower_white": [Vector2(-27.57,8.71), Vector2(-26.38,9.67), Vector2(-25.41,9.37), Vector2(-17.67,13.32)],
		"flower_blue": [Vector2(-26.49,5.45), Vector2(-24.31,6.56), Vector2(-25.44,5.34)],
		"flower_yellow": [Vector2(-34.63,4.43), Vector2(-32.37,5.37), Vector2(-32.76,6.62), Vector2(-19.59,10.38)],
		"flower_red": [Vector2(-24.72,9.29), Vector2(-16.63,10.69)],
	},
	Vector2i(6, -1): {
		"short_grass": [Vector2(2.52, -2.35), Vector2(4.37, -3.42), Vector2(7.31, 0.34), Vector2(6.48, 1.72)],
		"tall_grass": [Vector2(3.34, -2.4), Vector2(8.37, -1.44)],
		"flower_white": [Vector2(1.43, -3.38), Vector2(7.27, -1.92)],
		"flower_blue": [Vector2(4.63, -1.66), Vector2(5.34, -1.27), Vector2(6.28, -1.42)],
		"flower_yellow": [Vector2(7.37, -0.44)],
		"flower_red": [Vector2(4.38, 0.48)],
	},
	Vector2i(-9, 4): {
		"short_grass": [Vector2(-11.61, 3.32), Vector2(-7.56, 5.23), Vector2(-4.73, 3.48)],
		"tall_grass": [Vector2(-11.66, 4.55), Vector2(-6.68, 2.36)],
		"flower_blue": [Vector2(-6.46, 5.38)],
		"flower_yellow": [Vector2(-11.53, 2.52), Vector2(-9.65, 2.34), Vector2(-10.47, 3.66)],
		"flower_red": [Vector2(-6.39, 4.44)],
	},
	Vector2i(23, 8): {
		"short_grass": [Vector2(20.37, 6.46), Vector2(22.47, 6.55), Vector2(23.43, 8.42), Vector2(24.46, 10.62)],
		"tall_grass": [Vector2(20.48, 8.42), Vector2(22.43, 9.35)],
		"flower_white": [Vector2(22.58, 8.62)],
		"flower_blue": [Vector2(20.55, 7.35), Vector2(21.49, 8.5), Vector2(21.68, 9.39)],
		"flower_yellow": [Vector2(22.45, 7.41), Vector2(23.34, 9.57)],
	},
	Vector2i(26, 13): {
		"short_grass": [Vector2(24.41, 11.63), Vector2(26.69, 10.47), Vector2(26.42, 14.41)],
		"tall_grass": [Vector2(25.56, 11.33), Vector2(25.72, 14.39)],
		"flower_white": [Vector2(25.42, 12.41), Vector2(26.43, 13.63)],
		"flower_blue": [Vector2(25.29, 13.37), Vector2(27.27, 13.43)],
		"flower_yellow": [Vector2(24.48, 12.52), Vector2(24.36, 13.46)],
		"flower_red": [Vector2(27.48, 14.49)],
	},
}
const REVEAL_SHADER := preload("res://materials/world_map_grove.gdshader")
const TRUNK_RADIUS := 0.27
const TRUNK_HEIGHT := 2.6

var _appearance := ShaderMaterial.new()
var _canopy_appearance := ShaderMaterial.new()
var _canopy_shadow := ShaderMaterial.new()
var _direct_clouds := false
var _mist_strength := -1.0
var _trunks: Array[StaticBody3D] = []
var source_oaks := false
var _source_atlas: ImageTexture
var _source_leaf_weights: ImageTexture
var _source_leaf_mesh: Mesh
var _source_leaf_hue := 0.
var _source_leaf_mix := 0.
var _spruce_root: Node3D
var _spruce_atlas: ImageTexture
var _spruce_appearance := ShaderMaterial.new()
var _spruce_shadow := ShaderMaterial.new()
var _spruce_trunks: Array[StaticBody3D] = []
var _spruce_casters: Array[MeshInstance3D] = []
var spruce_shadows := true

func build(level: Node3D) -> bool:
	hide()
	_appearance.shader = REVEAL_SHADER
	_canopy_appearance.shader = REVEAL_SHADER
	_canopy_shadow.shader = REVEAL_SHADER
	_canopy_shadow.set_shader_parameter("reveal_player", false)
	if level.showcase.private_primary:
		return _build_source_oaks(level)
	var assets: Array[PackedScene] = []
	for path: String in OAKS:
		var asset := load(path) as PackedScene
		if asset == null: return false
		assets.append(asset)
	for index in PLACEMENTS.size():
		var placement: Vector4 = PLACEMENTS[index]
		var tree := assets[index % assets.size()].instantiate() as Node3D
		if not _place_tree(level, tree, placement): return false
	return true

func _build_source_oaks(level: Node3D) -> bool:
	if not OS.has_feature("editor"): return false
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return false
	var manifest_path := root.path_join(SOURCE_MANIFEST)
	if not FileAccess.file_exists(manifest_path): return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("schema") != "private_world_map_oaks_v1": return false
	var meshes: Variant = manifest.get("meshes")
	if not meshes is Array or meshes.size() != 4: return false
	var atlas_path := _checked_source_path(root, manifest.get("atlas"), "png")
	if atlas_path.is_empty(): return false
	var image := Image.load_from_file(atlas_path)
	if image == null or image.is_empty(): return false
	_source_atlas = ImageTexture.create_from_image(image)
	var assets: Array[Node3D] = []
	for row: Variant in meshes:
		var path := _checked_source_path(root, row, "glb")
		var mesh := _load_source_tree(path)
		if mesh == null: break
		if path.get_file() == "SM_Tree_Oak_1x1_Var2.glb":
			_prepare_source_leaf_tint(root, row.sha256, mesh)
		assets.append(mesh)
	source_oaks = assets.size() == 4
	if source_oaks:
		_bind_source_atlas(_canopy_appearance)
		_bind_source_atlas(_canopy_shadow)
		for index in PLACEMENTS.size():
			var original := assets[index % assets.size()]
			var tree := Node3D.new()
			tree.name = "MD2Oak%02d" % (index + 1)
			tree.set_meta("source_glb", original.get_meta("source_glb"))
			var visual := original.duplicate() as Node3D
			# Every source trunk spans -1..0 in both horizontal axes.
			visual.position += Vector3(.5, 0., .5)
			tree.add_child(visual)
			if not _place_tree(level, tree, PLACEMENTS[index]):
				source_oaks = false
				break
	for asset in assets:
		asset.free()
	if source_oaks:
		_build_source_spruce(level, root)
	return source_oaks

func _load_source_tree(path: String) -> Node3D:
	if path.is_empty():
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var tree := document.generate_scene(state) as Node3D
	if tree != null:
		tree.set_meta("source_glb", path.get_file())
	return tree

func _build_source_spruce(level: Node3D, root: String) -> void:
	var manifest_path := root.path_join(SPRUCE_MANIFEST)
	if not FileAccess.file_exists(manifest_path) or FileAccess.get_sha256(manifest_path) != SPRUCE_MANIFEST_SHA:
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var atlas_path := _checked_source_path(root, manifest.atlas, "png")
	if atlas_path.is_empty():
		return
	var image := Image.load_from_file(atlas_path)
	if image == null or image.is_empty():
		return
	var assets: Array[Node3D] = []
	for row: Dictionary in manifest.meshes:
		var asset := _load_source_tree(_checked_source_path(root, row, "glb"))
		if asset == null:
			break
		assets.append(asset)
	if assets.size() == manifest.meshes.size():
		_place_source_spruce(level, assets, manifest.meshes, image)
	for asset in assets:
		asset.free()

func _place_source_spruce(level: Node3D, assets: Array[Node3D], rows: Array, image: Image) -> void:
	# Placement is authored for the existing walkable path. Keep the source
	# metres, UVs and mesh intact, centering each trunk on its original footprint.
	for spot: Vector4 in SPRUCE_PLACEMENTS:
		if not is_finite(level.surface_height(spot.x, spot.y)):
			return
	_spruce_atlas = ImageTexture.create_from_image(image)
	for material: ShaderMaterial in [_spruce_appearance, _spruce_shadow]:
		material.shader = REVEAL_SHADER
		_bind_spruce_atlas(material)
	_spruce_root = Node3D.new()
	_spruce_root.name = "ForestSpruce"
	for spot: Vector4 in SPRUCE_PLACEMENTS:
		var index := int(spot.z)
		var width: float = rows[index].trunk_width_m
		var tree := assets[index].duplicate() as Node3D
		tree.name = "MD2Spruce%02d" % (_spruce_root.get_child_count() + 1)
		tree.position = Vector3(spot.x, level.surface_height(spot.x, spot.y), spot.y)
		tree.rotation.y = spot.w * PI * .5
		var meshes := tree.find_children("*", "MeshInstance3D", true, false)
		for visual: MeshInstance3D in meshes:
			visual.position += Vector3(width * .5, 0., width * .5)
			_spruce_casters.append(_split_shadow(visual, _spruce_appearance, _spruce_shadow))
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, 3.4, width)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		var body := StaticBody3D.new()
		body.name = "Trunk"
		body.position.y = shape.size.y * .5
		body.add_child(collider)
		tree.add_child(body)
		_spruce_trunks.append(body)
		_spruce_root.add_child(tree)
	level.add_child(_spruce_root)

func _bind_spruce_atlas(material: ShaderMaterial) -> void:
	material.set_shader_parameter("use_source_atlas", true)
	material.set_shader_parameter("source_atlas", _spruce_atlas)

func spruce_available() -> bool:
	return is_instance_valid(_spruce_root)

func spruce_visible() -> bool:
	return spruce_available() and _spruce_root.visible

func set_spruce_visible(value: bool, player_position: Vector3, capsule: CapsuleShape3D) -> bool:
	if not spruce_available():
		return false
	if value:
		for trunk: StaticBody3D in _spruce_trunks:
			var shape: BoxShape3D = trunk.get_child(0).shape
			var offset := trunk.to_local(player_position)
			var margin := Vector2(shape.size.x, shape.size.z) * .5
			var horizontal := (Vector2(offset.x, offset.z).abs() - margin).max(Vector2.ZERO)
			if absf(offset.y + capsule.height * .5) < (shape.size.y + capsule.height) * .5 \
				and horizontal.length() < capsule.radius + .03:
				return false
	_spruce_root.visible = value
	for trunk: StaticBody3D in _spruce_trunks:
		trunk.collision_layer = 1 if value else 0
	return true

func set_spruce_shadows(value: bool) -> void:
	spruce_shadows = value
	for caster in _spruce_casters:
		caster.visible = value

func _checked_source_path(root: String, row: Variant, extension: String) -> String:
	if not row is Dictionary or not row.get("file") is String or not row.get("sha256") is String:
		return ""
	var relative: String = row.file
	if relative.is_absolute_path() or relative.get_extension().to_lower() != extension: return ""
	var path := root.path_join(relative.replace("\\", "/")).simplify_path()
	if not path.begins_with(root + "/extracted/") or not FileAccess.file_exists(path): return ""
	return path if FileAccess.get_sha256(path) == row.sha256 else ""

func _bind_source_atlas(material: ShaderMaterial) -> void:
	material.set_shader_parameter("use_source_atlas", true)
	material.set_shader_parameter("source_atlas", _source_atlas)
	if material == _canopy_appearance and _source_leaf_weights != null:
		material.set_shader_parameter("source_leaf_weights", _source_leaf_weights)
		material.set_shader_parameter("source_leaf_hue", _source_leaf_hue)
		material.set_shader_parameter("source_leaf_tint_mix", _source_leaf_mix)

func _prepare_source_leaf_tint(root: String, asset_sha: String, asset: Node3D) -> void:
	if RenderingServer.get_current_rendering_method() != "mobile" or RenderingServer.get_rendering_device() == null:
		return
	var proof_path := root.path_join(LEAF_PROOF)
	var constants_path := root.path_join(LEAF_DRAW_CONSTANTS)
	if not FileAccess.file_exists(proof_path) or FileAccess.get_sha256(proof_path) != LEAF_PROOF_SHA:
		return
	if not FileAccess.file_exists(constants_path) or FileAccess.get_sha256(constants_path) != LEAF_DRAW_SHA:
		return
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(proof_path))
	if proof.asset_sha256 != asset_sha:
		return
	var meshes := asset.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		return
	var mesh: Mesh = meshes[0].mesh
	if mesh == null or mesh.get_surface_count() != 1:
		return
	var arrays := mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_VERTEX].size() != 1552 or arrays[Mesh.ARRAY_INDEX].size() != 2328:
		return
	var hashes := HashingContext.new()
	for channel: Array in [[Mesh.ARRAY_VERTEX, "positions"], [Mesh.ARRAY_TEX_UV, "uv"], [Mesh.ARRAY_INDEX, "indices"]]:
		hashes.start(HashingContext.HASH_SHA256)
		hashes.update(arrays[channel[0]].to_byte_array())
		if hashes.finish().hex_encode() != proof.imported_hashes[channel[1]]:
			return
	var weight_path := proof_path.get_base_dir().path_join("oak_var2_color.private.rgba8")
	if not FileAccess.file_exists(weight_path) or FileAccess.get_sha256(weight_path) != proof.colors_sha256:
		return
	var bytes := FileAccess.get_file_as_bytes(weight_path)
	if bytes.size() != 1552 * 4:
		return
	_source_leaf_mesh = mesh
	_source_leaf_weights = ImageTexture.create_from_image(Image.create_from_data(1552, 1, false, Image.FORMAT_RGBA8, bytes))
	# Draw 879's material register 1.x supplies the leaf hue angle.
	_source_leaf_hue = FileAccess.get_file_as_bytes(constants_path).decode_float(16)

func set_source_leaf_tint(strength: float) -> void:
	if _source_leaf_weights == null or strength == _source_leaf_mix:
		return
	_source_leaf_mix = strength
	_canopy_appearance.set_shader_parameter("source_leaf_tint_mix", strength)

func _place_tree(level: Node3D, tree: Node3D, placement: Vector4) -> bool:
	var height: float = level.surface_height(placement.x, placement.y)
	if not is_finite(height):
		tree.free()
		return false
	tree.position = Vector3(placement.x, height, placement.y)
	tree.rotation.y = placement.w
	tree.scale = Vector3.ONE * placement.z
	add_child(tree)
	_prepare_meshes(tree)
	_add_trunk(tree, placement.z)
	return true

func build_understory(level: Node3D) -> void:
	var offset := Vector3(level.runtime.offset[0], level.runtime.offset[1], level.runtime.offset[2])
	var placed: Dictionary = {}
	for anchor: Vector2i in UNDERSTORY:
		var planting: Dictionary = {}
		for kind: String in UNDERSTORY[anchor]:
			var roots: Array[Vector3] = []
			for point: Vector2 in UNDERSTORY[anchor][kind]:
				var height: float = level.surface_height(point.x, point.y)
				if not is_finite(height) or not is_equal_approx(height, 3.0): continue
				var local := Vector3(point.x, height, point.y) - offset
				var cell := Vector3i(local.floor())
				if placed.has(cell) or level.geometry.cells.has(cell): continue
				var support: int = level.geometry.cells.get(cell + Vector3i.DOWN, -1)
				if support < 0 or level.runtime.palette[support].kind != "grass_block": continue
				placed[cell] = true
				roots.append(Vector3(point.x, height, point.y))
			planting[kind] = roots
		level.geometry.build_accent_planting(anchor, planting)

func _prepare_meshes(tree: Node3D) -> void:
	for visual: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
		var source := visual.get_active_material(0) as StandardMaterial3D
		var appearance := _canopy_appearance if source_oaks or str(visual.name).begins_with("Leaves") else _appearance
		if not source_oaks and source != null:
			appearance.set_shader_parameter("native_specular", source.metallic_specular)
		if appearance == _canopy_appearance:
			# The caster shares the exact deformation, but never the reveal hole.
			visual.extra_cull_margin = 0.20
		_split_shadow(visual, appearance, _canopy_shadow if appearance == _canopy_appearance else null)
		if source_oaks and _source_leaf_mesh != null and visual.mesh == _source_leaf_mesh:
			visual.set_instance_shader_parameter("source_leaf_mask", true)

func _split_shadow(visual: MeshInstance3D, appearance: ShaderMaterial, shadow: ShaderMaterial) -> MeshInstance3D:
	var caster := MeshInstance3D.new()
	caster.name = visual.name + "Shadow"
	caster.mesh = visual.mesh
	caster.transform = visual.transform
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	caster.material_override = shadow
	caster.extra_cull_margin = visual.extra_cull_margin
	visual.get_parent().add_child(caster)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.material_override = appearance
	return caster

func _add_trunk(tree: Node3D, tree_scale: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = (.48 if source_oaks else TRUNK_RADIUS) * tree_scale
	shape.height = TRUNK_HEIGHT * tree_scale
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	body.position.y = TRUNK_HEIGHT * 0.5
	body.collision_layer = 0
	body.collision_mask = 0
	body.add_child(collider)
	# Cancel the visual scale because the physics dimensions are in metres.
	body.scale = Vector3.ONE / tree_scale
	tree.add_child(body)
	_trunks.append(body)

func set_enabled(value: bool, player_position: Vector3, player_shape: CapsuleShape3D) -> bool:
	if value:
		for trunk: StaticBody3D in _trunks:
			var shape := trunk.get_child(0).shape as CylinderShape3D
			var offset := player_position - trunk.global_position
			var clearance := shape.radius + player_shape.radius + 0.03
			var intersects_height := offset.y < shape.height * 0.5 and offset.y + player_shape.height > -shape.height * 0.5
			if intersects_height and Vector2(offset.x, offset.z).length_squared() < clearance * clearance:
				return false
	visible = value
	for trunk: StaticBody3D in _trunks:
		trunk.collision_layer = 1 if value else 0
	return true

func set_lighting(bark: Shader, leaves: Shader, field: Texture2D, shape: Vector4, time: float) -> void:
	_direct_clouds = field != null
	_apply_lighting(_appearance, bark, field, shape, time)
	_apply_lighting(_canopy_appearance, leaves, field, shape, time)
	if spruce_available():
		_apply_lighting(_spruce_appearance, leaves, field, shape, time)
		_bind_spruce_atlas(_spruce_appearance)

func set_crown_detail(enabled: bool) -> void:
	_canopy_appearance.set_shader_parameter("crown_detail", enabled)

func publish_crown_wind(enabled: bool, wind_phase: float, breeze_phase: float, travelling: bool) -> void:
	for material: ShaderMaterial in [_canopy_appearance, _canopy_shadow]:
		material.set_shader_parameter("crown_wind_enabled", enabled)
		material.set_shader_parameter("wind_phase", wind_phase)
		material.set_shader_parameter("breeze_phase", breeze_phase)
		material.set_shader_parameter("travelling_breeze", travelling)

func _apply_lighting(material: ShaderMaterial, shader: Shader, field: Texture2D, shape: Vector4, time: float) -> void:
	if material.shader.get_meta("gaf_mist_base", material.shader) != shader:
		var parameters := ["reveal_player", "player_view", "native_specular"]
		var values := parameters.map(material.get_shader_parameter)
		material.shader = shader
		for i in parameters.size():
			if values[i] != null: material.set_shader_parameter(parameters[i], values[i])
		if source_oaks and material == _canopy_appearance:
			_bind_source_atlas(material)
	if field != null:
		material.set_shader_parameter("clouds_enabled", true)
		material.set_shader_parameter("cloud_field", field)
		material.set_shader_parameter("cloud_shape", shape)
		material.set_shader_parameter("cloud_time", time)

func mist_receivers(strength: float) -> Array[ShaderMaterial]:
	if strength <= 0.0:
		return []
	var receivers: Array[ShaderMaterial] = []
	if visible:
		receivers.append_array([_appearance, _canopy_appearance])
	if spruce_visible():
		receivers.append(_spruce_appearance)
	if _mist_strength != strength:
		_mist_strength = strength
		for material in [_appearance, _canopy_appearance, _spruce_appearance]:
			material.set_shader_parameter("grove_mist_strength", strength)
	return receivers

func publish_cloud_time(time: float) -> void:
	if not _direct_clouds: return
	_appearance.set_shader_parameter("cloud_time", time)
	_canopy_appearance.set_shader_parameter("cloud_time", time)
	if spruce_available(): _spruce_appearance.set_shader_parameter("cloud_time", time)

func publish_cloud_shape(shape: Vector4) -> void:
	if not _direct_clouds:
		return
	_appearance.set_shader_parameter("cloud_shape", shape)
	_canopy_appearance.set_shader_parameter("cloud_shape", shape)
	if spruce_available(): _spruce_appearance.set_shader_parameter("cloud_shape", shape)

func update_focus(camera: Camera3D, player_position: Vector3, gameplay: bool) -> void:
	_appearance.set_shader_parameter("reveal_player", gameplay)
	_canopy_appearance.set_shader_parameter("reveal_player", gameplay)
	if spruce_available(): _spruce_appearance.set_shader_parameter("reveal_player", gameplay)
	if gameplay:
		var focus := player_position + Vector3.UP * 0.9
		var view_position := camera.global_transform.affine_inverse() * focus
		_appearance.set_shader_parameter("player_view", view_position)
		_canopy_appearance.set_shader_parameter("player_view", view_position)
		if spruce_available(): _spruce_appearance.set_shader_parameter("player_view", view_position)
