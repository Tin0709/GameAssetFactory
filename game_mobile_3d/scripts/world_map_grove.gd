extends Node3D
## An optional grove using the two original Forest Canopy V3 trees.
const OAKS := [
	"res://assets/environment/forest_canopy_v3/tree_oak_a.glb",
	"res://assets/environment/forest_canopy_v3/tree_oak_b.glb",
]
const PLACEMENTS := [
	Vector4(-33.4, 5.7, 0.88, 0.6),
	Vector4(-29.0, 1.3, 0.78, 1.25),
	Vector4(-25.0, 3.7, 0.91, 2.0),
	Vector4(-17.8, 11.5, 0.82, 0.1),
]
const REVIEW_POSITION := Vector2(-27.5, 8.0)
const REVEAL_SHADER := preload("res://materials/world_map_grove.gdshader")
const TRUNK_RADIUS := 0.27
const TRUNK_HEIGHT := 2.6

var _appearance := ShaderMaterial.new()
var _canopy_appearance := ShaderMaterial.new()
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
