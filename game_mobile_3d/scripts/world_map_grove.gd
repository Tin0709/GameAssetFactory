extends Node3D
## Reversible woodland planting using the two original Forest Canopy V3 trees.
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
var _direct_clouds := false
var _trunks: Array[StaticBody3D] = []

func build(level: Node3D) -> bool:
	hide()
	_appearance.shader = REVEAL_SHADER
	_canopy_appearance.shader = REVEAL_SHADER
	var assets: Array[PackedScene] = []
	for path: String in OAKS:
		var asset := load(path) as PackedScene
		if asset == null: return false
		assets.append(asset)
	for index in PLACEMENTS.size():
		var placement: Vector4 = PLACEMENTS[index]
		var height: float = level.surface_height(placement.x, placement.y)
		if not is_finite(height): return false
		var tree := assets[index % assets.size()].instantiate() as Node3D
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
		var appearance := _canopy_appearance if str(visual.name).begins_with("Leaves") else _appearance
		appearance.set_shader_parameter("native_specular", source.metallic_specular)
		# The shadow-only instance uses the original mesh and its imported shadow mesh.
		var caster := MeshInstance3D.new()
		caster.name = visual.name + "Shadow"
		caster.mesh = visual.mesh
		caster.transform = visual.transform
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		visual.get_parent().add_child(caster)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.material_override = appearance

func _add_trunk(tree: Node3D, tree_scale: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = TRUNK_RADIUS * tree_scale
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

func _apply_lighting(material: ShaderMaterial, shader: Shader, field: Texture2D, shape: Vector4, time: float) -> void:
	if material.shader != shader:
		var parameters := ["reveal_player", "player_view", "native_specular"]
		var values := parameters.map(material.get_shader_parameter)
		material.shader = shader
		for i in parameters.size():
			if values[i] != null: material.set_shader_parameter(parameters[i], values[i])
	if field != null:
		material.set_shader_parameter("clouds_enabled", true)
		material.set_shader_parameter("cloud_field", field)
		material.set_shader_parameter("cloud_shape", shape)
		material.set_shader_parameter("cloud_time", time)

func publish_cloud_time(time: float) -> void:
	if not _direct_clouds: return
	_appearance.set_shader_parameter("cloud_time", time)
	_canopy_appearance.set_shader_parameter("cloud_time", time)

func update_focus(camera: Camera3D, player_position: Vector3, gameplay: bool) -> void:
	_appearance.set_shader_parameter("reveal_player", gameplay)
	_canopy_appearance.set_shader_parameter("reveal_player", gameplay)
	if gameplay:
		var focus := player_position + Vector3.UP * 0.9
		var view_position := camera.global_transform.affine_inverse() * focus
		_appearance.set_shader_parameter("player_view", view_position)
		_canopy_appearance.set_shader_parameter("player_view", view_position)
