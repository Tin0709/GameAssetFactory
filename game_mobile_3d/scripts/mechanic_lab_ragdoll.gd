extends "res://scenes/dev/zombie_death_physics/ragdoll.gd"

const DEEP_CONTACT_LIFT_START := 0.10
const DEEP_CONTACT_LIFT_FULL := 0.112
const DEEP_CONTACT_SHARED_LIFT := 0.065
const EARLY_FLOOR_LIFT_START := 0.065
const EARLY_FLOOR_LIFT_FULL := 0.095
const EARLY_FLOOR_SHARED_LIFT := 0.045
const EARLY_FLOOR_LIFT_BLEND_END := 0.16
const HEAD_ROLL_LIFT_BLEND_START := 0.28
const HEAD_ROLL_LIFT_BLEND_END := 0.65
const LOCAL_FLOOR_LIFT_START := 0.057
const LOCAL_FLOOR_LIFT_FULL := 0.066
const LOCAL_FLOOR_SHARED_LIFT := 0.033
const FLOOR_CONTACT_GAP_DEPTH := 0.10
const EARLY_FLOOR_WALL_LOOKAHEAD := 5.0 / 60.0
const HANDOFF_TERRAIN_MASK := 1
const WALL_HANDOFF_RECOVERY_SECONDS := 0.12
const WALL_CHEST_MAX_SHIFT := 0.03
const WALL_ARM_REBOUND_MAX_SHIFT := 0.045
const WALL_ARM_HANDOFF_MAX_SHIFT := 0.06
const WALL_ARM_HANDOFF_MIN_GAP := 3.5 * SOURCE_ANCHOR_TOLERANCE
const WALL_NECK_BRACE_MIN_GAP := 2.5 * SOURCE_ANCHOR_TOLERANCE
const WALL_NECK_LANDING_BLEND_END := 0.5
const WALL_SHOULDER_SLIDE_WINDOW := 5.0 / 60.0
const WALL_SLIDE_MIN_GAP := 4.0 * SOURCE_ANCHOR_TOLERANCE
const FIRST_WALL_SHOULDER_SLIDE_MIN_GAP := 0.17
const TUNED_LIMB_RECOVERY_GAP := 8.0 * SOURCE_ANCHOR_TOLERANCE
const TUNED_WALL_SLIDE_MAX_VERTICAL_RATIO := 0.6
const WALL_SLIDE_MAX := 0.08
const REBOUND_SLIDE_MAX_NORMAL_FRACTION := 0.65
const FIRST_FLOOR_CHEST_MAX_SHIFT := 0.03
const EARLY_ARM_SLIDE_RESIDUAL := 0.125
const EARLY_ARM_SLIDE_EXTRA := 0.02
const BABY_FLOOR_ANCHOR_GAP := 0.08
const BABY_SUPPORTED_LEG_SLIDE_GAP := 2.0 * EARLY_ROLL_ANCHOR_LIMIT
const BABY_LARGE_LEG_SLIDE_GAP := 3.0 * EARLY_ROLL_ANCHOR_LIMIT
const BABY_FLOOR_ANCHOR_CLEARANCE := 0.02
const BABY_WALL_LIMB_SHIFT := 0.35
const BABY_WALL_CHEST_SHIFT := 0.10
const FLOOR_WALL_MAX_RECOVERY_TRAVEL := 0.20

var _handoff_query_snapshot: Dictionary[PhysicalBone3D, PhysicsShapeQueryParameters3D]
var _handoff_ray_region: AABB
var _handoff_region_floor: AABB
var _handoff_region_wall: AABB
var _sample_names: Array[String]
var _sample_bone_ids: Array[int]
var _sample_body_offsets: Array[Transform3D]
var _sampled_skeleton_transform: Transform3D
var _source_joint_biases: Dictionary[RID, float]
var _prepared_source_joints: Array[PhysicalPart]
var _wall_handoff_frame := -1
var _launch_frame := -1
var _tuned_wall_poses: Dictionary[String, Vector3]
var use_tuned_wall_sweep := false
var use_tuned_floor_support := false
var use_baby_floor_anchors := false
var _baby_wall_anchors := false
var wall_handoff_animation: AnimationPlayer
var wall_handoff_idle: StringName
var wall_handoff_idle_pose: Array[Transform3D]

static var _handoff_bounds_shape: BoxShape3D
static var _handoff_bounds_query: PhysicsShapeQueryParameters3D
static var _handoff_ray := PhysicsRayQueryParameters3D.new()
static var _handoff_box_queries: Dictionary[BoxShape3D, PhysicsShapeQueryParameters3D]
static var _body_shapes: Dictionary[Vector3, BoxShape3D]

func _make_body_shape(size: Vector3) -> BoxShape3D:
	if not _body_shapes.has(size):
		var box := super._make_body_shape(size)
		_body_shapes[size] = box
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = box
		query.collision_mask = HANDOFF_TERRAIN_MASK
		_handoff_box_queries[box] = query
	return _body_shapes[size]

func begin(profile: Resource, direction: Vector3, location: String, distance: float, gravity: float,
		flat_floor: CollisionShape3D = null, floor_impact_limb_share := 0.0, limit_first_contact_stretch := false,
		linear_override := INF, upward_override := INF) -> bool:
	if not super.begin(profile, direction, location, distance, gravity,
			flat_floor, floor_impact_limb_share, limit_first_contact_stretch, linear_override, upward_override):
		return false
	_launch_frame = Engine.get_physics_frames()
	if use_tuned_wall_sweep:
		for name: String in bodies:
			var body: PhysicalBone3D = bodies[name]
			_tuned_wall_poses[name] = body.global_position
	return true

func _correct_physical_pose() -> void:
	var frame := Engine.get_physics_frames()
	# Every physical bone calls this, but pose correction already processes the whole rig.
	if not running or _pose_correction_frame == frame:
		return
	if not use_tuned_wall_sweep:
		super._correct_physical_pose()
		return
	_sweep_tuned_lab_walls()
	super._correct_physical_pose()
	if use_tuned_floor_support and _limit_first_contact_stretch and not use_baby_floor_anchors and not _baby_wall_anchors:
		if frame <= _launch_frame + 1:
			_recover_tuned_wall_shoulders()
		elif floor_impact_blend <= 0.0:
			_recover_tuned_supported_legs()
	if _baby_wall_anchors:
		# A floor hit can hide a wall from the first ray. Check the
		# corrected pose before saving the start of the next sweep.
		_sweep_tuned_lab_walls()
	for name: String in bodies:
		var body: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state != null:
			_tuned_wall_poses[name] = state.transform.origin

func _sweep_tuned_lab_walls() -> void:
	# A fast, rotating part can reach the far side before Godot reports its
	# first contact. Sweep its centre and leave surface contacts to the solver.
	for name: String in _tuned_wall_poses:
		var body: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		var start := _tuned_wall_poses[name]
		var finish := state.transform.origin
		var travel := finish - start
		if Vector2(travel.x, travel.z).length_squared() <= PROJECTION_COLLISION_MARGIN ** 2:
			continue
		var space := state.get_space_state()
		_handoff_ray.collision_mask = body.collision_mask
		var velocity := state.linear_velocity
		# Sweep the remaining slide from the contact so it cannot cross
		# another face of the same corner.
		for sweep in 3:
			_handoff_ray.from = start
			_handoff_ray.to = finish
			var hit := space.intersect_ray(_handoff_ray)
			if not hit.is_empty() and is_instance_valid(_flat_floor) \
					and hit.collider == _flat_floor.get_parent() and hit.normal.is_equal_approx(Vector3.UP):
				hit = _wall_after_flat_floor(space, body, state.transform, hit.position, finish)
			if hit.is_empty() or not _is_fixed_wall(hit.collider) or absf(hit.normal.y) >= MAX_WALL_NORMAL_Y:
				start = finish
				break
			if use_baby_floor_anchors and use_tuned_floor_support:
				use_baby_floor_anchors = false
				_baby_wall_anchors = true
			var point: Vector3 = hit.position
			var normal: Vector3 = hit.normal
			start = point + normal * (2.0 * PROJECTION_COLLISION_MARGIN)
			finish = start + (finish - point).slide(normal)
			var closing := velocity.dot(normal)
			if closing < 0.0:
				velocity -= normal * closing
			if start.distance_squared_to(finish) <= PROJECTION_COLLISION_MARGIN ** 2:
				break
		if start != state.transform.origin:
			var pose := state.transform
			pose.origin = start
			state.transform = pose
			state.linear_velocity = velocity


