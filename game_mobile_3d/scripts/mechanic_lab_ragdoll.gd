extends "res://scenes/dev/zombie_death_physics/ragdoll.gd"

const DEEP_CONTACT_LIFT_START := 0.10
const DEEP_CONTACT_LIFT_FULL := 0.112
const DEEP_CONTACT_SHARED_LIFT := 0.065

var _sample_bone_ids: Dictionary[String, int]
var _sample_body_offsets: Dictionary[String, Transform3D]
var _sampled_skeleton_transform: Transform3D
var _source_joint_biases: Dictionary[RID, float]
var wall_handoff_animation: AnimationPlayer
var wall_handoff_idle: StringName

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
	_sampled_skeleton_transform = skeleton.global_transform
	for name: String in _sample_bone_ids:
		current[name] = (_sampled_skeleton_transform * skeleton.get_bone_global_pose(_sample_bone_ids[name])
			* _sample_body_offsets[name])
	sample_count += 1

func prepare_handoff_samples(delta: float, verify_transform: bool) -> void:
	# A Lab fixture can reposition a zombie between its last living sample
	# and the hit. The clearance query and the physics rig need the same pose.
	if sample_count >= 2 and (not verify_transform \
			or _sampled_skeleton_transform.is_equal_approx(skeleton.global_transform)):
		return
	sample(delta)
	sample(delta)

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
	if wall_handoff_animation != null and _handoff_straddles_wall(space, collision_mask):
		return _blend_wall_handoff(space, collision_mask)
	return super._handoff_wall_clearance()

func _blend_wall_handoff(space: PhysicsDirectSpaceState3D, collision_mask: int) -> Vector3:
	var source: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		source.append(skeleton.get_bone_pose(bone))
	wall_handoff_animation.stop()
	skeleton.reset_bone_poses()
	wall_handoff_animation.play(wall_handoff_idle)
	wall_handoff_animation.advance(0.0)
	wall_handoff_animation.pause()
	var idle: Array[Transform3D] = []
	for bone in source.size():
		idle.append(skeleton.get_bone_pose(bone))
	# Search from the least visible correction. Interpolating bone-local
	# transforms retains the source hierarchy while retracting the limbs.
	for idle_weight: float in [0.25, 0.50, 0.75, 1.0]:
		for bone in source.size():
			skeleton.set_bone_pose(bone, source[bone].interpolate_with(idle[bone], idle_weight))
		sample(sample_delta)
		var shift := super._handoff_wall_clearance()
		if idle_weight == 1.0 or _wall_handoff_is_clear(space, collision_mask, shift):
			return _preserve_wall_handoff_branches(space, collision_mask, source, shift)
	return Vector3.ZERO

func _preserve_wall_handoff_branches(space: PhysicsDirectSpaceState3D, collision_mask: int,
		source: Array[Transform3D], shift: Vector3) -> Vector3:
	# Keep source rotation on branches that can move without reopening the overlap.
	for name in ["Head", "Arm.L", "Arm.R", "Leg.L", "Leg.R"]:
		var bone: int = _sample_bone_ids[name]
		var safe_pose := skeleton.get_bone_pose(bone)
		for weight: float in [1.0, 0.5, 0.25]:
			var rotation := safe_pose.basis.get_rotation_quaternion().slerp(
				source[bone].basis.get_rotation_quaternion(), weight)
			var basis := Basis(rotation) * Basis.from_scale(safe_pose.basis.get_scale())
			skeleton.set_bone_pose(bone, Transform3D(basis, safe_pose.origin))
			sample(sample_delta)
			if _wall_handoff_is_clear(space, collision_mask, shift, name):
				safe_pose = skeleton.get_bone_pose(bone)
				break
		skeleton.set_bone_pose(bone, safe_pose)
	# Both snapshots must agree so the correction itself doesn't become a launch impulse.
	sample(sample_delta)
	sample(sample_delta)
	return shift

func _wall_handoff_is_clear(space: PhysicsDirectSpaceState3D, collision_mask: int,
		shift: Vector3, changed_part := "") -> bool:
	if _handoff_straddles_wall(space, collision_mask, shift, 0.0):
		return false
	for name: String in current:
		if not changed_part.is_empty() and name != changed_part:
			continue
		var pose: Transform3D = current[name]
		var points := _terrain_contacts_at(bodies[name], space, pose.translated(shift))
		for i in range(0, points.size(), 2):
			var separation := points[i + 1] - points[i]
			var depth := separation.length()
			if depth > HANDOFF_WALL_REST_OVERLAP and absf(separation.y) < depth * 0.7:
				return false
	return true

func _handoff_straddles_wall(space: PhysicsDirectSpaceState3D, collision_mask: int,
		shift := Vector3.ZERO, tolerance := SOURCE_ANCHOR_TOLERANCE) -> bool:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = collision_mask
	var origin := skeleton.global_position + shift
	for pose: Transform3D in current.values():
		ray.from = Vector3(origin.x, pose.origin.y, origin.z)
		ray.to = pose.origin + shift
		if ray.from.distance_squared_to(ray.to) <= SOURCE_ANCHOR_TOLERANCE * SOURCE_ANCHOR_TOLERANCE:
			continue
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not hit.collider is StaticBody3D:
			continue
		var normal: Vector3 = hit.normal
		var point: Vector3 = hit.position
		if absf(normal.y) < MAX_WALL_NORMAL_Y and normal.dot(point - ray.to) > tolerance:
			return true
	return false

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

