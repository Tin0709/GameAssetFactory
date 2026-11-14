extends "res://scenes/dev/zombie_death_physics/ragdoll.gd"

const DEEP_CONTACT_LIFT_START := 0.10
const DEEP_CONTACT_LIFT_FULL := 0.112
const DEEP_CONTACT_SHARED_LIFT := 0.065
const EARLY_FLOOR_LIFT_START := 0.065
const EARLY_FLOOR_LIFT_FULL := 0.095
const EARLY_FLOOR_SHARED_LIFT := 0.045
const EARLY_FLOOR_LIFT_BLEND_END := 0.16
const WALL_HANDOFF_RECOVERY_SECONDS := 0.12
const WALL_CHEST_MAX_SHIFT := 0.03
const WALL_ARM_REBOUND_MAX_SHIFT := 0.045
const WALL_ARM_HANDOFF_MAX_SHIFT := 0.06
const WALL_ARM_HANDOFF_MIN_GAP := 3.5 * SOURCE_ANCHOR_TOLERANCE
const WALL_NECK_BRACE_MIN_GAP := 2.5 * SOURCE_ANCHOR_TOLERANCE
const WALL_NECK_LANDING_BLEND_END := 0.5
const WALL_SHOULDER_SLIDE_WINDOW := 5.0 / 60.0
const WALL_SHOULDER_SLIDE_MIN_GAP := 4.0 * SOURCE_ANCHOR_TOLERANCE
const FIRST_WALL_SHOULDER_SLIDE_MIN_GAP := 0.17
const WALL_SHOULDER_SLIDE_MAX := 0.08
const REBOUND_SHOULDER_SLIDE_MAX_NORMAL_FRACTION := 0.65
const FIRST_FLOOR_CHEST_MAX_SHIFT := 0.03
const EARLY_ARM_SLIDE_RESIDUAL := 0.125
const EARLY_ARM_SLIDE_EXTRA := 0.02

var _sample_names: Array[String]
var _sample_bone_ids: Array[int]
var _sample_body_offsets: Array[Transform3D]
var _sampled_skeleton_transform: Transform3D
var _source_joint_biases: Dictionary[RID, float]
var _wall_handoff_frame := -1
var _launch_frame := -1
var wall_handoff_animation: AnimationPlayer
var wall_handoff_idle: StringName

static var _handoff_bounds_shape: BoxShape3D
static var _handoff_bounds_query: PhysicsShapeQueryParameters3D
static var _body_shapes: Dictionary[Vector3, BoxShape3D]

func _make_body_shape(size: Vector3) -> BoxShape3D:
	if not _body_shapes.has(size):
		_body_shapes[size] = super._make_body_shape(size)
	return _body_shapes[size]

func begin(profile: Resource, direction: Vector3, location: String, distance: float, gravity: float,
		flat_floor: CollisionShape3D = null, floor_impact_limb_share := 0.0, limit_first_contact_stretch := false,
		linear_override := INF, upward_override := INF) -> bool:
	if not super.begin(profile, direction, location, distance, gravity,
			flat_floor, floor_impact_limb_share, limit_first_contact_stretch, linear_override, upward_override):
		return false
	_launch_frame = Engine.get_physics_frames()
	return true

func setup(target: Skeleton3D, part_layout: Array = PARTS, bone_names: Dictionary = {},
		body_offsets: Dictionary = {}, authored_joints: Dictionary = {}) -> void:
	super.setup(target, part_layout, bone_names, body_offsets, authored_joints)
	_sample_names.clear()
	_sample_bone_ids.clear()
	_sample_body_offsets.clear()
	for name: String in bodies:
		var body: PhysicalBone3D = bodies[name]
		_sample_names.append(name)
		_sample_bone_ids.append(body.get_bone_id())
		_sample_body_offsets.append(body.body_offset)

func sample(delta: float) -> void:
	# Both dictionaries keep the same body keys, so the older buffer can be overwritten.
	var next := previous
	previous = current
	current = next
	sample_delta = delta
	_sampled_skeleton_transform = skeleton.global_transform
	for i in _sample_names.size():
		current[_sample_names[i]] = (_sampled_skeleton_transform * skeleton.get_bone_global_pose(_sample_bone_ids[i])
			* _sample_body_offsets[i])
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
	var overlaps := space.intersect_shape(_handoff_bounds_query, 2)
	if overlaps.is_empty():
		return Vector3.ZERO
	if overlaps.size() == 1 and _is_floor_top_overlap(overlaps[0].rid, bounds):
		return Vector3.ZERO
	if wall_handoff_animation != null and _handoff_straddles_wall(space, collision_mask):
		_wall_handoff_frame = Engine.get_physics_frames()
		return _blend_wall_handoff(space, collision_mask)
	return super._handoff_wall_clearance()