func _wall_after_flat_floor(space: PhysicsDirectSpaceState3D, body: PhysicalBone3D,
		pose: Transform3D, contact: Vector3, finish: Vector3) -> Dictionary:
	var floor_box := _flat_floor.shape as BoxShape3D
	var floor_pose := _flat_floor.global_transform
	if floor_box == null or _flat_floor.disabled or not floor_pose.basis.y.is_equal_approx(Vector3.UP) \
			or not floor_pose.basis.get_scale().is_equal_approx(Vector3.ONE):
		return {}
	var half := floor_box.size * 0.5
	if absf(contact.y - floor_pose.origin.y - half.y) > PROJECTION_COLLISION_MARGIN:
		return {}
	var collider := body.get_child(0) as CollisionShape3D
	var shape := collider.shape as BoxShape3D
	pose.origin = finish
	var bounds := (floor_pose.affine_inverse() * pose * collider.transform) * AABB(-shape.size * 0.5, shape.size)
	if bounds.position.x < -half.x or bounds.end.x > half.x \
			or bounds.position.z < -half.z or bounds.end.z > half.z:
		return {}
	# Follow the rest of the horizontal path across the floor. Only an
	# obstacle that reaches the ground can block this part of the sweep.
	var height := contact.y + 2.0 * PROJECTION_COLLISION_MARGIN
	_handoff_ray.from = Vector3(contact.x, height, contact.z)
	_handoff_ray.to = Vector3(finish.x, height, finish.z)
	var wall := space.intersect_ray(_handoff_ray)
	if not wall.is_empty() and is_zero_approx(wall.normal.y):
		return wall
	return {}

func setup(target: Skeleton3D, part_layout: Array = PARTS, bone_names: Dictionary = {},
		body_offsets: Dictionary = {}, authored_joints: Dictionary = {}, prepared: PackedScene = null) -> void:
	super.setup(target, part_layout, bone_names, body_offsets, authored_joints, prepared)
	_sample_names.clear()
	_sample_bone_ids.clear()
	_sample_body_offsets.clear()
	for name: String in bodies:
		var body: PhysicalBone3D = bodies[name]
		_sample_names.append(name)
		_sample_bone_ids.append(body.get_bone_id())
		_sample_body_offsets.append(body.body_offset)

func prepare_source_joints() -> void:
	# Bind the authored data at spawn. Attach the native joints after simulation starts.
	_prepared_source_joints.clear()
	for child_name: String in source_joints:
		_prepared_source_joints.append(_prepare_source_joint(child_name))

func _build_source_joints() -> void:
	if _prepared_source_joints.is_empty():
		super._build_source_joints()
		return
	for projection in _prepared_source_joints:
		_attach_source_joint(projection)
	_prepared_source_joints.clear()

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
	var wall_tolerance := PROJECTION_COLLISION_MARGIN if use_tuned_wall_sweep else SOURCE_ANCHOR_TOLERANCE
	if wall_handoff_animation != null and (_handoff_straddles_wall(
			space, collision_mask, Vector3.ZERO, wall_tolerance, {})
			or _handoff_arm_is_pinched(space, overlaps)):
		_wall_handoff_frame = Engine.get_physics_frames()
		# All candidate poses share the rig's collision configuration.
		if collision_mask == HANDOFF_TERRAIN_MASK:
			for body: PhysicalBone3D in bodies.values():
				if body.collision_mask != HANDOFF_TERRAIN_MASK:
					continue
				var collider := body.get_child(0) as CollisionShape3D
				if collider.transform == Transform3D.IDENTITY:
					var query: PhysicsShapeQueryParameters3D = _handoff_box_queries.get(collider.shape)
					if query != null:
						_handoff_query_snapshot[body] = query
		var shift := _blend_wall_handoff(space, collision_mask, overlaps, bounds)
		_handoff_query_snapshot.clear()
		return shift
	return super._handoff_wall_clearance()

static func _is_fixed_wall(body: Object) -> bool:
	return body is StaticBody3D or (body is RigidBody3D and body.freeze)

func _handoff_arm_is_pinched(space: PhysicsDirectSpaceState3D, overlaps: Array[Dictionary]) -> bool:
	var wall_shapes := 0
	var floor_body := _flat_floor.get_parent()
	for hit in overlaps:
		var blocker: Object = hit.collider
		if blocker != floor_body and _is_fixed_wall(blocker):
			wall_shapes += PhysicsServer3D.body_get_shape_count(hit.rid)
	if wall_shapes < 2:
		return false
	# The arm box can overlap both sides of a seam while its centre still clears the walls.
	for name in ["Arm.L", "Arm.R"]:
		var points := _terrain_contacts_at(bodies[name], space, current[name])
		var normals: Array[Vector3] = []
		for i in range(0, points.size(), 2):
			var separation := points[i + 1] - points[i]
			var depth := separation.length()
			if depth <= HANDOFF_MIN_WALL_OVERLAP or absf(separation.y) >= depth * MAX_WALL_NORMAL_Y:
				continue
			var normal := separation / depth
			for other in normals:
				if normal.dot(other) < -0.90:
					return true
			normals.append(normal)
	return false

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

static func capture_wall_handoff_idle(rig: Skeleton3D, animation: AnimationPlayer,
		clip: StringName) -> Array[Transform3D]:
	animation.stop()
	rig.reset_bone_poses()
	animation.play(clip)
	animation.advance(0.0)
	animation.pause()
	var pose: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		pose.append(rig.get_bone_pose(bone))
	return pose

func _blend_wall_handoff(space: PhysicsDirectSpaceState3D, collision_mask: int,
		overlaps: Array[Dictionary], initial_bounds: AABB) -> Vector3:
	var wall := RID()
	var wall_bounds := AABB()
	for overlap in overlaps:
		var candidate := overlap.collider as PhysicsBody3D
		if not _is_fixed_wall(candidate) or candidate == _flat_floor.get_parent() or not _is_single_box(candidate.get_rid()):
			continue
		var rid := candidate.get_rid()
		var pose: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
		pose *= PhysicsServer3D.body_get_shape_transform(rid, 0)
		if pose.basis != Basis.IDENTITY:
			continue
		var half: Vector3 = PhysicsServer3D.shape_get_data(PhysicsServer3D.body_get_shape(rid, 0))
		wall = rid
		wall_bounds = AABB(pose.origin - half, half * 2.0)
		break
	var region := AABB()
	var floor_bounds := AABB()
	if wall.is_valid():
		floor_bounds = _handoff_floor_bounds()
		if floor_bounds.has_volume():
			# Check one neighborhood for every blend. Only limbs fully within
			# this volume qualify for skipping the subsequent contact queries.
			region = initial_bounds.grow(0.45)
			if not _handoff_region_is_clear(space, collision_mask, wall, region):
				region = AABB()
	_handoff_ray_region = region
	_handoff_region_floor = floor_bounds
	_handoff_region_wall = wall_bounds
	var source: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		source.append(skeleton.get_bone_pose(bone))
	var idle := wall_handoff_idle_pose
	if idle.size() != source.size():
		idle = capture_wall_handoff_idle(skeleton, wall_handoff_animation, wall_handoff_idle)
	else:
		# The cached pose drives every bone in the blend below. Keep the
		# living animation paused while ownership transfers to the simulator.
		wall_handoff_animation.pause()
	# Collision depends only on the sampled bones and their ancestors.
	var collision_bones := PackedInt32Array()
	var parent_bones := PackedInt32Array()
	for sampled_bone in _sample_bone_ids:
		var bone := sampled_bone
		while bone >= 0 and not collision_bones.has(bone):
			collision_bones.append(bone)
			bone = skeleton.get_bone_parent(bone)
			if bone >= 0 and not parent_bones.has(bone):
				parent_bones.append(bone)
	collision_bones.sort()

	# Search from the least visible correction. Interpolate the remaining
	# bones once the chosen blend is known.
	var selected_weight := 1.0
	var shift := Vector3.ZERO
	var shift_known := true
	var rays_clear := false
	for idle_weight: float in [0.25, 0.50, 0.75, 1.0]:
		selected_weight = idle_weight
		for bone in collision_bones:
			skeleton.set_bone_pose(bone, source[bone].interpolate_with(idle[bone], idle_weight))
		sample(sample_delta)
		# A blend can produce the same collider poses, especially from Idle.
		if idle_weight != 0.25 and current == previous and (idle_weight < 1.0 or shift_known):
			continue
		if idle_weight < 1.0 and wall.is_valid() \
				and _wall_blocks_every_handoff_shift(space, collision_mask, wall, wall_bounds, region, floor_bounds):
			shift_known = false
			continue
		var clear_parts := _find_clear_handoff_parts(region, floor_bounds, wall_bounds)
		shift = _solve_handoff_clearance(clear_parts)
		shift_known = true
		if idle_weight < 1.0 and _wall_handoff_is_clear(space, collision_mask, shift, "", {}, clear_parts):
			rays_clear = true
			break
	for bone in source.size():
		if not collision_bones.has(bone):
			skeleton.set_bone_pose(bone, source[bone].interpolate_with(idle[bone], selected_weight))
	var final_shift := _preserve_wall_handoff_branches(space, collision_mask, source, shift, parent_bones, rays_clear)
	_handoff_ray_region = AABB()
	return final_shift

