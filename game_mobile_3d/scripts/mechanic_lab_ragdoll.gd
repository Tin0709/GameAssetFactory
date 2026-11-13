extends "res://scenes/dev/zombie_death_physics/ragdoll.gd"

var _sample_bone_ids: Dictionary[String, int]
var _sample_body_offsets: Dictionary[String, Transform3D]
var _source_joint_biases: Dictionary[RID, float]

static var _handoff_bounds_shape: BoxShape3D
static var _handoff_bounds_query: PhysicsShapeQueryParameters3D
static var _body_shapes: Dictionary[Vector3, BoxShape3D]

func _make_body_shape(size: Vector3) -> BoxShape3D:
	if not _body_shapes.has(size):
		_body_shapes[size] = super._make_body_shape(size)
	return _body_shapes[size]

func setup(target: Skeleton3D, part_layout: Array = PARTS, bone_names: Dictionary = {},
		body_offsets: Dictionary = {}, authored_joints: Dictionary = {}) -> void:
	super.setup(target, part_layout, bone_names, body_offsets, authored_joints)
	_sample_bone_ids.clear()
	_sample_body_offsets.clear()
	for name: String in bodies:
		var body: PhysicalBone3D = bodies[name]
		_sample_bone_ids[name] = body.get_bone_id()
		_sample_body_offsets[name] = body.body_offset

func sample(delta: float) -> void:
	# Both dictionaries keep the same body keys, so the older buffer can be overwritten.
	var next := previous
	previous = current
	current = next
	sample_delta = delta
	var skeleton_transform := skeleton.global_transform
	for name: String in _sample_bone_ids:
		current[name] = (skeleton_transform * skeleton.get_bone_global_pose(_sample_bone_ids[name])
			* _sample_body_offsets[name])
	sample_count += 1

func _handoff_wall_clearance() -> Vector3:
	if not is_instance_valid(_flat_floor):
		return super._handoff_wall_clearance()

	# Only skip the detailed queries when the entire captured rig clears terrain.
	var bounds: AABB
	var collision_mask := 0
	var first := true
	for name: String in current:
		var body: PhysicalBone3D = bodies[name]
		var collider := body.get_child(0) as CollisionShape3D
		var shape := collider.shape as BoxShape3D
		var pose: Transform3D = current[name] * collider.transform
		var box := pose * AABB(-shape.size * 0.5, shape.size)
		bounds = box if first else bounds.merge(box)
		collision_mask |= body.collision_mask
		first = false
	if _handoff_bounds_query == null:
		_handoff_bounds_shape = BoxShape3D.new()
		_handoff_bounds_query = PhysicsShapeQueryParameters3D.new()
		_handoff_bounds_query.shape = _handoff_bounds_shape
	bounds = bounds.grow(PROJECTION_COLLISION_MARGIN)
	_handoff_bounds_shape.size = bounds.size
	_handoff_bounds_query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
	_handoff_bounds_query.collision_mask = collision_mask
	var space := skeleton.get_world_3d().direct_space_state
	if space.intersect_shape(_handoff_bounds_query, 1).is_empty():
		return Vector3.ZERO
	return super._handoff_wall_clearance()

func is_near_flat_floor(tolerance: float) -> bool:
	var floor_box := _flat_floor.shape as BoxShape3D
	var floor_pose := _flat_floor.global_transform
	if floor_box == null or not floor_pose.basis.y.is_equal_approx(Vector3.UP) \
			or not floor_pose.basis.get_scale().is_equal_approx(Vector3.ONE):
		return false
	var floor_half := floor_box.size * 0.5
	var floor_inverse := floor_pose.affine_inverse()
	var minimum_y := INF
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		var size: Vector3 = part[2]
		var bounds := (floor_inverse * body.global_transform) * AABB(-size * 0.5, size)
		# Ignore limbs that have already cleared the finite floor footprint.
		if bounds.position.x > floor_half.x or bounds.end.x < -floor_half.x \
				or bounds.position.z > floor_half.z or bounds.end.z < -floor_half.z:
			continue
		minimum_y = minf(minimum_y, bounds.position.y)
	return absf(minimum_y - floor_half.y) <= tolerance

func _set_source_joint_bias(joint: RID, bias: float) -> void:
	if _source_joint_biases.get(joint, -1.0) == bias:
		return
	super._set_source_joint_bias(joint, bias)
	_source_joint_biases[joint] = bias

func release(visible_world_pose: Array[Transform3D] = []) -> void:
	super.release(visible_world_pose)
	_source_joint_biases.clear()
	_sample_bone_ids.clear()
	_sample_body_offsets.clear()