func _is_floor_top_overlap(hit: RID, bounds: AABB) -> bool:
	var floor_body := _flat_floor.get_parent() as StaticBody3D
	var floor_shape := _flat_floor.shape as BoxShape3D
	if floor_body == null or floor_shape == null or _flat_floor.disabled or hit != floor_body.get_rid() \
			or PhysicsServer3D.body_get_shape_count(hit) != 1:
		return false
	var pose := _flat_floor.global_transform
	if pose.basis != Basis.IDENTITY:
		return false
	var half := floor_shape.size * 0.5
	var low := pose.origin - half
	var high := pose.origin + half
	# Only skip a shallow top overlap with enough room that a box cannot
	# contact a side. Floor penetration is still resolved by the solver.
	var depth := high.y - bounds.position.y
	if depth < 0.0 or depth > floor_shape.size.y * 0.5 or bounds.end.y <= high.y:
		return false
	return bounds.position.x > low.x + depth and bounds.end.x < high.x - depth \
		and bounds.position.z > low.z + depth and bounds.end.z < high.z - depth

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
		var bone: int = bodies[name].get_bone_id()
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
	var inner_minimum_y := INF
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		var size: Vector3 = part[2]
		var bounds := (floor_inverse * body.global_transform) * AABB(-size * 0.5, size)
		if bounds.position.x > floor_half.x or bounds.end.x < -floor_half.x \
				or bounds.position.z > floor_half.z or bounds.end.z < -floor_half.z:
			continue
		minimum_y = minf(minimum_y, bounds.position.y)
		if bounds.position.x >= -floor_half.x and bounds.end.x <= floor_half.x \
				and bounds.position.z >= -floor_half.z and bounds.end.z <= floor_half.z:
			inner_minimum_y = minf(inner_minimum_y, bounds.position.y)
	# A corner below the lip can hide another part resting wholly on the floor.
	return absf(minimum_y - floor_half.y) <= tolerance or absf(inner_minimum_y - floor_half.y) <= tolerance

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

func has_wall_rest_with_near_foot() -> bool:
	if _flat_floor.disabled or not has_flat_wall_rest_support(true):
		return false
	var floor_body := _flat_floor.get_parent()
	var left: PhysicalBone3D = bodies["Leg.L"]
	var right: PhysicalBone3D = bodies["Leg.R"]
	var left_supported := _body_supported_by(left, floor_body)
	var right_supported := _body_supported_by(right, floor_body)
	if left_supported == right_supported:
		return false
	var floor_box := _flat_floor.shape as BoxShape3D
	var floor_pose := _flat_floor.global_transform
	if floor_box == null or not floor_pose.basis.y.is_equal_approx(Vector3.UP) \
			or not floor_pose.basis.get_scale().is_equal_approx(Vector3.ONE):
		return false
	var foot := right if left_supported else left
	var collider := foot.get_child(0) as CollisionShape3D
	var size := (collider.shape as BoxShape3D).size
	var box := (floor_pose.affine_inverse() * collider.global_transform) * AABB(-size * 0.5, size)
	var half := floor_box.size * 0.5
	return box.position.x >= -half.x and box.end.x <= half.x \
		and box.position.z >= -half.z and box.end.z <= half.z \
		and absf(box.position.y - half.y) <= FLOOR_CONTACT_SLOP

func has_flat_corner_brace() -> bool:
	var floor_body := _flat_floor.get_parent()
	if not _body_supported_by(bodies["Leg.L"], floor_body) and not _body_supported_by(bodies["Leg.R"], floor_body):
		return false
	var normal := Vector3.ZERO
	var wall := RID()
	for name in ["Head", "Chest"]:
		var body: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		for i in state.get_contact_count():
			var next := state.get_contact_local_normal(i)
			if absf(next.y) >= MAX_WALL_NORMAL_Y or not state.get_contact_collider_object(i) is StaticBody3D:
				continue
			var collider := state.get_contact_collider(i)
			if not wall.is_valid():
				wall = collider
				normal = next
			elif collider != wall and absf(normal.dot(next)) < 0.25:
				return true
	return false