func _handoff_floor_bounds() -> AABB:
	var floor := _flat_floor.get_parent() as StaticBody3D
	if floor == null or not _is_single_box(floor.get_rid()):
		return AABB()
	var rid := floor.get_rid()
	var pose: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	pose *= PhysicsServer3D.body_get_shape_transform(rid, 0)
	if pose.basis != Basis.IDENTITY:
		return AABB()
	var half: Vector3 = PhysicsServer3D.shape_get_data(PhysicsServer3D.body_get_shape(rid, 0))
	return AABB(pose.origin - half, half * 2.0)

func _handoff_region_is_clear(space: PhysicsDirectSpaceState3D, collision_mask: int,
		wall: RID, region: AABB) -> bool:
	var floor := _flat_floor.get_parent() as StaticBody3D
	_handoff_bounds_shape.size = region.size
	_handoff_bounds_query.transform = Transform3D(Basis.IDENTITY, region.get_center())
	_handoff_bounds_query.collision_mask = collision_mask
	_handoff_bounds_query.exclude = [wall, floor.get_rid()]
	var clear := space.intersect_shape(_handoff_bounds_query, 1).is_empty()
	_handoff_bounds_query.exclude = []
	return clear

func _find_clear_handoff_parts(region: AABB, floor_bounds: AABB,
		wall_bounds: AABB) -> Dictionary[String, bool]:
	var clear_parts: Dictionary[String, bool] = {}
	if not region.has_volume():
		return clear_parts
	# Endpoints and midpoints can translate horizontally by at most HANDOFF_MAX_SHIFT.
	var margin := Vector3(HANDOFF_MAX_SHIFT, 0.0, HANDOFF_MAX_SHIFT) + Vector3.ONE * PROJECTION_COLLISION_MARGIN
	for name: String in current:
		var body: PhysicalBone3D = bodies[name]
		var collider := body.get_child(0) as CollisionShape3D
		var box := collider.shape as BoxShape3D
		if box == null:
			continue
		var pose: Transform3D = current[name] * collider.transform
		var bounds := pose * AABB(-0.5 * box.size, box.size)
		bounds.position -= margin
		bounds.size += 2.0 * margin
		if region.encloses(bounds) and not bounds.intersects(floor_bounds) and not bounds.intersects(wall_bounds):
			clear_parts[name] = true
	return clear_parts

func _wall_blocks_every_handoff_shift(space: PhysicsDirectSpaceState3D, collision_mask: int,
		wall: RID, bounds: AABB, region: AABB, floor_bounds: AABB) -> bool:
	# Handoff shifts translate both ends of the ray by at most 12 cm horizontally.
	# Require the whole shifted segment to enter the same side face of the box.
	var margin := HANDOFF_MAX_SHIFT + PROJECTION_COLLISION_MARGIN
	var origin := skeleton.global_position
	var low := bounds.position
	var high := bounds.end
	for pose: Transform3D in current.values():
		var endpoint := pose.origin
		if endpoint.y <= low.y + PROJECTION_COLLISION_MARGIN or endpoint.y >= high.y - PROJECTION_COLLISION_MARGIN:
			continue
		var start := Vector3(origin.x, endpoint.y, origin.z)
		var ray_bounds := AABB(start.min(endpoint), (endpoint - start).abs())
		var crosses_x := (start.x < low.x - margin and endpoint.x > low.x + margin) \
			or (start.x > high.x + margin and endpoint.x < high.x - margin)
		var crosses_z := (start.z < low.z - margin and endpoint.z > low.z + margin) \
			or (start.z > high.z + margin and endpoint.z < high.z - margin)
		if not ((crosses_x and ray_bounds.position.z > low.z + margin and ray_bounds.end.z < high.z - margin)
				or (crosses_z and ray_bounds.position.x > low.x + margin and ray_bounds.end.x < high.x - margin)):
			continue
		# Another collider in the swept ray can change which side the ray sees.
		var envelope := ray_bounds.grow(margin)
		# This region has already been tested with the wall and floor excluded.
		if region.has_volume() and region.encloses(envelope) and not envelope.intersects(floor_bounds):
			return true
		_handoff_bounds_shape.size = envelope.size
		_handoff_bounds_query.transform = Transform3D(Basis.IDENTITY, envelope.get_center())
		_handoff_bounds_query.collision_mask = collision_mask
		_handoff_bounds_query.exclude = [wall]
		var unobstructed := space.intersect_shape(_handoff_bounds_query, 1).is_empty()
		_handoff_bounds_query.exclude = []
		if unobstructed:
			return true
	return false

func _preserve_wall_handoff_branches(space: PhysicsDirectSpaceState3D, collision_mask: int,
		source: Array[Transform3D], shift: Vector3, parent_bones: PackedInt32Array, rays_clear: bool) -> Vector3:
	# Keep source rotation on branches that can move without reopening the overlap.
	# The ray origin, shift, mask and terrain stay fixed throughout this search.
	var skeleton_transform := skeleton.global_transform
	var origin := skeleton_transform.origin + shift
	_handoff_ray.collision_mask = collision_mask
	var wall_crossings: Dictionary[Vector3, bool] = {}
	# The last blend can be selected without a branch clearance check.
	# Verify its rays once so each independent limb can test just its own pose.
	if not rays_clear:
		rays_clear = not _handoff_straddles_wall(space, collision_mask, shift, 0.0, wall_crossings)
	for name in ["Head", "Arm.L", "Arm.R", "Leg.L", "Leg.R"]:
		var body: PhysicalBone3D = bodies[name]
		var bone := body.get_bone_id()
		var safe_pose := skeleton.get_bone_pose(bone)
		# From a verified pose, a terminal branch can only change its own ray.
		var sample_index := _sample_names.find(name)
		var independent_part := sample_index >= 0 and not parent_bones.has(bone) \
			and _sample_bone_ids.count(bone) == 1
		var check_single_part := rays_clear and independent_part
		var start_rotation := safe_pose.basis.get_rotation_quaternion()
		var target_rotation := source[bone].basis.get_rotation_quaternion()
		var scale := Basis.from_scale(safe_pose.basis.get_scale())
		for weight: float in [1.0, 0.5, 0.25]:
			var basis := Basis(start_rotation.slerp(target_rotation, weight)) * scale
			skeleton.set_bone_pose(bone, Transform3D(basis, safe_pose.origin))
			var clear := false
			if check_single_part:
				var pose := skeleton_transform * skeleton.get_bone_global_pose(bone) \
					* _sample_body_offsets[sample_index]
				clear = not _wall_ray_crosses(space, origin, pose.origin, shift, 0.0, wall_crossings) \
					and _wall_handoff_part_is_clear(space, body, pose.translated(shift))
			else:
				sample(sample_delta)
				clear = _wall_handoff_is_clear(space, collision_mask, shift, name, wall_crossings)
			if clear:
				safe_pose = skeleton.get_bone_pose(bone)
				rays_clear = true
				break
		skeleton.set_bone_pose(bone, safe_pose)
		# Writing the pose can round its basis. Refresh the affected ray
		# before using the restored branch as evidence for the next one.
		if rays_clear:
			if independent_part:
				var pose := skeleton_transform * skeleton.get_bone_global_pose(bone) \
					* _sample_body_offsets[sample_index]
				rays_clear = not _wall_ray_crosses(space, origin, pose.origin, shift, 0.0, wall_crossings)
			else:
				rays_clear = skeleton.get_bone_pose(bone) == safe_pose
	# Both snapshots must agree so the correction itself doesn't become a launch impulse.
	sample(sample_delta)
	sample(sample_delta)
	return shift

func _wall_handoff_is_clear(space: PhysicsDirectSpaceState3D, collision_mask: int,
		shift: Vector3, changed_part: String, wall_crossings: Dictionary[Vector3, bool],
		clear_parts: Dictionary[String, bool] = {}) -> bool:
	if _handoff_straddles_wall(space, collision_mask, shift, 0.0, wall_crossings):
		return false
	if not changed_part.is_empty():
		var pose: Transform3D = current[changed_part]
		return _wall_handoff_part_is_clear(space, bodies[changed_part], pose.translated(shift))
	for name: String in current:
		# These parts clear terrain throughout the allowed horizontal shift.
		if clear_parts.has(name):
			continue
		var pose: Transform3D = current[name]
		if not _wall_handoff_part_is_clear(space, bodies[name], pose.translated(shift)):
			return false
	return true

