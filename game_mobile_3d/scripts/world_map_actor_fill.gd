extends Node
## Original static crown visibility for this map's existing opaque player materials.
const PROBES := [
	preload("res://assets/graphics/world_map_actor_sky_v001/oak_sky_a.res"),
	preload("res://assets/graphics/world_map_actor_sky_v001/oak_sky_b.res"),
]
const MAX_CROWNS := 10
var level: Node3D
var enabled := true
var _trees: Array[Array] = []
var _coefficients := PackedVector4Array()
var _last_position := Vector3(INF, INF, INF)
var _last_visible := false

func setup(world: Node3D) -> void:
	level = world
	_coefficients.resize(MAX_CROWNS * 6)
	if is_instance_valid(level.grove) and not level.grove.source_oaks:
		for tree: Node3D in level.grove.get_children():
			var rotation := tree.global_basis.orthonormalized()
			_trees.append([tree.global_transform.affine_inverse(), rotation, PROBES[_trees.size() % 2]])
	set_enabled(true)

func available() -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null \
		and is_instance_valid(level) and is_instance_valid(level.grove) and not _trees.is_empty() and _trees.size() <= MAX_CROWNS

func is_active() -> bool:
	return enabled and available() and level.look.stage == 2

func set_enabled(value: bool) -> void:
	enabled = value
	level.look.set_actor_sky_fill(enabled and available())
	_last_position = Vector3(INF, INF, INF)
	refresh()

func current_coefficients() -> PackedVector4Array:
	return _coefficients.duplicate()

func _rotate(values: PackedVector4Array, rotation: Basis) -> PackedVector4Array:
	var c := values[0]
	var q := values[1]
	var r := values[2]
	var linear := rotation * Vector3(c.y, c.z, c.w)
	var quadratic := Basis(Vector3(q.x, q.w, r.x), Vector3(q.w, q.y, r.y), Vector3(r.x, r.y, q.z))
	quadratic = rotation * quadratic * rotation.transposed()
	return PackedVector4Array([
		Vector4(c.x, linear.x, linear.y, linear.z),
		Vector4(quadratic.x.x, quadratic.y.y, quadratic.z.z, quadratic.x.y),
		Vector4(quadratic.x.z, quadratic.y.z, 0, 0),
	])

func refresh() -> void:
	if not is_active(): return
	var position: Vector3 = level.presentation.player_position()
	var visible: bool = level.grove.visible
	if position != _last_position or visible != _last_visible:
		_last_position = position
		_last_visible = visible
		_coefficients.fill(Vector4.ZERO)
		if visible:
			for index in _trees.size():
				var tree: Array = _trees[index]
				var inverse: Transform3D = tree[0]
				var local := inverse * position
				if maxf(absf(local.x), absf(local.z)) >= 6.0: continue
				var pair := PackedVector4Array()
				for height: float in [0.15, 1.8]:
					var probe: Vector3 = inverse * (position + Vector3.UP * height)
					pair.append_array(_rotate(tree[2].sample(probe), tree[1]))
				for term in 6: _coefficients[index * 6 + term] = pair[term]
	# Material selection can change at F3/B while the actor remains stationary.
	for material: ShaderMaterial in level.look._direct_actor_materials:
		if material == null: continue
		material.set_shader_parameter("sky_block", _coefficients)
		material.set_shader_parameter("sky_heights", Vector2(position.y + 0.15, position.y + 1.8))

func _process(_delta: float) -> void:
	refresh()