func _limit_shared_first_contact_lift(lifts: Dictionary[PhysicalBone3D, float],
		depths: Dictionary[PhysicalBone3D, float], shared_lift: float, slop: float) -> void:
	if shared_lift <= DEEP_CONTACT_LIFT_START:
		return
	var weight := smoothstep(DEEP_CONTACT_LIFT_START, DEEP_CONTACT_LIFT_FULL, shared_lift)
	var reduced_lift := lerpf(shared_lift, DEEP_CONTACT_SHARED_LIFT, weight)
	_distribute_floor_lift(lifts, depths, shared_lift, slop, reduced_lift, FIRST_CONTACT_ANCHOR_LIMIT)

func _limit_floor_anchor_stretch(lifts: Dictionary[PhysicalBone3D, float], depths: Dictionary[PhysicalBone3D, float],
		shared_lift: float, slop: float, anchor_limit: float) -> void:
	super._limit_floor_anchor_stretch(lifts, depths, shared_lift, slop, anchor_limit)
	if floor_landing_blended or floor_impact_blend <= 0.0 or floor_impact_blend >= EARLY_FLOOR_LIFT_BLEND_END \
			or shared_lift <= EARLY_FLOOR_LIFT_START:
		return
	# Keep the correction local while the first roll still has floor support.
	# An airborne frame between contacts can need the existing shared lift.
	var floor_body := _flat_floor.get_parent()
	for body: PhysicalBone3D in bodies.values():
		if _body_supported_by(body, floor_body):
			var weight := smoothstep(EARLY_FLOOR_LIFT_START, EARLY_FLOOR_LIFT_FULL, shared_lift)
			weight *= 1.0 - smoothstep(EARLY_FLOOR_LIFT_BLEND_END * 0.5, EARLY_FLOOR_LIFT_BLEND_END, floor_impact_blend)
			var reduced_lift := lerpf(shared_lift, EARLY_FLOOR_SHARED_LIFT, weight)
			_distribute_floor_lift(lifts, depths, shared_lift, slop, reduced_lift, anchor_limit)
			return