func _wall_handoff_part_is_clear(space: PhysicsDirectSpaceState3D, body: PhysicalBone3D, pose: Transform3D) -> bool:
	var points := _terrain_contacts_at(body, space, pose)
	for i in range(0, points.size(), 2):
		var separation := points[i + 1] - points[i]
		var depth := separation.length()
		# Upward separation can support the pose. A deep downward separation
		# can pin a limb under an overhang or at the seam of two stacked boxes.
		if depth > HANDOFF_WALL_REST_OVERLAP and separation.y < depth * 0.7:
			return false
	return true

func _handoff_straddles_wall(space: PhysicsDirectSpaceState3D, collision_mask: int,
		shift: Vector3, tolerance: float, wall_crossings: Dictionary[Vector3, bool]) -> bool:
	# The synchronous query can reuse its parameters for the next body.
	_handoff_ray.collision_mask = collision_mask
	var origin := skeleton.global_position + shift
	for pose: Transform3D in current.values():
		if _wall_ray_crosses(space, origin, pose.origin, shift, tolerance, wall_crossings):
			return true
	return false

func _wall_ray_crosses(space: PhysicsDirectSpaceState3D, origin: Vector3, endpoint: Vector3,
		shift: Vector3, tolerance: float, wall_crossings: Dictionary[Vector3, bool]) -> bool:
	var cached: Variant = wall_crossings.get(endpoint)
	if cached != null:
		return cached
	var start := Vector3(origin.x, endpoint.y, origin.z)
	var finish := endpoint + shift
	if _handoff_ray_region.has_volume():
		# The region query excluded only the known floor and wall boxes.
		var ray_bounds := AABB(start.min(finish), (finish - start).abs()).grow(PROJECTION_COLLISION_MARGIN)
		if _handoff_ray_region.encloses(ray_bounds) and not _handoff_region_wall.intersects(ray_bounds) \
				and not _handoff_region_floor.intersects(ray_bounds):
			wall_crossings[endpoint] = false
			return false
	var crosses := false
	if start.distance_squared_to(finish) > SOURCE_ANCHOR_TOLERANCE * SOURCE_ANCHOR_TOLERANCE:
		_handoff_ray.from = start
		_handoff_ray.to = finish
		var hit := space.intersect_ray(_handoff_ray)
		if not hit.is_empty() and _is_fixed_wall(hit.collider):
			var normal: Vector3 = hit.normal
			var point: Vector3 = hit.position
			crosses = absf(normal.y) < MAX_WALL_NORMAL_Y and normal.dot(point - finish) > tolerance
	wall_crossings[endpoint] = crosses
	return crosses

func _terrain_contacts_at(body: PhysicalBone3D, space: PhysicsDirectSpaceState3D, pose: Transform3D) -> Array[Vector3]:
	var query: PhysicsShapeQueryParameters3D = _handoff_query_snapshot.get(body)
	if query != null:
		# Set the pose just before the synchronous physics query.
		query.transform = pose
		return space.collide_shape(query, 16)
	return super._terrain_contacts_at(body, space, pose)


func is_near_flat_floor(tolerance: float) -> bool:
	var floor_box := _flat_floor.shape as BoxShape3D
	var floor_pose := _flat_floor.global_transform
	if floor_box == null or not floor_pose.basis.y.is_equal_approx(Vector3.UP) \
			or not floor_pose.basis.get_scale().is_equal_approx(Vector3.ONE):
		return false
	var floor_half := floor_box.size * 0.5
	var floor_inverse := floor_pose.affine_inverse()
	var inner_minimum_y := INF
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		var size: Vector3 = part[2]
		var pose := floor_inverse * body.global_transform
		var bounds := pose * AABB(-size * 0.5, size)
		if bounds.position.x > floor_half.x or bounds.end.x < -floor_half.x \
				or bounds.position.z > floor_half.z or bounds.end.z < -floor_half.z:
			continue
		if bounds.position.x >= -floor_half.x and bounds.end.x <= floor_half.x \
				and bounds.position.z >= -floor_half.z and bounds.end.z <= floor_half.z:
			inner_minimum_y = minf(inner_minimum_y, bounds.position.y)
		elif bounds.position.y <= floor_half.y + tolerance and bounds.end.y >= floor_half.y - tolerance:
			# The lowest corner can hang beyond the lip while the rest of the part rolls on it.
			var edge_minimum_y := _floor_edge_minimum_y(pose, size * 0.5, bounds, floor_half)
			if absf(edge_minimum_y - floor_half.y) <= tolerance:
				return true
	return absf(inner_minimum_y - floor_half.y) <= tolerance

static func _floor_edge_minimum_y(pose: Transform3D, half: Vector3, bounds: AABB, floor_half: Vector3) -> float:
	var edges: Array[Plane] = []
	if bounds.position.x < -floor_half.x:
		edges.append(Plane(Vector3.LEFT, floor_half.x))
	if bounds.end.x > floor_half.x:
		edges.append(Plane(Vector3.RIGHT, floor_half.x))
	if bounds.position.z < -floor_half.z:
		edges.append(Plane(Vector3.FORWARD, floor_half.z))
	if bounds.end.z > floor_half.z:
		edges.append(Plane(Vector3.BACK, floor_half.z))
	var minimum_y := INF
	for axis in 3:
		var normal := pose.basis[axis]
		var side := 1.0 if normal.y < 0.0 else -1.0
		var center := pose.origin + normal * (half[axis] * side)
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var width := pose.basis[u] * half[u]
		var length := pose.basis[v] * half[v]
		var face := PackedVector3Array([
			center - width - length, center + width - length,
			center + width + length, center - width + length,
		])
		for edge in edges:
			face = Geometry3D.clip_polygon(face, edge)
			if face.is_empty():
				break
		for point in face:
			minimum_y = minf(minimum_y, point.y)
	return minimum_y

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
					and _is_fixed_wall(state.get_contact_collider_object(contact)):
				return true
	return false

func has_unbalanced_single_wall_support(minimum_margin: float) -> bool:
	if not _upper_body_on_single_wall():
		return false
	var floor := _flat_floor.get_parent()
	if not _body_supported_by(bodies["Leg.L"], floor) or not _body_supported_by(bodies["Leg.R"], floor):
		return false
	var footprint := PackedVector2Array()
	for name in ["Leg.L", "Leg.R"]:
		var collider := bodies[name].get_child(0) as CollisionShape3D
		var half := (collider.shape as BoxShape3D).size * 0.5
		var pose := collider.global_transform
		for x: float in [-1.0, 1.0]:
			for y: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					var corner := pose * (Vector3(x, y, z) * half)
					footprint.append(Vector2(corner.x, corner.z))
	# Use the complete foot boxes. Single reported points can lose their
	# contact patch for a tick even while the feet still carry the body.
	var hull := Geometry2D.convex_hull(footprint)
	var center := Vector3.ZERO
	var mass := 0.0
	for part in _physical_parts:
		var state := PhysicsServer3D.body_get_direct_state(part.rid)
		if state == null:
			return false
		center += (state.transform.origin + state.center_of_mass) * part.body.mass
		mass += part.body.mass
	var projected_center := Vector2(center.x, center.z) / mass
	if Geometry2D.is_point_in_polygon(projected_center, hull):
		return false
	for i in hull.size() - 1:
		var edge := Geometry2D.get_closest_point_to_segment(projected_center, hull[i], hull[i + 1])
		if edge.distance_to(projected_center) <= minimum_margin:
			return false
	return true


func _upper_body_on_single_wall() -> bool:
	var wall := RID()
	var face := -1
	var normal := Vector3.ZERO
	for name in ["Chest", "Head", "Leg.L", "Leg.R"]:
		var body: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			return false
		var upper_body: bool = name == "Chest" or name == "Head"
		var touched_wall := false
		for i in state.get_contact_count():
			var next := state.get_contact_local_normal(i)
			if absf(next.y) >= MAX_WALL_NORMAL_Y or not _is_fixed_wall(state.get_contact_collider_object(i)):
				continue
			if not upper_body:
				return false
			var rid := state.get_contact_collider(i)
			var shape := state.get_contact_collider_shape(i)
			if wall.is_valid() and (wall != rid or face != shape or normal.dot(next) < 0.95):
				return false
			wall = rid
			face = shape
			normal = next
			touched_wall = true
		if upper_body and not touched_wall:
			return false
	return true


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

func has_flat_corner_brace(max_linear := INF, max_angular := INF) -> bool:
	var floor_body := _flat_floor.get_parent()
	var foot_supported := false
	for name in ["Leg.L", "Leg.R"]:
		var body: PhysicalBone3D = bodies[name]
		if _body_supported_by(body, floor_body) and _body_below_speed(body, max_linear, max_angular):
			foot_supported = true
			break
	if not foot_supported or not _body_below_speed(bodies.Head, max_linear, max_angular) \
			or not _body_below_speed(bodies.Chest, max_linear, max_angular):
		return false
	var normals: Array[Vector3] = []
	var walls: Array[RID] = []
	var shapes := PackedInt32Array()
	for name in ["Head", "Chest"]:
		var body: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		for i in state.get_contact_count():
			var next := state.get_contact_local_normal(i)
			if absf(next.y) >= MAX_WALL_NORMAL_Y or not _is_fixed_wall(state.get_contact_collider_object(i)):
				continue
			var collider := state.get_contact_collider(i)
			var shape := state.get_contact_collider_shape(i)
			# Contact order can put a bevel before both supporting walls.
			# The two faces can belong to different shapes on one body.
			for previous in normals.size():
				if (collider != walls[previous] or shape != shapes[previous]) \
						and absf(normals[previous].dot(next)) < 0.25:
					return true
			normals.append(next)
			walls.append(collider)
			shapes.append(shape)
	return false

