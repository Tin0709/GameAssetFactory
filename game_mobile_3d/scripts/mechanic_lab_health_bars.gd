extends MultiMeshInstance3D

const HEALTH_SHADER := preload("res://materials/mechanic_lab_zombie_health.gdshader")
const BAR_HEIGHT := 2.16
const INITIAL_CAPACITY := 128

var _owners: Array[Node3D] = []
var _positions := PackedVector3Array()
var _fills := PackedColorArray()

static func make_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.86, 0.165)
	return quad

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = HEALTH_SHADER
	material.set_shader_parameter("use_batched_health", true)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.mesh = make_quad()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = INITIAL_CAPACITY
	multimesh.visible_instance_count = 0
	set_process(false)

func add_bar(owner_node: Node3D) -> int:
	var slot := _owners.size()
	if slot == multimesh.instance_count:
		multimesh.instance_count *= 2
		for i in slot:
			_write_bar(i)
	_owners.append(owner_node)
	_positions.append(_bar_position(owner_node))
	_fills.append(Color(1.0, 1.0, 0.0, 1.0))
	_write_bar(slot)
	multimesh.visible_instance_count = _owners.size()
	set_process(true)
	return slot

func remove_bar(slot: int) -> void:
	var last := _owners.size() - 1
	if slot != last:
		var moved := _owners[last]
		_owners[slot] = moved
		_positions[slot] = _positions[last]
		_fills[slot] = _fills[last]
		moved.set("bar_slot", slot)
		_write_bar(slot)
	_owners.pop_back()
	_positions.resize(last)
	_fills.resize(last)
	multimesh.visible_instance_count = last
	set_process(last > 0)

func set_bar_health(slot: int, health: float, delayed: float) -> void:
	var fill := Color(health, delayed, 0.0, 1.0)
	_fills[slot] = fill
	multimesh.set_instance_custom_data(slot, fill)

func _process(_delta: float) -> void:
	for slot in _owners.size():
		var point := _bar_position(_owners[slot])
		if point != _positions[slot]:
			_positions[slot] = point
			multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, point))

func _bar_position(owner_node: Node3D) -> Vector3:
	return to_local(owner_node.to_global(Vector3.UP * BAR_HEIGHT))

func _write_bar(slot: int) -> void:
	multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, _positions[slot]))
	multimesh.set_instance_custom_data(slot, _fills[slot])