func _distribute_floor_lift(lifts: Dictionary[PhysicalBone3D, float], depths: Dictionary[PhysicalBone3D, float],
		shared_lift: float, slop: float, reduced_lift: float, anchor_limit: float) -> void:
	# All five MD2 zombie joints share one spine body. Solve its minimum
	# lift first, then raise only the limbs that need floor or joint clearance.
	var chest: PhysicalBone3D = bodies.Chest
	var chest_state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if chest_state == null:
		return
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
		var tolerance := maxf(anchor_limit,
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
	if (motion.y >= 0.0 or not floor_landing_blended
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
	# Keep the preceding floor recovery when the joint would move a limb
	# below the resting clearance. Keep the tighter Sabre roll behavior.
	var clearance := bounds.position.y - floor_half.y + FLOOR_REST_SLOP
	if _limit_first_contact_stretch or clearance + motion.y < -FLOOR_REST_SLOP:
		motion.y = maxf(motion.y, -maxf(clearance, 0.0))
	return motion

func _recover_early_floor_arm_gap() -> void:
	if not _limit_first_contact_stretch or floor_landing_blended or floor_impact_blend <= 0.0 \
			or floor_impact_blend >= EARLY_ROLL_ANCHOR_BLEND_END \
			or not is_instance_valid(_flat_floor) or _flat_floor.disabled:
		return
	var floor_body := _flat_floor.get_parent() as StaticBody3D
	var chest: PhysicalBone3D = bodies.Chest
	var chest_state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if floor_body == null or chest_state == null:
		return
	# During early support, continue the existing first-contact slide only
	# for a falling arm with a large gap mostly along the floor.
	for name in ["Arm.L", "Arm.R"]:
		var arm: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(arm.get_rid())
		if state == null or state.linear_velocity.y > 0.0:
			continue
		var spec: Dictionary = source_joints[name]
		var gap: Vector3 = (chest_state.transform * spec.parent_frame).origin \
			- (state.transform * spec.child_frame).origin
		var along_floor := gap.slide(Vector3.UP)
		var tangent := along_floor.length()
		if tangent > 2.0 * SOURCE_ANCHOR_TOLERANCE and absf(gap.y) <= tangent * 0.75 \
				and _body_supported_by(arm, floor_body):
			# Only extend the slide when its normal limit leaves a large gap.
			var remaining_tangent := sqrt(maxf(EARLY_ARM_SLIDE_RESIDUAL ** 2 - gap.y * gap.y, 0.0))
			var slide_limit := FIRST_CONTACT_ANCHOR_MAX_SLIDE + EARLY_ARM_SLIDE_EXTRA
			var slide_distance := minf(slide_limit, tangent - remaining_tangent)
			if slide_distance > FIRST_CONTACT_ANCHOR_MAX_SLIDE:
				var motion := along_floor * (slide_distance / tangent)
				if not _test_projection_motion(arm, state.transform, motion, floor_body.get_rid()):
					state.transform = state.transform.translated(motion)
					continue
			_slide_supported_anchor(arm, state, gap, gap.length(), floor_body.get_rid())

func _project_source_anchors() -> void:
	var lab_floor := not floor_landing_blended and is_instance_valid(_flat_floor) and not _flat_floor.disabled
	var sabre_floor := _limit_first_contact_stretch and lab_floor
	var sabre_flight := sabre_floor and floor_impact_blend <= 0.0
	var first_wall_window := lab_floor and floor_impact_blend <= 0.0 and Engine.get_physics_frames() - _launch_frame \
		<= roundi(WALL_SHOULDER_SLIDE_WINDOW * Engine.physics_ticks_per_second)
	var early_wall_landing := sabre_floor and floor_impact_blend > 0.0 \
		and floor_impact_blend <= WALL_NECK_LANDING_BLEND_END
	if sabre_flight:
		_recover_leading_head_wall_overlap()
	super._project_source_anchors()
	if first_wall_window:
		_slide_wall_shoulder_anchors()
	_recover_early_floor_arm_gap()
	_recover_floor_blocked_hip()
	var recent_handoff := _wall_handoff_frame >= 0 and Engine.get_physics_frames() - _wall_handoff_frame \
		<= roundi(WALL_HANDOFF_RECOVERY_SECONDS * Engine.physics_ticks_per_second)
	if not recent_handoff and not sabre_flight and not early_wall_landing:
		return

	# All five source joints share the chest. A side contact can block a
	# limb's projection, so check whether the chest has room to meet it.
	var motion := Vector3.ZERO
	var neck_wall := RID()
	var handoff_arm: PhysicsDirectBodyState3D
	var largest_gap := 2.0 * SOURCE_ANCHOR_TOLERANCE
	var chest: PhysicalBone3D = bodies.Chest
	var chest_state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if chest_state == null:
		return
	if not recent_handoff:
		# The first contact can pin an arm before the solver turns it around.
		# Allow the ordinary positional shift on that tick with a free torso.
		var first_contact := Engine.get_physics_frames() == _launch_frame + 1 \
			and chest_state.get_contact_count() == 0
		for name in ["Head", "Arm.L", "Arm.R"]:
			var is_arm: bool = name != "Head"
			# A wall can still pin the descending head during the first part
			# of the floor roll. Only a free chest can follow it.
			if early_wall_landing and (is_arm or chest_state.get_contact_count() > 0):
				continue
			var limb: PhysicalBone3D = bodies[name]
			var state := PhysicsServer3D.body_get_direct_state(limb.get_rid())
			if state == null or state.get_contact_count() == 0:
				continue
			if early_wall_landing and state.linear_velocity.y >= 0.0:
				continue
			var spec: Dictionary = source_joints[name]
			var gap: Vector3 = (chest_state.transform * spec.parent_frame).origin \
				- (state.transform * spec.child_frame).origin
			var distance := gap.length()
			if distance <= largest_gap:
				continue
			var shift := _wall_anchor_motion(state, gap, not is_arm or not first_contact, is_arm)
			if early_wall_landing and not shift.is_zero_approx():
				var toward_anchor := gap * (1.0 - SOURCE_ANCHOR_TOLERANCE / distance)
				if not _test_projection_motion(limb, state.transform, toward_anchor) \
						or _projection_hit.get_collision_safe_fraction() > 0.0:
					continue
			var braced_neck := not is_arm and chest_state.get_contact_count() > 0
			var wall := RID()
			if braced_neck:
				if distance <= WALL_NECK_BRACE_MIN_GAP:
					continue
				wall = _shared_wall_contact(chest_state, state, shift)
				if not wall.is_valid():
					continue
			elif sabre_flight and not is_arm and shift.is_zero_approx():
				# The head can still be moving inward while the wall pins its
				# anchor. Confirm the block and follow the torso's retreat.
				shift = _wall_anchor_motion(state, gap, false)
				if not shift.is_zero_approx() and chest_state.linear_velocity.dot(shift) > 0.0:
					var toward_anchor := gap * (1.0 - SOURCE_ANCHOR_TOLERANCE / distance)
					if not _test_projection_motion(limb, state.transform, toward_anchor) \
							or _projection_hit.get_collision_safe_fraction() > 0.0:
						shift = Vector3.ZERO
				else:
					shift = Vector3.ZERO
			if not shift.is_zero_approx():
				largest_gap = distance
				motion = shift
				neck_wall = wall
				handoff_arm = null
				# A clean launch can pin both the chest and arm to the same
				# face. Let the existing overlap-checked retreat handle it.
				if is_arm and first_wall_window and distance > WALL_ARM_HANDOFF_MIN_GAP \
						and chest_state.get_contact_count() > 0 \
						and _shared_wall_contact(chest_state, state, shift).is_valid():
					handoff_arm = state
		if motion.is_zero_approx():
			return

	var gaps: Array[Vector3] = []
	for name: String in source_joint_rids:
		var spec: Dictionary = source_joints[name]
		var limb: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(limb.get_rid())
		if state == null or spec.parent != "Chest":
			return
		var gap: Vector3 = (chest_state.transform * spec.parent_frame).origin \
			- (state.transform * spec.child_frame).origin
		gaps.append(gap)
		var distance := gap.length()
		if not recent_handoff or distance <= largest_gap:
			continue
		var is_arm := name == "Arm.L" or name == "Arm.R"
		var shift := _wall_anchor_motion(state, gap, false, is_arm)
		if not shift.is_zero_approx():
			largest_gap = distance
			motion = shift
			handoff_arm = state if is_arm else null
	if motion.is_zero_approx():
		return
	var extended_arm_shift := motion.length_squared() > WALL_CHEST_MAX_SHIFT * WALL_CHEST_MAX_SHIFT + 0.000001
	if handoff_arm != null and extended_arm_shift and largest_gap > WALL_ARM_HANDOFF_MIN_GAP \
			and chest_state.get_contact_count() > 0:
		# A rebounding arm and chest on the same wall can need more room
		# than the ordinary rebound correction. Check the whole retreat.
		var wall := _shared_wall_contact(chest_state, handoff_arm, motion)
		var extra_motion := motion.normalized() * WALL_ARM_HANDOFF_MAX_SHIFT
		if wall.is_valid() and _wall_chest_shift_preserves_joints(gaps, largest_gap, extra_motion) \
				and _reduce_chest_wall_overlap(chest, chest_state, extra_motion, wall):
			return
	if _wall_chest_shift_preserves_joints(gaps, largest_gap, motion):
		if not _test_projection_motion(chest, chest_state.transform, motion):
			chest_state.transform = chest_state.transform.translated(motion)
			return
		if neck_wall.is_valid() and _reduce_chest_wall_overlap(chest, chest_state, motion, neck_wall):
			return
		var shared_wall_retreat := handoff_arm != null and not extended_arm_shift \
			and chest_state.get_contact_count() > 0 and chest_state.linear_velocity.dot(motion) > 0.0 \
			and _shared_wall_contact(chest_state, handoff_arm, motion).is_valid()
		if shared_wall_retreat or (extended_arm_shift and (recent_handoff or chest_state.get_contact_count() == 0)):
			# The forward sweep stops inside the chest's starting overlap.
			# Require clearance at the destination and sweep back to the start.
			var start := chest_state.transform
			_project_contacting_anchor(chest, chest_state, motion, true)
			if not chest_state.transform.is_equal_approx(start):
				return
	if extended_arm_shift:
		# A braced torso or another joint may still allow the ordinary shift.
		var fallback := motion.limit_length(WALL_CHEST_MAX_SHIFT)
		if _wall_chest_shift_preserves_joints(gaps, largest_gap, fallback) \
				and not _test_projection_motion(chest, chest_state.transform, fallback):
			chest_state.transform = chest_state.transform.translated(fallback)

func _recover_leading_head_wall_overlap() -> void:
	var head: PhysicalBone3D = bodies.Head
	var state := PhysicsServer3D.body_get_direct_state(head.get_rid())
	if state == null or state.linear_velocity.y >= 0.0 or state.get_contact_count() > 0:
		return
	var velocity := state.linear_velocity
	var travel := Vector2(velocity.x, velocity.z) * state.step
	if travel.length_squared() <= TERRAIN_DEEP_OVERLAP ** 2:
		return
	var chest: PhysicalBone3D = bodies.Chest
	var core := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if core == null or core.get_contact_count() > 0:
		return

	# A fast, rotating head can already overlap the wall before the solver
	# reports contact. Move the rig together and leave the rebound to the solver.
	var points := _terrain_contact_points(head, state, Vector3.ZERO)
	var deepest := TERRAIN_DEEP_RESIDUAL
	var correction := Vector3.ZERO
	for i in range(0, points.size(), 2):
		var offset := points[i + 1] - points[i]
		var depth := offset.length()
		if depth <= deepest or absf(offset.y) >= MAX_WALL_NORMAL_Y * depth:
			continue
		var normal := offset / depth
		var closing_speed := -velocity.dot(normal)
		if closing_speed <= 0.0 or (state.transform.origin - core.transform.origin).dot(normal) >= 0.0:
			continue
		deepest = depth
		var recovery := minf(depth - TERRAIN_RESIDUAL_OVERLAP, closing_speed * state.step * 0.5)
		correction = normal * minf(recovery, TERRAIN_MAX_RECOVERY_SHIFT)
	if not correction.is_zero_approx():
		_try_terrain_translation(correction, head)

func _slide_wall_shoulder_anchors() -> void:
	var chest: PhysicalBone3D = bodies.Chest
	var core := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if core == null:
		return
	# A clean launch can still hit the corner on the first few physics ticks.
	# Correct only large gaps and keep the translation parallel to the wall.
	var initial_collision := _wall_handoff_frame < 0
	var min_gap := FIRST_WALL_SHOULDER_SLIDE_MIN_GAP if initial_collision else WALL_SHOULDER_SLIDE_MIN_GAP
	var max_normal_fraction := 0.5 if initial_collision else 0.2
	for name in ["Arm.L", "Arm.R"]:
		var limb: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(limb.get_rid())
		if state == null:
			continue
		var spec: Dictionary = source_joints[name]
		var gap: Vector3 = (core.transform * spec.parent_frame).origin - (state.transform * spec.child_frame).origin
		var distance := gap.length()
		if distance <= min_gap:
			continue
		var contacts := state.get_contact_count()
		var free_torso := core.get_contact_count() == 0
		if (initial_collision and free_torso and contacts >= 2
				and absf(gap.y) >= FIRST_WALL_SHOULDER_SLIDE_MIN_GAP
				and _slide_at_wall_intersection(limb, state, gap.y)):
			continue
		# The shoulder can lose its solver contact while the wall still
		# blocks the motion to its anchor. Use the swept contact in that tick.
		var swept := contacts == 0
		if swept and (not initial_collision or not free_torso or distance <= WALL_SHOULDER_SLIDE_MIN_GAP
				or not _test_projection_motion(limb, state.transform, gap)
				or _projection_hit.get_collision_count() == 0):
			continue
		for i in maxi(contacts, 1):
			var wall := (_projection_hit.get_collider() if swept else state.get_contact_collider_object(i)) as StaticBody3D
			var normal := _projection_hit.get_collision_normal() if swept else state.get_contact_local_normal(i)
			if wall == null or absf(normal.y) >= MAX_WALL_NORMAL_Y:
				continue
			var normal_gap := gap.dot(normal)
			# An arm rebounding from the wall can also close a tangential
			# gap while the torso is free. Leave wall-normal motion to physics.
			var rebounding := normal_gap < 0.0 and free_torso \
				and state.linear_velocity.dot(normal) > 0.0
			var normal_fraction := REBOUND_SHOULDER_SLIDE_MAX_NORMAL_FRACTION if rebounding or swept else max_normal_fraction
			if absf(normal_gap) > distance * normal_fraction:
				continue
			var wall_rid := wall.get_rid()
			if not _is_single_box(wall_rid):
				continue
			# Sweep against the other geometry, then verify that sliding along
			# the contact face does not deepen the starting overlap.
			var motion := gap.slide(normal).limit_length(WALL_SHOULDER_SLIDE_MAX)
			if not _test_projection_motion(limb, state.transform, motion, wall_rid):
				var start := _deepest_contact(_terrain_contact_points(limb, state, Vector3.ZERO))
				var end := _deepest_contact(_terrain_contact_points(limb, state, motion))
				var mid := _deepest_contact(_terrain_contact_points(limb, state, motion * 0.5))
				if maxf(mid, end) <= maxf(start, PROJECTION_COLLISION_MARGIN) + PROJECTION_COLLISION_MARGIN:
					state.transform = state.transform.translated(motion)
			break

func _slide_at_wall_intersection(limb: PhysicalBone3D, state: PhysicsDirectBodyState3D, vertical_gap: float) -> bool:
	var walls: Array[RID] = []
	var first_normal := Vector3.ZERO
	for i in state.get_contact_count():
		var wall := state.get_contact_collider_object(i) as StaticBody3D
		var normal := state.get_contact_local_normal(i)
		if wall == null or absf(normal.y) > 0.001:
			return false
		var rid := wall.get_rid()
		if rid in walls:
			if walls.size() == 1 and normal.dot(first_normal) < 0.99:
				return false
			continue
		if walls.size() == 2 or not _is_single_box(rid):
			return false
		if walls.is_empty():
			first_normal = normal
		elif absf(normal.dot(first_normal)) > 0.1:
			return false
		walls.append(rid)
	if walls.size() != 2:
		return false
	# The vertical direction is tangent to both faces. Sweep it against
	# other geometry, then check overlap with the contacted walls as well.
	var motion := Vector3.UP * clampf(vertical_gap, -WALL_SHOULDER_SLIDE_MAX, WALL_SHOULDER_SLIDE_MAX)
	var sweep := PhysicsTestMotionParameters3D.new()
	sweep.from = state.transform
	sweep.motion = motion
	sweep.margin = PROJECTION_COLLISION_MARGIN
	sweep.recovery_as_collision = true
	sweep.exclude_bodies = walls
	if PhysicsServer3D.body_test_motion(limb.get_rid(), sweep):
		return false
	var start := _deepest_contact(_terrain_contact_points(limb, state, Vector3.ZERO))
	var mid := _deepest_contact(_terrain_contact_points(limb, state, motion * 0.5))
	var end := _deepest_contact(_terrain_contact_points(limb, state, motion))
	if maxf(mid, end) > maxf(start, PROJECTION_COLLISION_MARGIN) + PROJECTION_COLLISION_MARGIN:
		return false
	state.transform = state.transform.translated(motion)
	return true

func _is_single_box(body: RID) -> bool:
	return PhysicsServer3D.body_get_shape_count(body) == 1 \
		and PhysicsServer3D.shape_get_type(PhysicsServer3D.body_get_shape(body, 0)) == PhysicsServer3D.SHAPE_BOX

func _wall_chest_shift_preserves_joints(gaps: Array[Vector3], largest_gap: float, motion: Vector3) -> bool:
	for gap: Vector3 in gaps:
		if (gap + motion).length() > largest_gap:
			return false
	return true

func _shared_wall_contact(chest: PhysicsDirectBodyState3D, head: PhysicsDirectBodyState3D,
		motion: Vector3) -> RID:
	if motion.is_zero_approx():
		return RID()
	var away := motion.normalized()
	var wall := chest.get_contact_collider(0)
	if not wall.is_valid() or PhysicsServer3D.body_get_shape_count(wall) != 1:
		return RID()
	if PhysicsServer3D.shape_get_type(PhysicsServer3D.body_get_shape(wall, 0)) != PhysicsServer3D.SHAPE_BOX:
		return RID()
	for index in chest.get_contact_count():
		if chest.get_contact_collider(index) != wall or chest.get_contact_local_normal(index).dot(away) < 0.95:
			return RID()
	for index in head.get_contact_count():
		if head.get_contact_collider(index) == wall and head.get_contact_local_normal(index).dot(away) >= 0.95:
			return wall
	return RID()

func _reduce_chest_wall_overlap(chest: PhysicalBone3D, state: PhysicsDirectBodyState3D,
		motion: Vector3, wall: RID) -> bool:
	# Both boxes hit the same face. The chest can retreat even if 3 cm
	# is insufficient to clear its starting overlap in one physics tick.
	var start := state.transform
	if _test_projection_motion(chest, start, motion, wall):
		return false
	var depth := _deepest_contact(_terrain_contact_points(chest, state, Vector3.ZERO))
	var halfway := _deepest_contact(_terrain_contact_points(chest, state, motion * 0.5))
	var end := _deepest_contact(_terrain_contact_points(chest, state, motion))
	var distance := motion.length()
	if depth <= PROJECTION_COLLISION_MARGIN or halfway >= depth or end >= halfway \
			or end > maxf(depth - distance, 0.0) + 2.0 * PROJECTION_COLLISION_MARGIN:
		return false
	state.transform = start.translated(motion)
	return true

func _wall_anchor_motion(state: PhysicsDirectBodyState3D, gap: Vector3, require_rebound: bool,
		allow_extra_arm_shift := false) -> Vector3:
	for index in state.get_contact_count():
		var normal := state.get_contact_local_normal(index)
		if absf(normal.y) >= MAX_WALL_NORMAL_Y or not state.get_contact_collider_object(index) is StaticBody3D:
			continue
		var rebounding := state.linear_velocity.dot(normal) > 0.0
		if require_rebound and not rebounding:
			continue
		var blocked_distance := -gap.dot(normal) - SOURCE_ANCHOR_TOLERANCE
		if blocked_distance > 0.0:
			var max_shift := WALL_ARM_REBOUND_MAX_SHIFT if allow_extra_arm_shift and rebounding \
				else WALL_CHEST_MAX_SHIFT
			return normal * minf(blocked_distance, max_shift)
	return Vector3.ZERO

func _recover_floor_blocked_hip() -> void:
	if not _limit_first_contact_stretch or floor_landing_blended or floor_impact_blend > 0.0 \
			or not is_instance_valid(_flat_floor) or _flat_floor.disabled:
		return
	var chest: PhysicalBone3D = bodies.Chest
	var chest_state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if chest_state == null or chest_state.get_contact_count() > 0:
		return
	var lift := 0.0
	for name in ["Leg.L", "Leg.R"]:
		var limb: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(limb.get_rid())
		if state == null or state.linear_velocity.y >= 0.0:
			continue
		var spec: Dictionary = source_joints[name]
		var gap: Vector3 = (chest_state.transform * spec.parent_frame).origin \
			- (state.transform * spec.child_frame).origin
		if gap.y >= -EARLY_ROLL_ANCHOR_LIMIT or not _is_at_flat_floor(limb, state.transform):
			continue
		lift = maxf(lift, minf(-gap.y - SOURCE_ANCHOR_TOLERANCE, FIRST_FLOOR_CHEST_MAX_SHIFT))
	if lift <= 0.0:
		return

	# The leg cannot move down any farther. Let the free torso close part of
	# the gap only if it reduces the worst error across all five joints.
	var motion := Vector3.UP * lift
	var before := 0.0
	var after := 0.0
	for name: String in source_joint_rids:
		var spec: Dictionary = source_joints[name]
		var limb: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(limb.get_rid())
		if state == null or spec.parent != "Chest":
			return
		var gap: Vector3 = (chest_state.transform * spec.parent_frame).origin \
			- (state.transform * spec.child_frame).origin
		before = maxf(before, gap.length_squared())
		after = maxf(after, (gap + motion).length_squared())
	if after < before and not _test_projection_motion(chest, chest_state.transform, motion):
		chest_state.transform = chest_state.transform.translated(motion)

func _is_at_flat_floor(body: PhysicalBone3D, transform: Transform3D) -> bool:
	var floor_box := _flat_floor.shape as BoxShape3D
	var floor_pose := _flat_floor.global_transform
	if floor_box == null or not floor_pose.basis.y.is_equal_approx(Vector3.UP) \
			or not floor_pose.basis.get_scale().is_equal_approx(Vector3.ONE):
		return false
	var collider := body.get_child(0) as CollisionShape3D
	var shape := collider.shape as BoxShape3D
	var pose := floor_pose.affine_inverse() * transform * collider.transform
	var bounds := pose * AABB(-shape.size * 0.5, shape.size)
	var half := floor_box.size * 0.5
	return absf(bounds.position.y - half.y) <= FLOOR_REST_SLOP + PROJECTION_COLLISION_MARGIN \
		and bounds.position.x >= -half.x and bounds.end.x <= half.x \
		and bounds.position.z >= -half.z and bounds.end.z <= half.z

func _set_source_joint_bias(joint: RID, bias: float) -> void:
	if _source_joint_biases.get(joint, -1.0) == bias:
		return
	super._set_source_joint_bias(joint, bias)
	_source_joint_biases[joint] = bias

func release(visible_world_pose: Array[Transform3D] = []) -> void:
	super.release(visible_world_pose)
	_source_joint_biases.clear()
	_sample_names.clear()
	_sample_bone_ids.clear()
	_sample_body_offsets.clear()