static func _body_below_speed(body: PhysicalBone3D, max_linear: float, max_angular: float) -> bool:
	return body.linear_velocity.length_squared() < max_linear * max_linear \
		and body.angular_velocity.length_squared() < max_angular * max_angular

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
			or shared_lift <= LOCAL_FLOOR_LIFT_START:
		return
	# Concentrated penetration needs more clearance at the deepest part.
	# Spread the remaining lift through the existing joint-limit pass.
	var concentration := 0.0
	if depths.size() == 1:
		concentration = 1.0
	elif depths.size() == 2:
		var depth := depths.values()
		var shallow := minf(depth[0], depth[1])
		var deep := maxf(depth[0], depth[1])
		concentration = smoothstep(2.5, 4.0, deep / shallow)
	var regular_weight := smoothstep(EARLY_FLOOR_LIFT_START, EARLY_FLOOR_LIFT_FULL, shared_lift)
	var local_weight := smoothstep(LOCAL_FLOOR_LIFT_START, LOCAL_FLOOR_LIFT_FULL, shared_lift) * concentration
	if regular_weight <= 0.0 and local_weight <= 0.0:
		return
	# A deeply overlapping single part can briefly have no solver contact
	# even though the prior contact has already started the landing blend.
	var floor_body := _flat_floor.get_parent()
	var deep_overlap := depths.size() == 1 and float(depths.values()[0]) - slop >= FLOOR_CONTACT_GAP_DEPTH
	var supported := false
	for body: PhysicalBone3D in bodies.values():
		if _body_supported_by(body, floor_body):
			supported = true
			break
	if not supported:
		regular_weight = 0.0
		if not deep_overlap:
			return
	var blend := 1.0 - smoothstep(EARLY_FLOOR_LIFT_BLEND_END * 0.5, EARLY_FLOOR_LIFT_BLEND_END, floor_impact_blend)
	var reduced_lift := lerpf(shared_lift, EARLY_FLOOR_SHARED_LIFT, regular_weight * blend)
	var local_lift := lerpf(shared_lift, LOCAL_FLOOR_SHARED_LIFT, local_weight * blend)
	if local_lift < reduced_lift and not _floor_roll_nears_obstacle(floor_body.get_rid()):
		reduced_lift = local_lift
	if reduced_lift < shared_lift:
		_distribute_floor_lift(lifts, depths, shared_lift, slop, reduced_lift, anchor_limit)

func _project_floor_contact() -> void:
	super._project_floor_contact()
	if not use_tuned_floor_support or not floor_landing_blended:
		return
	var floor_body := _flat_floor.get_parent() as StaticBody3D
	if floor_body == null or not _flat_floor.global_basis.y.is_equal_approx(Vector3.UP):
		return
	var default_gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	# Once the landing blend has finished, carry the added gravity through
	# the supported parts. This keeps the normal solver from repeatedly
	# lifting those parts out of the floor under the higher load.
	for part in _physical_parts:
		var state := PhysicsServer3D.body_get_direct_state(part.rid)
		if state == null or state.sleeping or not _body_supported_by(part.body, floor_body):
			continue
		var added_acceleration := -state.total_gravity.y - default_gravity
		if added_acceleration > 0.0:
			PhysicsServer3D.body_apply_central_force(part.rid, Vector3.UP * added_acceleration * part.body.mass)

func _resolve_floor_anchor_lifts(lifts: Dictionary[PhysicalBone3D, float], depths: Dictionary[PhysicalBone3D, float],
		shared_lift: float, slop: float, landing_blended: bool) -> void:
	super._resolve_floor_anchor_lifts(lifts, depths, shared_lift, slop, landing_blended)
	if (landing_blended or not _flat_floor_has_contact or floor_impact_blend <= HEAD_ROLL_LIFT_BLEND_START
			or floor_impact_blend >= HEAD_ROLL_LIFT_BLEND_END or shared_lift <= FLOOR_SINGLE_PART_SHARED_LIFT or depths.size() < 2):
		return
	var head: PhysicalBone3D = bodies.Head
	var head_overlap: float = depths.get(head, 0.0) - slop
	if head_overlap <= 0.045:
		return
	var other_overlap := 0.0
	for body: PhysicalBone3D in depths:
		if body != head:
			other_overlap = maxf(other_overlap, depths[body] - slop)
	# Keep more of a deep head correction local when every other part still
	# fits within the shared lift allowed for a single penetrating part.
	# A second part barely past the floor tolerance should not spread
	# a deep head correction across the rest of the rig.
	var shallow_secondary := 1.0 - smoothstep(FLOOR_CONTACT_SLOP * 0.5, FLOOR_CONTACT_SLOP, other_overlap)
	var deep_head := smoothstep(0.030, 0.036, head_overlap - shared_lift)
	var spare_lift := 1.0 - smoothstep(
		FLOOR_SINGLE_PART_SHARED_LIFT - FLOOR_CONTACT_SLOP, FLOOR_SINGLE_PART_SHARED_LIFT, other_overlap)
	var weight := smoothstep(0.045, 0.060, head_overlap) * maxf(shallow_secondary, deep_head * spare_lift)
	weight *= smoothstep(HEAD_ROLL_LIFT_BLEND_START, 0.36, floor_impact_blend) \
		* (1.0 - smoothstep(0.43, HEAD_ROLL_LIFT_BLEND_END, floor_impact_blend))
	if weight <= 0.0 or _floor_roll_nears_obstacle(_flat_floor.get_parent().get_rid()):
		return
	var local_lift := lerpf(shared_lift, FLOOR_SINGLE_PART_SHARED_LIFT, weight)
	_distribute_floor_lift(lifts, depths, shared_lift, slop, local_lift, EARLY_ROLL_ANCHOR_LIMIT)


func _floor_roll_nears_obstacle(floor: RID, include_contacts := false) -> bool:
	# Preserve the incoming pose of a roll that is about to contact a wall.
	for part in _physical_parts:
		var state := PhysicsServer3D.body_get_direct_state(part.rid)
		if state == null:
			continue
		if include_contacts:
			for index in state.get_contact_count():
				if state.get_contact_collider(index) != floor:
					return true
		var travel := state.linear_velocity.slide(Vector3.UP) * EARLY_FLOOR_WALL_LOOKAHEAD
		if _test_projection_motion(part.body, state.transform, travel, floor):
			return true
	return false

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