func has_flat_wall_rest_support(core_grounded: bool) -> bool:
	if not core_grounded:
		if _flat_floor.disabled:
			return false
		var floor_body := _flat_floor.get_parent()
		if not _body_supported_by(bodies["Leg.L"], floor_body) \
				or not _body_supported_by(bodies["Leg.R"], floor_body):
			return false
	for part in ["Head", "Chest"]:
		var body: PhysicalBone3D = bodies[part]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		for contact in state.get_contact_count():
			if absf(state.get_contact_local_normal(contact).y) < MAX_WALL_NORMAL_Y \
					and state.get_contact_collider_object(contact) is StaticBody3D:
				return true
	return false

func _limit_shared_first_contact_lift(lifts: Dictionary[PhysicalBone3D, float],
		depths: Dictionary[PhysicalBone3D, float], shared_lift: float, slop: float) -> void:
	if shared_lift <= DEEP_CONTACT_LIFT_START:
		return
	# All five MD2 zombie joints share one spine body. Solve its minimum
	# lift first, then raise only the limbs that need floor or joint clearance.
	var chest: PhysicalBone3D = bodies.Chest
	var chest_state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if chest_state == null:
		return
	var weight := smoothstep(DEEP_CONTACT_LIFT_START, DEEP_CONTACT_LIFT_FULL, shared_lift)
	var reduced_lift := lerpf(shared_lift, DEEP_CONTACT_SHARED_LIFT, weight)
	var chest_lift := maxf(reduced_lift, depths.get(chest, 0.0) - slop)
	var old_chest_lift: float = lifts.get(chest, maxf(shared_lift, depths.get(chest, 0.0) - slop))
	var limb_clearances: Dictionary[PhysicalBone3D, float] = {}
	var limb_gap_limits: Dictionary[PhysicalBone3D, Vector2] = {}
	for name: String in source_joint_rids:
		var joint: Dictionary = source_joints[name]
		if joint.parent != "Chest":
			return
		var limb: PhysicalBone3D = bodies[name]
		var limb_state := PhysicsServer3D.body_get_direct_state(limb.get_rid())
		if limb_state == null:
			return
		var chest_anchor: Vector3 = (chest_state.transform * joint.parent_frame).origin
		var limb_anchor: Vector3 = (limb_state.transform * joint.child_frame).origin
		var gap := chest_anchor - limb_anchor
		var old_limb_lift: float = lifts.get(limb, maxf(shared_lift, depths.get(limb, 0.0) - slop))
		var tolerance := maxf(FIRST_CONTACT_ANCHOR_LIMIT,
			(gap + Vector3.UP * (old_chest_lift - old_limb_lift)).length())
		var vertical_limit := sqrt(maxf(tolerance * tolerance - gap.x * gap.x - gap.z * gap.z, 0.0))
		var limb_clearance := maxf(reduced_lift, depths.get(limb, 0.0) - slop)
		chest_lift = maxf(chest_lift, limb_clearance - gap.y - vertical_limit)
		limb_clearances[limb] = limb_clearance
		limb_gap_limits[limb] = Vector2(gap.y, vertical_limit)
	for limb: PhysicalBone3D in limb_clearances:
		var limit := limb_gap_limits[limb]
		lifts[limb] = maxf(limb_clearances[limb], chest_lift + limit.x - limit.y)
	lifts[chest] = chest_lift

func _constrain_free_anchor_motion(body: PhysicalBone3D, state: PhysicsDirectBodyState3D,
		motion: Vector3) -> Vector3:
	if (motion.y >= 0.0 or not _limit_first_contact_stretch or not floor_landing_blended
			or not is_instance_valid(_flat_floor) or _flat_floor.disabled):
		return motion
	var floor_box := _flat_floor.shape as BoxShape3D
	var floor_pose := _flat_floor.global_transform
	if (floor_box == null or not floor_pose.basis.y.is_equal_approx(Vector3.UP)
			or not floor_pose.basis.get_scale().is_equal_approx(Vector3.ONE)):
		return motion
	var collider := body.get_child(0) as CollisionShape3D
	var shape := collider.shape as BoxShape3D
	var floor_inverse := floor_pose.affine_inverse()
	var pose := floor_inverse * state.transform * collider.transform
	var bounds := pose * AABB(-shape.size * 0.5, shape.size)
	var floor_half := floor_box.size * 0.5
	var local_motion := floor_inverse.basis * motion
	var target := bounds.position + local_motion
	if (target.x < -floor_half.x or target.x + bounds.size.x > floor_half.x
			or target.z < -floor_half.z or target.z + bounds.size.z > floor_half.z):
		return motion
	# Keep the preceding floor recovery when the free limb is already at
	# the resting clearance. The wall sweep still handles the lateral move.
	var clearance := bounds.position.y - floor_half.y + FLOOR_REST_SLOP
	motion.y = maxf(motion.y, -maxf(clearance, 0.0))
	return motion

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