func _recover_baby_floor_anchors() -> void:
	var tuned := use_tuned_wall_sweep
	if not tuned and (floor_landing_blended or floor_impact_blend >= EARLY_ROLL_ANCHOR_BLEND_END):
		return
	if not is_instance_valid(_flat_floor) or _flat_floor.disabled:
		return
	var floor_body := _flat_floor.get_parent() as StaticBody3D
	var floor_box := _flat_floor.shape as BoxShape3D
	var floor_pose := _flat_floor.global_transform
	if floor_body == null or floor_box == null or not floor_pose.basis.y.is_equal_approx(Vector3.UP) \
			or not floor_pose.basis.get_scale().is_equal_approx(Vector3.ONE):
		return
	var floor_inverse := floor_pose.affine_inverse()
	var floor_half := floor_box.size * 0.5
	var floor_rid := floor_body.get_rid()
	var chest: PhysicalBone3D = bodies.Chest
	var parent := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if parent == null or (not tuned and parent.get_contact_count() > 0):
		return
	var gap_limit := BABY_FLOOR_ANCHOR_GAP if tuned else BABY_SUPPORTED_LEG_SLIDE_GAP
	var checked_obstacles := false
	for joint in _source_anchor_projections:
		var leg := joint.name == "Leg.L" or joint.name == "Leg.R"
		if not tuned and not leg:
			continue
		var state := PhysicsServer3D.body_get_direct_state(joint.rid)
		if state == null:
			continue
		var gap := (parent.transform * joint.parent_frame).origin - (state.transform * joint.child_frame).origin
		if not tuned:
			# Keep a planted leg on the floor when a large sideways error
			# opens ahead of the chest contact.
			gap.y = 0.0
		var distance := gap.length()
		if distance <= gap_limit or (not tuned and not _body_supported_by(joint.body, floor_body)):
			continue
		var tolerance := SOURCE_ANCHOR_TOLERANCE
		if not tuned and distance <= BABY_LARGE_LEG_SLIDE_GAP:
			# A smaller gap can be part of the planted leg's roll. Help only
			# when it opens quickly and leave more room for the support solver.
			var relative_velocity := parent.linear_velocity - state.linear_velocity
			var separation_step := relative_velocity.dot(gap / distance) * state.step
			if separation_step <= EARLY_ROLL_ANCHOR_LIMIT:
				continue
			tolerance = EARLY_ROLL_ANCHOR_LIMIT
		var local := floor_inverse * state.transform
		var extent := Basis(local.basis.x.abs(), local.basis.y.abs(), local.basis.z.abs()) * joint.half_size
		var clearance := local.origin.y - extent.y - floor_half.y
		var above_floor := tuned and clearance > BABY_FLOOR_ANCHOR_CLEARANCE and not _body_supported_by(joint.body, floor_body)
		if above_floor and (not leg or distance <= TUNED_LIMB_RECOVERY_GAP):
			continue
		if local.origin.y + extent.y < floor_half.y:
			continue
		# Bound the anchor correction by the travel the two pieces can cover in one step.
		var motion := gap * (1.0 - tolerance / distance)
		motion.y = maxf(motion.y, -maxf(clearance + FLOOR_REST_SLOP, 0.0))
		var speed_sum := float(chest.get("maximum_linear_speed")) + float(joint.body.get("maximum_linear_speed"))
		motion = motion.limit_length(speed_sum * state.step)
		var end := local.origin + floor_inverse.basis * motion
		if maxf(absf(end.x), absf(local.origin.x)) + extent.x > floor_half.x \
				or maxf(absf(end.z), absf(local.origin.z)) + extent.z > floor_half.z:
			continue
		if above_floor:
			_recover_raised_leg_wall_overlap(joint, state, motion, floor_rid,
				floor_pose.origin.y + floor_half.y)
			continue
		if tuned and not checked_obstacles:
			if _floor_roll_nears_obstacle(floor_rid, true):
				use_baby_floor_anchors = false
				_baby_wall_anchors = use_tuned_floor_support
				return
			checked_obstacles = true
		if _test_projection_motion(joint.body, state.transform, motion, floor_rid):
			motion *= _projection_hit.get_collision_safe_fraction()
		if not motion.is_zero_approx():
			state.transform = state.transform.translated(motion)

func _leg_has_side_contact(state: PhysicsDirectBodyState3D) -> bool:
	for contact in state.get_contact_count():
		if absf(state.get_contact_local_normal(contact).y) < MAX_WALL_NORMAL_Y \
				and _is_fixed_wall(state.get_contact_collider_object(contact)):
			return true
	return false

func _recover_raised_leg_wall_overlap(joint: PhysicalPart, state: PhysicsDirectBodyState3D,
		motion: Vector3, floor: RID, floor_y: float) -> void:
	var pose := state.transform
	if not _test_projection_motion(joint.body, pose, motion) or _projection_hit.get_collision_safe_fraction() > 0.0:
		return
	var normal := _projection_hit.get_collision_normal()
	if absf(normal.y) >= MAX_WALL_NORMAL_Y or not _is_fixed_wall(_projection_hit.get_collider()):
		return
	# The solver can report a side hit at zero distance even while the leg
	# is moving away. Clear the initial box overlap and sweep the remainder.
	var retreat := _wall_overlap_retreat(joint.body, pose, joint.half_size, motion, normal, floor)
	if retreat.is_zero_approx():
		# Give the first-contact solver its existing window. After that,
		# a limb still braced on a side face can close the gap along it.
		var first_contact_ticks := roundi(WALL_SHOULDER_SLIDE_WINDOW * Engine.physics_ticks_per_second)
		if not use_tuned_floor_support and Engine.get_physics_frames() - _launch_frame > first_contact_ticks \
				and _leg_has_side_contact(state):
			_slide_floor_wall_part(joint.body, state, joint.half_size, motion, floor_y, floor)
		return
	var separated := pose.translated(retreat)
	var remainder := motion - retreat
	if _test_projection_motion(joint.body, separated, remainder):
		remainder *= _projection_hit.get_collision_safe_fraction()
	state.transform = separated.translated(remainder)

func _baby_neck_needs_wall_recovery() -> bool:
	var head: PhysicalBone3D = bodies.Head
	var state := PhysicsServer3D.body_get_direct_state(head.get_rid())
	if state == null or state.get_contact_count() == 0:
		return false
	for contact in state.get_contact_count():
		if absf(state.get_contact_local_normal(contact).y) >= MAX_WALL_NORMAL_Y \
				or not _is_fixed_wall(state.get_contact_collider_object(contact)):
			continue
		var chest: PhysicalBone3D = bodies.Chest
		var parent := PhysicsServer3D.body_get_direct_state(chest.get_rid())
		if parent == null:
			return false
		var joint: Dictionary = source_joints.Head
		var gap: Vector3 = (parent.transform * joint.parent_frame).origin - (state.transform * joint.child_frame).origin
		return gap.length_squared() > WALL_SLIDE_MIN_GAP ** 2
	return false

func _recover_tuned_supported_legs() -> void:
	if not is_instance_valid(_flat_floor) or _flat_floor.disabled:
		return
	var floor_body := _flat_floor.get_parent() as StaticBody3D
	var floor_box := _flat_floor.shape as BoxShape3D
	if floor_body == null or floor_box == null or not _flat_floor.global_basis.y.is_equal_approx(Vector3.UP):
		return
	var chest: PhysicalBone3D = bodies.Chest
	var core := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if core == null or core.linear_velocity.y >= 0.0:
		return
	var core_contacts := core.get_contact_count()
	var floor := floor_body.get_rid()
	var floor_y := _flat_floor.global_position.y + floor_box.size.y * 0.5
	for joint in _source_anchor_projections:
		if joint.name != "Leg.L" and joint.name != "Leg.R":
			continue
		var state := PhysicsServer3D.body_get_direct_state(joint.rid)
		if state == null:
			continue
		var contacts := state.get_contact_count()
		if contacts == 0:
			continue
		var gap := (core.transform * joint.parent_frame).origin - (state.transform * joint.child_frame).origin
		if gap.length_squared() <= TUNED_LIMB_RECOVERY_GAP ** 2:
			continue
		var wall_support := false
		var floor_support := false
		var floor_only := true
		for i in contacts:
			var normal := state.get_contact_local_normal(i)
			var obstacle := state.get_contact_collider_object(i) as PhysicsBody3D
			var on_floor := obstacle == floor_body and normal.y >= MIN_SUPPORT_NORMAL_Y
			floor_support = floor_support or on_floor
			floor_only = floor_only and on_floor
			if absf(normal.y) < MAX_WALL_NORMAL_Y and gap.dot(normal) > 0.0 and _is_fixed_wall(obstacle):
				wall_support = wall_support or _is_single_box(obstacle.get_rid())
		if not floor_support:
			continue
		var tangent := gap.slide(Vector3.UP)
		var limit := (core.linear_velocity.length() + state.linear_velocity.length()) * state.step
		var motion := tangent.limit_length(limit)
		if core_contacts == 0 and wall_support and gap.y < 0.0:
			_slide_floor_wall_part(joint.body, state, joint.half_size, motion, floor_y, floor)
		elif core_contacts == 0 and floor_only and absf(gap.y) <= SOURCE_ANCHOR_TOLERANCE \
				and tangent.length_squared() > TUNED_LIMB_RECOVERY_GAP ** 2:
			# With a supported foot and the separation parallel to the ground,
			# keep floor height and let the swept slide follow the torso.
			if _test_projection_motion(joint.body, state.transform, motion, floor):
				motion *= _projection_hit.get_collision_safe_fraction()
			if not motion.is_zero_approx():
				state.transform = state.transform.translated(motion)
		elif floor_only and gap.y < -SOURCE_ANCHOR_TOLERANCE \
				and -gap.y <= TUNED_WALL_SLIDE_MAX_VERTICAL_RATIO * tangent.length() \
				and tangent.length_squared() > TUNED_LIMB_RECOVERY_GAP ** 2:
			# A vertical wall can block the inward component while the planted leg
			# still has room to follow along the wall. Keep true upper-body support.
			var side_contact := true
			for contact in core_contacts:
				side_contact = side_contact and absf(core.get_contact_local_normal(contact).y) < MAX_WALL_NORMAL_Y \
					and _is_fixed_wall(core.get_contact_collider_object(contact))
			if core_contacts == 0:
				side_contact = _test_projection_motion(joint.body, state.transform, motion, floor) \
					and absf(_projection_hit.get_collision_normal().y) < MAX_WALL_NORMAL_Y \
					and _is_fixed_wall(_projection_hit.get_collider())
			if side_contact:
				_slide_floor_wall_part(joint.body, state, joint.half_size, motion, floor_y, floor)


func _recover_tuned_wall_shoulders() -> void:
	if not is_instance_valid(_flat_floor) or _flat_floor.disabled:
		return
	var chest: PhysicalBone3D = bodies.Chest
	var core := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if core == null or core.get_contact_count() != 0:
		return
	for joint in _source_anchor_projections:
		if joint.name != "Arm.L" and joint.name != "Arm.R":
			continue
		var state := PhysicsServer3D.body_get_direct_state(joint.rid)
		if state == null or state.get_contact_count() == 0:
			continue
		var gap := (core.transform * joint.parent_frame).origin - (state.transform * joint.child_frame).origin
		var distance := gap.length()
		if distance <= TUNED_LIMB_RECOVERY_GAP:
			continue
		for i in state.get_contact_count():
			var normal := state.get_contact_local_normal(i)
			var wall := state.get_contact_collider_object(i) as PhysicsBody3D
			if absf(normal.y) >= MAX_WALL_NORMAL_Y or gap.dot(normal) <= PROJECTION_COLLISION_MARGIN \
					or not _is_fixed_wall(wall):
				continue
			# Bound the correction by how far the two parts can separate in one step.
			var relative_speed := float(joint.body.get("maximum_linear_speed")) + float(chest.get("maximum_linear_speed"))
			var limit := relative_speed * state.step
			if _recover_first_wall_shoulder(joint, state, wall.get_rid(), normal, gap, limit):
				break


func _recover_first_wall_shoulder(joint: PhysicalPart, state: PhysicsDirectBodyState3D,
		wall: RID, normal: Vector3, gap: Vector3, limit: float) -> bool:
	if not _is_single_box(wall) or normal.y != 0.0 or (absf(normal.x) != 1.0 and absf(normal.z) != 1.0):
		return false
	var wall_pose: Transform3D = PhysicsServer3D.body_get_state(wall, PhysicsServer3D.BODY_STATE_TRANSFORM)
	wall_pose *= PhysicsServer3D.body_get_shape_transform(wall, 0)
	if wall_pose.basis != Basis.IDENTITY:
		return false
	var wall_half: Vector3 = PhysicsServer3D.shape_get_data(PhysicsServer3D.body_get_shape(wall, 0))
	var pose := state.transform
	var side := (pose.origin - wall_pose.origin).dot(normal)
	if side <= 0.0:
		return false
	var extent := (pose.basis.transposed() * normal).abs().dot(joint.half_size)
	var retreat_distance := maxf(wall_half.dot(normal.abs()) + extent - side + 2.0 * PROJECTION_COLLISION_MARGIN, 0.0)
	if retreat_distance > limit:
		return false
	# Clear the contacted face first. The retreat only moves out of this
	# box, and both it and the following tangent sweep test all other bodies.
	var retreat := normal * retreat_distance
	if retreat_distance > 0.0 and _test_projection_motion(joint.body, pose, retreat, wall):
		return false
	var tangent := gap.slide(normal).limit_length(maxf(limit - retreat_distance, 0.0))
	var separated := pose.translated(retreat)
	if _test_projection_motion(joint.body, separated, tangent):
		tangent *= _projection_hit.get_collision_safe_fraction()
	var motion := retreat + tangent
	if (gap - motion).length_squared() >= gap.length_squared():
		return false
	state.transform = pose.translated(motion)
	return true


func _recover_baby_wall_anchors() -> void:
	if not is_instance_valid(_flat_floor) or _flat_floor.disabled:
		return
	var floor_body := _flat_floor.get_parent() as StaticBody3D
	var floor_box := _flat_floor.shape as BoxShape3D
	if floor_body == null or floor_box == null or not _flat_floor.global_basis.y.is_equal_approx(Vector3.UP):
		return
	var floor_y := _flat_floor.global_position.y + floor_box.size.y * 0.5
	var floor := floor_body.get_rid()
	var chest: PhysicalBone3D = bodies.Chest
	var parent := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if parent == null:
		return
	var chest_box := (chest.get_child(0) as CollisionShape3D).shape as BoxShape3D
	var chest_half := chest_box.size * 0.5
	# When the floor and a wall block a limb, move the chest toward
	# the residual instead of trying to push the limb through the corner.
	for pass_index in 2:
		for joint in _source_anchor_projections:
			var child := PhysicsServer3D.body_get_direct_state(joint.rid)
			if child == null:
				continue
			var gap := (parent.transform * joint.parent_frame).origin - (child.transform * joint.child_frame).origin
			var distance := gap.length()
			if distance <= BABY_FLOOR_ANCHOR_GAP:
				continue
			var motion := gap * (1.0 - SOURCE_ANCHOR_TOLERANCE / distance)
			var moved := _slide_floor_wall_part(joint.body, child, joint.half_size,
				motion.limit_length(BABY_WALL_LIMB_SHIFT), floor_y, floor)
			_slide_floor_wall_part(chest, parent, chest_half,
				(moved - motion).limit_length(BABY_WALL_CHEST_SHIFT), floor_y, floor)

func _slide_floor_wall_part(body: PhysicalBone3D, state: PhysicsDirectBodyState3D, half_size: Vector3,
		motion: Vector3, floor_y: float, floor: RID) -> Vector3:
	var start := state.transform.origin
	var basis := state.transform.basis
	var floor_clearance := start.y - Vector3(absf(basis.x.y), absf(basis.y.y), absf(basis.z.y)).dot(half_size) - floor_y
	# Clamp against the floor plane before each wall sweep so its
	# solver overlap does not block tangential motion at the corner.
	for sweep in 3:
		var moved_y := state.transform.origin.y - start.y
		var lowest_travel := -maxf(floor_clearance + moved_y + FLOOR_REST_SLOP, 0.0)
		motion.y = maxf(motion.y, lowest_travel)
		if motion.length_squared() <= PROJECTION_COLLISION_MARGIN ** 2:
			break
		if not _test_projection_motion(body, state.transform, motion, floor):
			state.transform = state.transform.translated(motion)
			break
		var normal := _projection_hit.get_collision_normal()
		var fraction := _projection_hit.get_collision_safe_fraction()
		if fraction == 0.0 and normal.y <= -MAX_WALL_NORMAL_Y and _is_fixed_wall(_projection_hit.get_collider()):
			var retreat := _wall_overlap_retreat(body, state.transform, half_size, motion, normal, floor)
			if not retreat.is_zero_approx():
				state.transform = state.transform.translated(retreat)
				motion -= retreat
				continue
		if fraction == 0.0 and absf(normal.y) < MAX_WALL_NORMAL_Y and _is_fixed_wall(_projection_hit.get_collider()):
			# The initial overlap can report a zero-distance hit even when
			# the part has room along the wall. Let the query separate the
			# box first, then sweep the requested correction from there.
			_projection_query.recovery_as_collision = false
			var collided := _test_projection_motion(body, state.transform, motion, floor)
			_projection_query.recovery_as_collision = true
			var travel := _projection_hit.get_travel()
			if travel.length() <= motion.length() + FLOOR_WALL_MAX_RECOVERY_TRAVEL and travel.y >= lowest_travel:
				state.transform = state.transform.translated(travel)
				if not collided:
					break
				motion = _projection_hit.get_remainder().slide(_projection_hit.get_collision_normal())
				continue
		state.transform = state.transform.translated(motion * fraction)
		if motion.dot(normal) >= 0.0:
			break
		motion = (motion * (1.0 - fraction)).slide(normal)
	return state.transform.origin - start

func _wall_overlap_retreat(body: PhysicalBone3D, pose: Transform3D, half_size: Vector3,
		motion: Vector3, normal: Vector3, floor: RID) -> Vector3:
	# Clear the overlapping box along the requested horizontal motion in the wall's frame.
	var wall := _projection_hit.get_collider_rid()
	var collider := body.get_child(0) as CollisionShape3D
	if collider == null or collider.transform != Transform3D.IDENTITY or not _is_single_box(wall):
		return Vector3.ZERO
	var wall_pose: Transform3D = PhysicsServer3D.body_get_state(wall, PhysicsServer3D.BODY_STATE_TRANSFORM)
	wall_pose *= PhysicsServer3D.body_get_shape_transform(wall, 0)
	var rotation := wall_pose.basis
	if not rotation.y.is_equal_approx(Vector3.UP) or not is_equal_approx(rotation.determinant(), 1.0) \
			or not rotation.is_equal_approx(rotation.orthonormalized()):
		return Vector3.ZERO
	var wall_half: Vector3 = PhysicsServer3D.shape_get_data(PhysicsServer3D.body_get_shape(wall, 0))
	var horizontal := rotation.transposed() * normal
	horizontal.y = 0.0
	if not is_zero_approx(horizontal.x) and not is_zero_approx(horizontal.z):
		return Vector3.ZERO
	if horizontal.is_zero_approx():
		# An underside hit can point straight down. Use the nearest side on
		# the part's half of the box, subject to the same outward motion check.
		var relative := rotation.transposed() * (pose.origin - wall_pose.origin)
		var face_distance := (wall_half - relative.abs()).abs()
		horizontal = Vector3(relative.x, 0.0, 0.0) if face_distance.x <= face_distance.z else Vector3(0.0, 0.0, relative.z)
	var local_axis := Vector3(signf(horizontal.x), 0.0, 0.0) if is_zero_approx(horizontal.z) else Vector3(0.0, 0.0, signf(horizontal.z))
	var axis := rotation * local_axis
	var outward_travel := motion.dot(axis)
	if outward_travel <= 0.0:
		return Vector3.ZERO
	var wall_centre := wall_pose.origin.dot(axis)
	var part_centre := pose.origin.dot(axis)
	if part_centre <= wall_centre:
		return Vector3.ZERO
	var face := wall_centre + wall_half.dot(local_axis.abs())
	var extent := (pose.basis.transposed() * axis).abs().dot(half_size)
	var clearance := face - (part_centre - extent) + 2.0 * PROJECTION_COLLISION_MARGIN
	if clearance <= 0.0 or clearance > outward_travel:
		return Vector3.ZERO
	var retreat := axis * clearance
	# Overlap with this wall only decreases along the retreat. Sweep against
	# all other obstacles before moving the part.
	_projection_query.from = pose
	_projection_query.motion = retreat
	_projection_query.exclude_bodies = [floor, wall]
	var blocked := PhysicsServer3D.body_test_motion(body.get_rid(), _projection_query)
	_projection_query.exclude_bodies = []
	return Vector3.ZERO if blocked else retreat

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
	if use_baby_floor_anchors:
		_recover_baby_floor_anchors()
	# The head box can touch the wall before its center reaches the wall sweep.
	if use_baby_floor_anchors and use_tuned_floor_support and _baby_neck_needs_wall_recovery():
		use_baby_floor_anchors = false
		_baby_wall_anchors = true
	if _baby_wall_anchors:
		_recover_baby_wall_anchors()
	if first_wall_window:
		_slide_wall_shoulder_anchors()
	elif lab_floor and floor_impact_blend <= 0.0:
		_slide_rebounding_legs()
		if use_tuned_wall_sweep and not use_tuned_floor_support:
			_recover_rebounding_wall_legs()
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
	var min_gap := FIRST_WALL_SHOULDER_SLIDE_MIN_GAP if initial_collision else WALL_SLIDE_MIN_GAP
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
		if swept and (not initial_collision or not free_torso or distance <= WALL_SLIDE_MIN_GAP
				or not _test_projection_motion(limb, state.transform, gap)
				or _projection_hit.get_collision_count() == 0):
			continue
		for i in maxi(contacts, 1):
			var wall := (_projection_hit.get_collider() if swept else state.get_contact_collider_object(i)) as PhysicsBody3D
			var normal := _projection_hit.get_collision_normal() if swept else state.get_contact_local_normal(i)
			if not _is_fixed_wall(wall) or absf(normal.y) >= MAX_WALL_NORMAL_Y:
				continue
			var normal_gap := gap.dot(normal)
			# An arm rebounding from the wall can also close a tangential
			# gap while the torso is free. Leave wall-normal motion to physics.
			var rebounding := normal_gap < 0.0 and free_torso \
				and state.linear_velocity.dot(normal) > 0.0
			var normal_fraction := REBOUND_SLIDE_MAX_NORMAL_FRACTION if rebounding or swept else max_normal_fraction
			if absf(normal_gap) > distance * normal_fraction:
				continue
			var wall_rid := wall.get_rid()
			if not _is_single_box(wall_rid):
				continue
			# Sweep against the other geometry, then verify that sliding along
			# the contact face does not deepen the starting overlap.
			_slide_along_wall(limb, state, gap, normal, wall_rid)
			break

func _recover_rebounding_wall_legs() -> void:
	# At extreme launch, a wall can hold a leg down while the torso rebounds.
	# Sweep the leg back toward its joint without changing the rebound velocity.
	var floor_body := _flat_floor.get_parent() as StaticBody3D
	var floor_box := _flat_floor.shape as BoxShape3D
	if floor_body == null or floor_box == null or not _flat_floor.global_basis.y.is_equal_approx(Vector3.UP):
		return
	var floor := floor_body.get_rid()
	var floor_y := _flat_floor.global_position.y + floor_box.size.y * 0.5
	var core := PhysicsServer3D.body_get_direct_state(bodies.Chest.get_rid())
	if core == null:
		return
	for joint in _source_anchor_projections:
		if joint.name != "Leg.L" and joint.name != "Leg.R":
			continue
		var state := PhysicsServer3D.body_get_direct_state(joint.rid)
		if state == null or not _leg_has_side_contact(state):
			continue
		var gap := (core.transform * joint.parent_frame).origin - (state.transform * joint.child_frame).origin
		var distance := gap.length()
		if distance <= TUNED_LIMB_RECOVERY_GAP or gap.y <= SOURCE_ANCHOR_TOLERANCE:
			continue
		var advance := (core.linear_velocity - state.linear_velocity).dot(gap / distance) * state.step
		if advance <= SOURCE_ANCHOR_TOLERANCE:
			continue
		var motion := gap * (minf(advance, distance - SOURCE_ANCHOR_TOLERANCE) / distance)
		_slide_floor_wall_part(joint.body, state, joint.half_size, motion, floor_y, floor)


func _slide_rebounding_legs() -> void:
	var torso: PhysicalBone3D = bodies.Chest
	var core := PhysicsServer3D.body_get_direct_state(torso.get_rid())
	if core == null or core.get_contact_count() != 0 or core.linear_velocity.y >= 0.0:
		return
	# A falling leg can rebound before the rest of the body reaches the
	# wall. Close the large tangential gap without altering its rebound.
	for name in ["Leg.L", "Leg.R"]:
		var limb: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(limb.get_rid())
		if state == null or state.get_contact_count() == 0 or state.linear_velocity.y >= 0.0:
			continue
		var spec: Dictionary = source_joints[name]
		var gap: Vector3 = (core.transform * spec.parent_frame).origin - (state.transform * spec.child_frame).origin
		var distance := gap.length()
		if distance <= WALL_SLIDE_MIN_GAP:
			continue
		for i in state.get_contact_count():
			var wall := state.get_contact_collider_object(i) as PhysicsBody3D
			var normal := state.get_contact_local_normal(i)
			if not _is_fixed_wall(wall) or absf(normal.y) >= MAX_WALL_NORMAL_Y or state.linear_velocity.dot(normal) <= 0.0:
				continue
			var normal_gap := gap.dot(normal)
			if normal_gap >= 0.0 or -normal_gap > distance * REBOUND_SLIDE_MAX_NORMAL_FRACTION:
				continue
			var wall_rid := wall.get_rid()
			if _is_single_box(wall_rid) and _slide_along_wall(limb, state, gap, normal, wall_rid):
				break

func _slide_along_wall(limb: PhysicalBone3D, state: PhysicsDirectBodyState3D,
		gap: Vector3, normal: Vector3, wall: RID) -> bool:
	var motion := gap.slide(normal).limit_length(WALL_SLIDE_MAX)
	if _test_projection_motion(limb, state.transform, motion, wall):
		return false
	var start := _deepest_contact(_terrain_contact_points(limb, state, Vector3.ZERO))
	var end := _deepest_contact(_terrain_contact_points(limb, state, motion))
	var mid := _deepest_contact(_terrain_contact_points(limb, state, motion * 0.5))
	if maxf(mid, end) > maxf(start, PROJECTION_COLLISION_MARGIN) + PROJECTION_COLLISION_MARGIN:
		return false
	state.transform = state.transform.translated(motion)
	return true

func _slide_at_wall_intersection(limb: PhysicalBone3D, state: PhysicsDirectBodyState3D, vertical_gap: float) -> bool:
	var walls: Array[RID] = []
	var first_normal := Vector3.ZERO
	for i in state.get_contact_count():
		var wall := state.get_contact_collider_object(i) as PhysicsBody3D
		var normal := state.get_contact_local_normal(i)
		if not _is_fixed_wall(wall) or absf(normal.y) > 0.001:
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
	var motion := Vector3.UP * clampf(vertical_gap, -WALL_SLIDE_MAX, WALL_SLIDE_MAX)
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
		if absf(normal.y) >= MAX_WALL_NORMAL_Y or not _is_fixed_wall(state.get_contact_collider_object(index)):
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
	_prepared_source_joints.clear()
	super.release(visible_world_pose)
	_source_joint_biases.clear()
	_sample_names.clear()
	_sample_bone_ids.clear()
	_sample_body_offsets.clear()
