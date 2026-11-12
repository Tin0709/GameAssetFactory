extends Node
## Native skeletal adapter with contact recovery for the lab floor and authored terrain.
const PHYSICAL_PART = preload("res://scenes/dev/zombie_death_physics/physical_part.gd")
const PARTS := [
	# name, Skeleton Y-up rest center, inset box, kg, bend°, twist°
	["Hips", Vector3(0, 0.765, 0), Vector3(0.36, 0.18, 0.16), 8.0, 0.0, 0.0],
	["Chest", Vector3(0, 1.0125, 0), Vector3(0.43, 0.655, 0.205), 22.0, 6.0, 4.0],
	["Head", Vector3(0, 1.575, 0), Vector3(0.43, 0.43, 0.43), 8.0, 16.0, 10.0],
	["Arm.L", Vector3(0.3375, 1.0125, 0), Vector3(0.205, 0.655, 0.205), 4.0, 40.0, 14.0],
	["Arm.R", Vector3(-0.3375, 1.0125, 0), Vector3(0.205, 0.655, 0.205), 4.0, 40.0, 14.0],
	["Leg.L", Vector3(0.1125, 0.3375, 0), Vector3(0.205, 0.655, 0.205), 7.0, 25.0, 10.0],
	["Leg.R", Vector3(-0.1125, 0.3375, 0), Vector3(0.205, 0.655, 0.205), 7.0, 25.0, 10.0],
]
const PARENTS := {"Chest": "Hips", "Head": "Chest", "Arm.L": "Chest", "Arm.R": "Chest", "Leg.L": "Hips", "Leg.R": "Hips"}
const FLOOR_CONTACT_SLOP := 0.005
const FLOOR_REST_SLOP := 0.012
const FLOOR_SHARED_LIFT_THRESHOLD := 0.05
const FLOOR_EXCESS_LIFT_PART_SHARE := 0.35
const MIN_SUPPORT_NORMAL_Y := 0.5
const MAX_WALL_NORMAL_Y := 0.10
const HANDOFF_MIN_WALL_OVERLAP := 0.035
const HANDOFF_WALL_REST_OVERLAP := 0.012
const HANDOFF_MAX_SHIFT := 0.12
const TERRAIN_MIN_FALL_SPEED := 2.0
const TERRAIN_MIN_SUPPORT_Y := 0.85
const TERRAIN_MIN_OVERLAP := 0.035
const TERRAIN_RESIDUAL_OVERLAP := 0.018
const TERRAIN_DEEP_OVERLAP := 0.12
const TERRAIN_DEEP_RESIDUAL := 0.08
const TERRAIN_MAX_RECOVERY_SHIFT := 0.14
const CONE_DEFAULT_BIAS := 0.30
const CONE_OVERSHOOT_BIAS := 0.10
const CONE_SUPPORT_OVERSHOOT_COS := cos(deg_to_rad(75.0))
# SK_Zombie_PhysicsAsset enables linear projection with a 5 cm tolerance.
const SOURCE_ANCHOR_TOLERANCE := 0.05
const PROJECTION_COLLISION_MARGIN := 0.001
const CONTACT_ANCHOR_RECOVERY_MAX_SHIFT := 0.18
@export var maximum_inherited_linear_speed := 3.0
@export var maximum_inherited_angular_speed := 10.0
var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Dictionary = {}
var previous: Dictionary = {}
var current: Dictionary = {}
var sample_delta := 1.0 / 60.0
var sample_count := 0
var running := false
var handoff_error := 0.0
var inherited: Dictionary = {}
var anchors: Dictionary = {}
var total_applied_impulse := Vector3.ZERO
var impact_distribution: Dictionary = {}
var last_strength := 1.0
var joint_rest_rotations: Dictionary = {}
var resistance_gain := 0.0
var resistance_age := 0.0
var _parts: Array = PARTS
var source_joints: Dictionary
var source_joint_rids: Dictionary[String, RID]
var _flat_floor: CollisionShape3D
var _split_floor_impact := false
var _flat_floor_has_contact := false
var _pose_correction_frame := -1
var _terrain_poses: Dictionary[String, Transform3D]
var _terrain_query: PhysicsShapeQueryParameters3D
var _projection_query: PhysicsTestMotionParameters3D
var _projection_hit: PhysicsTestMotionResult3D
# (Nm/rad, Nms/rad): soft restoring torque plus relative angular damping.
const JOINT_RESPONSE := {"Chest": Vector2(18,5.4), "Head": Vector2(4,2.4), "Arm.L": Vector2(3,2.1), "Arm.R": Vector2(3,2.1), "Leg.L": Vector2(6,2.7), "Leg.R": Vector2(6,2.7)}

func setup(target: Skeleton3D, part_layout: Array = PARTS, bone_names: Dictionary = {},
		body_offsets: Dictionary = {}, authored_joints: Dictionary = {}) -> void:
	set_physics_process(false)
	skeleton = target
	_parts = part_layout
	source_joints = authored_joints
	# Reject unsupported rigs instead of quietly binding the wrong bones/scale.
	assert(skeleton.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Ragdoll requires unit-scale hierarchy")
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "DeathPhysicsSimulator"
	skeleton.add_child(simulator)
	simulator.active = false
	for part in _parts:
		var bone_name: String = bone_names.get(part[0], part[0])
		var id := skeleton.find_bone(bone_name)
		assert(id >= 0, "Missing ragdoll bone: " + bone_name)
		var body := PhysicalBone3D.new()
		body.set_script(PHYSICAL_PART)
		body.name = "Corpse_" + part[0]
		body.set("bone_name", bone_name)
		body.body_offset = body_offsets.get(part[0],
			skeleton.get_bone_global_rest(id).affine_inverse() * Transform3D(Basis.IDENTITY, part[1]))
		body.mass = part[3]
		body.friction = 0.75
		body.bounce = 0.0
		body.collision_layer = 2
		body.collision_mask = 1 # Ground only. No self/corpse/live-controller collisions.
		body.can_sleep = true
		body.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		body.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = part[2]
		shape.custom_solver_bias = 0.6 # Stronger contact recovery for the new fast launches.
		collider.shape = shape
		body.add_child(collider)
		simulator.add_child(body)
		PhysicsServer3D.body_set_enable_continuous_collision_detection(body.get_rid(), true)
		PhysicsServer3D.body_set_max_contacts_reported(body.get_rid(), 4)
		if part[0] == "Hips":
			# Utility carrier supports the torso: use finite torso-like inertia, not a tiny hinge.
			PhysicsServer3D.body_set_param(body.get_rid(), PhysicsServer3D.BODY_PARAM_INERTIA, Vector3(0.6, 0.4, 0.6))
		bodies[part[0]] = body

func sample(delta: float) -> void:
	previous = current.duplicate()
	current.clear()
	sample_delta = delta
	for name in bodies:
		var body: PhysicalBone3D = bodies[name]
		current[name] = skeleton.global_transform * skeleton.get_bone_global_pose(body.get_bone_id()) * body.body_offset
	sample_count += 1

func begin(profile: Resource, direction: Vector3, location: String, distance: float, gravity: float,
		flat_floor: CollisionShape3D = null, split_floor_impact := false) -> bool:
	if running or sample_count < 2: return false
	running = true
	_flat_floor = flat_floor
	_split_floor_impact = split_floor_impact and not source_joints.is_empty()
	_flat_floor_has_contact = false
	if _flat_floor != null or not source_joints.is_empty():
		for body: PhysicalBone3D in bodies.values():
			body.set("pose_correction", _correct_physical_pose)
	var handoff_shift := _handoff_wall_clearance() if not source_joints.is_empty() else Vector3.ZERO
	if not handoff_shift.is_zero_approx():
		skeleton.global_position += handoff_shift
	simulator.active = true
	# This refreshes all cached animated poses, sets all body transforms and changes mode.
	simulator.physical_bones_start_simulation()
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		handoff_error = maxf(handoff_error, body.global_position.distance_to(current[part[0]].origin + handoff_shift))
		body.gravity_scale = gravity / float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		body.linear_damp = profile.linear_damping
		body.angular_damp = profile.angular_damping
		var a: Transform3D = previous[part[0]]
		var b: Transform3D = current[part[0]]
		var velocity := ((b.origin - a.origin) / sample_delta).limit_length(maximum_inherited_linear_speed)
		var dq := (b.basis.get_rotation_quaternion() * a.basis.get_rotation_quaternion().inverse()).normalized()
		if dq.w < 0.0: dq = -dq
		# atan2 logarithm remains accurate for very small per-tick rotations.
		var imaginary := Vector3(dq.x, dq.y, dq.z)
		var angle := 2.0 * atan2(imaginary.length(), dq.w)
		var angular := (imaginary.normalized() * angle / sample_delta).limit_length(maximum_inherited_angular_speed)
		inherited[part[0]] = {"linear": velocity, "angular": angular}
		body.linear_velocity = velocity
		body.angular_velocity = angular
	if not source_joints.is_empty():
		_build_source_joints()
		apply_impact(profile, direction, location, distance)
		return true
	# Rebuild frames only AFTER every body has the current pose. Native parent frame
	# is computed from this exact pose, accommodating animated bone translations.
	# Limits are relative to the captured pose; no rest-pose projection/correction.
	for part in _parts:
		if part[0] == "Hips": continue
		var body: PhysicalBone3D = bodies[part[0]]
		body.joint_rotation = Vector3(0, 0, PI / 2.0) # Joint X axis along rigid part Y.
		body.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		for axis_name in ["x", "y", "z"]:
			var prefix: String = "joint_constraints/" + axis_name + "/"
			var span: float = minf(80.0, (part[5] if axis_name == "x" else part[4]) * profile.limit_scale)
			body.set(prefix + "angular_limit_lower", -span)
			body.set(prefix + "angular_limit_upper", span)
			body.set(prefix + "angular_restitution", 0.0)
			body.set(prefix + "linear_restitution", 0.5)
			body.set(prefix + "erp", 0.15)

		var joint_world := body.global_transform * body.joint_offset
		var parent: PhysicalBone3D = bodies[PARENTS[part[0]]]
		anchors[part[0]] = parent.global_transform.affine_inverse() * joint_world
		joint_rest_rotations[part[0]] = (parent.global_basis.inverse() * body.global_basis).get_rotation_quaternion()
	resistance_gain = profile.joint_resistance
	set_physics_process(resistance_gain > 0.0)
	apply_impact(profile, direction, location, distance)
	return true

func _handoff_wall_clearance() -> Vector3:
	# The living capsule can clear the wall while an animated limb overlaps it.
	# Test the captured boxes before the solver can turn that overlap into a kick.
	var space := skeleton.get_world_3d().direct_space_state
	var depths: Dictionary[String, float] = {}
	var candidates: Array[Vector3] = []
	var initial_peak := 0.0
	for part in _parts:
		var name: String = part[0]
		var points := _terrain_contacts_at(bodies[name], space, current[name])
		depths[name] = _deepest_contact(points)
		initial_peak = maxf(initial_peak, depths[name])
		var deepest_wall := HANDOFF_MIN_WALL_OVERLAP
		var wall_motion := Vector3.ZERO
		for i in range(0, points.size(), 2):
			var offset := points[i + 1] - points[i]
			var depth := offset.length()
			if depth <= deepest_wall or absf(offset.y) > depth * 0.7:
				continue
			var horizontal := Vector3(offset.x, 0.0, offset.z)
			var clearance := (depth - HANDOFF_WALL_REST_OVERLAP) * depth / horizontal.length()
			wall_motion = horizontal.normalized() * minf(clearance, HANDOFF_MAX_SHIFT)
			deepest_wall = depth
		if not wall_motion.is_zero_approx():
			candidates.append(wall_motion)
	var best := Vector3.ZERO
	var best_depth := initial_peak
	for motion in candidates:
		var peak := _handoff_clearance_depth(space, depths, motion)
		if peak < best_depth - FLOOR_CONTACT_SLOP:
			best = motion
			best_depth = peak
	return best

func _handoff_clearance_depth(space: PhysicsDirectSpaceState3D, depths: Dictionary[String, float], motion: Vector3) -> float:
	var peak := 0.0
	for name in depths:
		var pose: Transform3D = current[name]
		var limit := maxf(depths[name], FLOOR_CONTACT_SLOP) + PROJECTION_COLLISION_MARGIN
		var midway := _deepest_contact(_terrain_contacts_at(bodies[name], space, pose.translated(motion * 0.5)))
		var after := _deepest_contact(_terrain_contacts_at(bodies[name], space, pose.translated(motion)))
		if maxf(midway, after) > limit:
			return INF
		peak = maxf(peak, after)
	return peak

func _build_source_joints() -> void:
	# PhysicalBone3D's automatic joint follows the Skeleton3D hierarchy and
	# derives one frame from the current pose. MD2 legs connect to J_Spine,
	# so supply both authored frames to the Godot physics server explicitly.
	for child_name: String in source_joints:
		var spec: Dictionary = source_joints[child_name]
		var child: PhysicalBone3D = bodies[child_name]
		var parent: PhysicalBone3D = bodies[spec.parent]
		var joint := PhysicsServer3D.joint_create()
		PhysicsServer3D.joint_make_cone_twist(joint, parent.get_rid(), spec.parent_frame,
			child.get_rid(), spec.child_frame)
		PhysicsServer3D.cone_twist_joint_set_param(joint, PhysicsServer3D.CONE_TWIST_JOINT_SWING_SPAN, deg_to_rad(spec.swing))
		PhysicsServer3D.cone_twist_joint_set_param(joint, PhysicsServer3D.CONE_TWIST_JOINT_TWIST_SPAN, deg_to_rad(spec.twist))
		source_joint_rids[child_name] = joint

func _physics_process(delta: float) -> void:
	if not running: return
	resistance_age += delta
	if resistance_age >= 2.0:
		# Leave the final passive corpse free to sleep; no perpetual motor or pose writer.
		set_physics_process(false)
		return
	var gain := resistance_gain * (1.0 - smoothstep(1.2,2.0,resistance_age))
	for name in joint_rest_rotations:
		var child: PhysicalBone3D = bodies[name]
		var parent: PhysicalBone3D = bodies[PARENTS[name]]
		var target: Quaternion = parent.global_basis.get_rotation_quaternion() * joint_rest_rotations[name]
		var error := (target * child.global_basis.get_rotation_quaternion().inverse()).normalized()
		if error.w < 0.0: error = -error
		var imaginary := Vector3(error.x,error.y,error.z)
		var angle := imaginary.normalized() * (2.0 * atan2(imaginary.length(),error.w))
		var response: Vector2 = JOINT_RESPONSE[name]
		# Implicit angular damping stays stable at 60 Hz / high resistance.
		# J = dt(k*error - c*(w + (Ic^-1+Ip^-1)*J)).
		var child_state := PhysicsServer3D.body_get_direct_state(child.get_rid())
		var parent_state := PhysicsServer3D.body_get_direct_state(parent.get_rid())
		if not child_state or not parent_state: continue
		var ci: Basis = child_state.inverse_inertia_tensor
		var pi: Basis = parent_state.inverse_inertia_tensor
		var inverse_inertia := Basis(ci.x+pi.x,ci.y+pi.y,ci.z+pi.z)
		var damping := response.y * gain
		var scaled := inverse_inertia * (damping * delta)
		var solve := Basis(Vector3.RIGHT+scaled.x,Vector3.UP+scaled.y,Vector3.BACK+scaled.z)
		var relative: Vector3 = child.angular_velocity-parent.angular_velocity
		var impulse: Vector3 = solve.inverse() * ((angle * response.x * gain-relative * damping) * delta)
		impulse = impulse.limit_length(40.0 * delta)
		# Equal/opposite internal torques resist flailing without braking whole-body travel.
		PhysicsServer3D.body_apply_torque_impulse(child.get_rid(),impulse)
		PhysicsServer3D.body_apply_torque_impulse(parent.get_rid(),-impulse)

func apply_impact(profile: Resource, direction: Vector3, location: String, distance: float) -> void:
	var dir := direction.normalized()
	if dir.is_zero_approx(): dir = Vector3.FORWARD
	var target_name := "Chest"
	if location == "Head": target_name = "Head"
	elif location == "Hip": target_name = "Hips"
	var target: PhysicalBone3D = bodies[target_name]
	# Offset is tied to anatomical right, expressed in world axes (not body-local apply_impulse input).
	var side := 0.0
	if location == "Right shoulder": side = -0.24
	elif location == "Left shoulder": side = 0.24
	var hit := target.global_position + target.global_basis * Vector3(side, 0.24 if side != 0.0 else 0.08, 0.10)
	last_strength = profile.strength_at(distance)
	var total: Vector3 = (dir * profile.linear_impulse + Vector3.UP * profile.upward_impulse) * last_strength
	total_applied_impulse = total
	impact_distribution.clear()
	# A common added velocity carries the 60kg assembly together. The remaining
	# event impulse hits the selected region/pellet pattern and supplies asymmetry.
	# Both shares add to ONE event J; no per-limb copy of the full weapon impulse.
	var mass := 0.0
	for body in bodies.values(): mass += body.mass
	var transport: Vector3 = total * clampf(profile.transport_fraction, 0.0, 0.98)
	for body in bodies.values():
		var impulse: Vector3 = transport * body.mass / mass
		body.apply_central_impulse(impulse)
		impact_distribution[body.name] = impulse
	total -= transport
	if profile.aggregate_pellets:
		# Five weighted pattern samples, one event, no projectile physics objects.
		# Route to current box surfaces so spread can share load with a shoulder/head.
		# Sum J exactly equals total; all offsets contribute their own r×J once.
		var right := dir.cross(Vector3.UP).normalized()
		if right.is_zero_approx(): right = Vector3.RIGHT
		var up := right.cross(dir).normalized()
		var radius: float = profile.pattern_radius
		var offsets := [Vector3.ZERO, right * radius, -right * radius, up * radius, -up * radius]
		var weights := [0.4, 0.15, 0.15, 0.15, 0.15]
		for i in offsets.size():
			var point: Vector3 = hit + offsets[i]
			var receiver: PhysicalBone3D = nearest_part(point)
			var impulse: Vector3 = total * weights[i]
			receiver.apply_impulse(impulse, point - receiver.global_position)
			impact_distribution[receiver.name] = impact_distribution.get(receiver.name, Vector3.ZERO) + impulse
	else:
		target.apply_impulse(total, hit - target.global_position)
		impact_distribution[target.name] = impact_distribution.get(target.name, Vector3.ZERO) + total
	var axis := Vector3.UP.cross(dir).normalized()
	if axis.is_zero_approx(): axis = Vector3.RIGHT
	# A bounded whole-pattern art control, not an extra impulse per pellet.
	var torque: Vector3 = (axis + Vector3.UP * (-side * 2.0)).normalized() * profile.angular_impulse * last_strength
	PhysicsServer3D.body_apply_torque_impulse(target.get_rid(), torque)

func nearest_part(world_point: Vector3) -> PhysicalBone3D:
	var nearest: PhysicalBone3D = bodies.Chest
	var best := INF
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		var point := body.global_transform.affine_inverse() * world_point
		var half: Vector3 = part[2] * 0.5
		var separation := point.distance_squared_to(point.clamp(-half, half))
		if separation < best:
			best = separation
			nearest = body
	return nearest

func max_anchor_error() -> float:
	var result := 0.0
	for child_name: String in source_joint_rids:
		var spec: Dictionary = source_joints[child_name]
		var child: PhysicalBone3D = bodies[child_name]
		var parent: PhysicalBone3D = bodies[spec.parent]
		var child_frame: Transform3D = child.global_transform * spec.child_frame
		var parent_frame: Transform3D = parent.global_transform * spec.parent_frame
		result = maxf(result, child_frame.origin.distance_to(parent_frame.origin))
	for name in anchors:
		var child: PhysicalBone3D = bodies[name]
		var parent: PhysicalBone3D = bodies[PARENTS[name]]
		result = maxf(result, (parent.global_transform * anchors[name]).origin.distance_to((child.global_transform * child.joint_offset).origin))
	return result

func minimum_corner_y() -> float:
	var result := INF
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		var half: Vector3 = part[2] * 0.5
		for x in [-1, 1]:
			for y in [-1, 1]:
				for z in [-1, 1]:
					result = minf(result, (body.global_transform * (half * Vector3(x,y,z))).y)
	return result

func _correct_physical_pose() -> void:
	var frame := Engine.get_physics_frames()
	if not running or _pose_correction_frame == frame:
		return
	_pose_correction_frame = frame
	if is_instance_valid(_flat_floor) and not _flat_floor.disabled:
		_project_floor_contact()
	elif not source_joint_rids.is_empty():
		_project_terrain_contact()
	if not source_joint_rids.is_empty():
		_project_source_anchors()
		if not is_instance_valid(_flat_floor):
			for name: String in bodies:
				var body: PhysicalBone3D = bodies[name]
				var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
				if state:
					_terrain_poses[name] = state.transform

func _project_source_anchors() -> void:
	var flat_floor := is_instance_valid(_flat_floor)
	for name: String in source_joint_rids:
		var spec: Dictionary = source_joints[name]
		var child: PhysicalBone3D = bodies[name]
		var parent: PhysicalBone3D = bodies[spec.parent]
		var state := PhysicsServer3D.body_get_direct_state(child.get_rid())
		var parent_state := PhysicsServer3D.body_get_direct_state(parent.get_rid())
		if state == null or parent_state == null:
			continue
		var parent_frame: Transform3D = parent_state.transform * spec.parent_frame
		var child_frame: Transform3D = state.transform * spec.child_frame
		# Godot's cone solver flips its swing axis past perpendicular. A limb
		# braced against terrain can wrench the anchor apart before that flip.
		var alignment := child_frame.basis.x.dot(parent_frame.basis.x)
		var overshot := alignment <= 0.0
		if not overshot and alignment < CONE_SUPPORT_OVERSHOOT_COS:
			for index in state.get_contact_count():
				if state.get_contact_local_normal(index).y > MIN_SUPPORT_NORMAL_Y:
					overshot = true
					break
		var bias := CONE_OVERSHOOT_BIAS if overshot else CONE_DEFAULT_BIAS
		PhysicsServer3D.cone_twist_joint_set_param(source_joint_rids[name], PhysicsServer3D.CONE_TWIST_JOINT_BIAS, bias)
		var contacting := state.get_contact_count() > 0
		if contacting and flat_floor:
			continue
		var correction := parent_frame.origin - child_frame.origin
		var distance := correction.length()
		if distance <= SOURCE_ANCHOR_TOLERANCE:
			continue
		# Leave the authored tolerance and preserve rotation and velocities.
		var motion := correction * (1.0 - SOURCE_ANCHOR_TOLERANCE / distance)
		var can_project_contact := not flat_floor and distance > 2.0 * SOURCE_ANCHOR_TOLERANCE
		if contacting:
			# Small errors on a supported limb stay with the contact solver.
			if can_project_contact:
				_project_contacting_anchor(child, state, motion.limit_length(CONTACT_ANCHOR_RECOVERY_MAX_SHIFT))
			continue
		if _test_projection_motion(child, state.transform, motion):
			var safe_fraction := _projection_hit.get_collision_safe_fraction()
			if is_zero_approx(safe_fraction) and can_project_contact:
				# Shape overlap can precede the next solver contact. Test the
				# current pose before treating the outward motion as blocked.
				_project_contacting_anchor(child, state,
					motion.limit_length(CONTACT_ANCHOR_RECOVERY_MAX_SHIFT), true)
				continue
			motion *= safe_fraction
		if not motion.is_zero_approx():
			state.transform = state.transform.translated(motion)

func _project_contacting_anchor(body: PhysicalBone3D, state: PhysicsDirectBodyState3D, motion: Vector3,
		require_overlap := false) -> void:
	var points := _terrain_contact_points(body, state, Vector3.ZERO)
	var escape_fraction := 0.0
	for i in range(0, points.size(), 2):
		var offset := points[i + 1] - points[i]
		var depth := offset.length()
		if depth > TERRAIN_DEEP_RESIDUAL:
			return
		if depth <= PROJECTION_COLLISION_MARGIN:
			continue
		var separation := motion.dot(offset / depth)
		if separation <= depth:
			return
		escape_fraction = maxf(escape_fraction, depth / separation)
	if require_overlap and escape_fraction <= 0.0:
		return
	if _deepest_contact(_terrain_contact_points(body, state, motion)) > PROJECTION_COLLISION_MARGIN:
		return
	# Sweep from the clear end because a forward sweep can stop inside the
	# original overlap. A hit near the original pose is the expected contact.
	var destination := state.transform.translated(motion)
	if _test_projection_motion(body, destination, -motion):
		var early_hit := 1.0 - _projection_hit.get_collision_unsafe_fraction() - escape_fraction
		if early_hit * motion.length() > 2.0 * PROJECTION_COLLISION_MARGIN:
			return
	state.transform = destination

func _test_projection_motion(body: PhysicalBone3D, start: Transform3D, motion: Vector3) -> bool:
	if _projection_query == null:
		_projection_query = PhysicsTestMotionParameters3D.new()
		_projection_query.margin = PROJECTION_COLLISION_MARGIN
		_projection_query.recovery_as_collision = true
		_projection_hit = PhysicsTestMotionResult3D.new()
	_projection_query.from = start
	_projection_query.motion = motion
	return PhysicsServer3D.body_test_motion(body.get_rid(), _projection_query, _projection_hit)

func _project_terrain_contact() -> void:
	var lift := 0.0
	var deepest: PhysicalBone3D
	var has_deep_contact := false
	var first_wall_parts: Array[String] = []
	var missed_wall: PhysicalBone3D
	var missed_rewind := Vector3.ZERO
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		var velocity := state.linear_velocity
		var fall_speed := -velocity.y
		# Godot's linear CCD slows individual parts on contact. Keep it for
		# horizontal travel and let the whole-body projection handle steep falls.
		var steep_fall := fall_speed > TERRAIN_MIN_FALL_SPEED and fall_speed > Vector2(velocity.x, velocity.z).length()
		PhysicsServer3D.body_set_enable_continuous_collision_detection(body.get_rid(), not steep_fall)
		var fast_contact := _can_have_fast_contact(state, part[2])
		if fall_speed <= TERRAIN_MIN_FALL_SPEED and not fast_contact:
			continue
		var can_rewind: bool = state.get_contact_count() == 0 and _terrain_poses.has(part[0])
		var points := _terrain_contact_points(body, state, Vector3.ZERO)
		if can_rewind and not steep_fall and points.is_empty():
			var rewind := _missed_wall_rewind(body, state, _terrain_poses[part[0]])
			if rewind.length_squared() > missed_rewind.length_squared():
				missed_wall = body
				missed_rewind = rewind
		for i in range(0, points.size(), 2):
			var offset := points[i + 1] - points[i]
			var depth := offset.length()
			has_deep_contact = has_deep_contact or depth > TERRAIN_DEEP_OVERLAP - PROJECTION_COLLISION_MARGIN
			if can_rewind and depth > TERRAIN_DEEP_OVERLAP and absf(offset.y) < depth * MIN_SUPPORT_NORMAL_Y:
				first_wall_parts.append(part[0])
				can_rewind = false
			if fall_speed <= TERRAIN_MIN_FALL_SPEED or offset.y < TERRAIN_MIN_OVERLAP or offset.y < depth * TERRAIN_MIN_SUPPORT_Y:
				continue
			# Keep contact for the next solve and bound the lift by one step of travel.
			var step_lift := minf((depth - TERRAIN_RESIDUAL_OVERLAP) * depth / offset.y, fall_speed * state.step)
			if step_lift > lift:
				lift = step_lift
				deepest = body
	if deepest != null:
		_try_terrain_translation(Vector3.UP * lift, deepest)
	if has_deep_contact:
		_project_deep_terrain_contact()
	if not first_wall_parts.is_empty():
		_project_unresolved_wall_contact(first_wall_parts)
	elif missed_wall != null and not has_deep_contact:
		_try_terrain_translation(missed_rewind, missed_wall, true)

func _project_unresolved_wall_contact(names: Array[String]) -> void:
	var deepest: PhysicalBone3D
	var deepest_depth := TERRAIN_DEEP_OVERLAP
	var correction := Vector3.ZERO
	for name in names:
		var body: PhysicalBone3D = bodies[name]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		var depth := _deepest_contact(_terrain_contact_points(body, state, Vector3.ZERO))
		if depth <= deepest_depth:
			continue
		var rewind := _first_wall_rewind(body, state, _terrain_poses[name].origin)
		if rewind.is_zero_approx():
			continue
		deepest = body
		deepest_depth = depth
		correction = rewind
	if deepest != null:
		_try_terrain_translation(correction, deepest)

func _missed_wall_rewind(body: PhysicalBone3D, state: PhysicsDirectBodyState3D, start: Transform3D) -> Vector3:
	var travel := state.transform.origin - start.origin
	var distance := travel.length()
	if distance <= TERRAIN_DEEP_OVERLAP + TERRAIN_RESIDUAL_OVERLAP:
		return Vector3.ZERO
	# A box can enter a one-sided cliff face and end the step with no reported overlap.
	var fraction := _wall_sweep_fraction(body, start, travel)
	var rewind := (1.0 - fraction) * distance - TERRAIN_RESIDUAL_OVERLAP
	if fraction <= 0.0 or rewind <= TERRAIN_DEEP_OVERLAP:
		return Vector3.ZERO
	return -travel * (minf(rewind, TERRAIN_MAX_RECOVERY_SHIFT) / distance)

func _first_wall_rewind(body: PhysicalBone3D, state: PhysicsDirectBodyState3D, previous_origin: Vector3) -> Vector3:
	var travel := state.transform.origin - previous_origin
	if travel.length_squared() <= TERRAIN_DEEP_OVERLAP * TERRAIN_DEEP_OVERLAP:
		return Vector3.ZERO
	# Sweep the full box along the last step when the engine's CCD missed the edge.
	var start := Transform3D(state.transform.basis, previous_origin)
	if _deepest_contact(_terrain_contacts_at(body, state.get_space_state(), start)) > FLOOR_CONTACT_SLOP:
		return Vector3.ZERO
	var remaining := travel * (1.0 - _wall_sweep_fraction(body, start, travel))
	var rewind := maxf(0.0, remaining.length() - TERRAIN_RESIDUAL_OVERLAP)
	return -travel.normalized() * minf(rewind, TERRAIN_MAX_RECOVERY_SHIFT)

func _wall_sweep_fraction(body: PhysicalBone3D, start: Transform3D, travel: Vector3) -> float:
	if not _test_projection_motion(body, start, travel):
		return 1.0
	var normal := _projection_hit.get_collision_normal()
	if absf(normal.y) >= MIN_SUPPORT_NORMAL_Y or travel.dot(normal) >= 0.0:
		return 1.0
	return _projection_hit.get_collision_unsafe_fraction()

func _can_have_fast_contact(state: PhysicsDirectBodyState3D, box_size: Vector3) -> bool:
	var half_diagonal := (box_size * 0.5).length()
	return state.linear_velocity.length() + state.angular_velocity.length() * half_diagonal > TERRAIN_MIN_FALL_SPEED

func _project_deep_terrain_contact() -> void:
	var worst_depth := TERRAIN_DEEP_OVERLAP
	var motion := Vector3.ZERO
	var deepest: PhysicalBone3D
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null or not _can_have_fast_contact(state, part[2]):
			continue
		var points := _terrain_contact_points(body, state, Vector3.ZERO)
		for i in range(0, points.size(), 2):
			var offset := points[i + 1] - points[i]
			var depth := offset.length()
			if depth <= worst_depth:
				continue
			var normal := offset / depth
			if normal.y < -0.05:
				continue
			# The contact point can still move inward while the body's center slows.
			var radius := points[i] - state.transform.origin - state.center_of_mass
			var point_velocity := state.linear_velocity + state.angular_velocity.cross(radius)
			var approach := -point_velocity.dot(normal)
			var direction := Vector3.UP if normal.y >= TERRAIN_MIN_SUPPORT_Y else normal
			var separation := minf(depth - TERRAIN_DEEP_RESIDUAL, approach * state.step) / direction.dot(normal)
			if separation < FLOOR_CONTACT_SLOP:
				continue
			worst_depth = depth
			deepest = body
			motion = direction * minf(separation, TERRAIN_MAX_RECOVERY_SHIFT)
	if deepest != null:
		_try_terrain_translation(motion, deepest)

func _try_terrain_translation(motion: Vector3, deepest: PhysicalBone3D, crossed_wall := false) -> void:
	for body: PhysicalBone3D in bodies.values():
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			return
		var before := _deepest_contact(_terrain_contact_points(body, state, Vector3.ZERO))
		var after := _deepest_contact(_terrain_contact_points(body, state, motion))
		# Reject a shift into an adjacent ledge or one that leaves the worst contact unchanged.
		if crossed_wall and body == deepest:
			# Leave a shallow contact on the entry face for the next solve.
			if before > FLOOR_CONTACT_SLOP or after <= FLOOR_CONTACT_SLOP or after > TERRAIN_DEEP_RESIDUAL:
				return
		elif after > maxf(before, FLOOR_CONTACT_SLOP) + PROJECTION_COLLISION_MARGIN \
				or (body == deepest and after >= before - FLOOR_CONTACT_SLOP):
			return
	for body: PhysicalBone3D in bodies.values():
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		state.transform = state.transform.translated(motion)

func _terrain_contact_points(body: PhysicalBone3D, state: PhysicsDirectBodyState3D, motion: Vector3) -> Array[Vector3]:
	return _terrain_contacts_at(body, state.get_space_state(), state.transform.translated(motion))

func _terrain_contacts_at(body: PhysicalBone3D, space: PhysicsDirectSpaceState3D, pose: Transform3D) -> Array[Vector3]:
	if _terrain_query == null:
		_terrain_query = PhysicsShapeQueryParameters3D.new()
	var collider := body.get_child(0) as CollisionShape3D
	_terrain_query.collision_mask = body.collision_mask
	_terrain_query.shape = collider.shape
	_terrain_query.transform = pose * collider.transform
	return space.collide_shape(_terrain_query, 16)

func _deepest_contact(points: Array[Vector3]) -> float:
	var deepest := 0.0
	for i in range(0, points.size(), 2):
		deepest = maxf(deepest, points[i].distance_to(points[i + 1]))
	return deepest

func _project_floor_contact() -> void:
	var floor_box := _flat_floor.shape as BoxShape3D
	var floor_pose := _flat_floor.global_transform
	if floor_box == null or not floor_pose.basis.y.is_equal_approx(Vector3.UP) \
			or not floor_pose.basis.get_scale().is_equal_approx(Vector3.ONE):
		return
	var floor_half := floor_box.size * 0.5
	var floor_inverse := floor_pose.affine_inverse()
	var lift := 0.0
	var landing_blended := not source_joint_rids.is_empty() and is_equal_approx(bodies.Head.gravity_scale, 1.0)
	if _split_floor_impact and not _flat_floor_has_contact:
		var floor_body := _flat_floor.get_parent()
		for body: PhysicalBone3D in bodies.values():
			if _body_supported_by(body, floor_body):
				_flat_floor_has_contact = true
				break
	var min_depth := FLOOR_REST_SLOP if landing_blended else FLOOR_CONTACT_SLOP
	var depths: Dictionary[PhysicalBone3D, float] = {}
	var slow := true
	for part in _parts:
		var body: PhysicalBone3D = bodies[part[0]]
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		slow = slow and state.linear_velocity.length_squared() < 0.6 * 0.6 \
			and state.angular_velocity.length_squared() < 2.0 * 2.0
		var pose := floor_inverse * state.transform
		var half: Vector3 = part[2] * 0.5
		var extent_y := Vector3(absf(pose.basis.x.y), absf(pose.basis.y.y), absf(pose.basis.z.y)).dot(half)
		var depth := floor_half.y - (pose.origin.y - extent_y)
		if depth <= min_depth or pose.origin.y + extent_y < -floor_half.y:
			continue
		# The finite platform only supports boxes whose footprints fit on it.
		var extent_x := Vector3(absf(pose.basis.x.x), absf(pose.basis.y.x), absf(pose.basis.z.x)).dot(half)
		var extent_z := Vector3(absf(pose.basis.x.z), absf(pose.basis.y.z), absf(pose.basis.z.z)).dot(half)
		if absf(pose.origin.x) + extent_x <= floor_half.x and absf(pose.origin.z) + extent_z <= floor_half.z:
			lift = maxf(lift, depth)
			if landing_blended or _flat_floor_has_contact:
				depths[body] = depth
	# The tighter flight clearance can repeatedly lift grounded limbs out of
	# contact. Keep the resting tolerance through small solver velocity spikes.
	var slop := FLOOR_REST_SLOP if slow or landing_blended else FLOOR_CONTACT_SLOP
	lift -= slop
	if lift <= 0.0:
		return
	var shared_lift := 0.0 if landing_blended else lift
	if not landing_blended and _flat_floor_has_contact:
		# Once Sabre's throw meets the floor, leave part of a large correction
		# with the penetrating limb so it does not kick the whole body upward.
		shared_lift -= maxf(0.0, lift - FLOOR_SHARED_LIFT_THRESHOLD) * FLOOR_EXCESS_LIFT_PART_SHARE
	for body: PhysicalBone3D in bodies.values():
		var correction := maxf(shared_lift, depths.get(body, 0.0) - slop)
		if correction <= 0.0:
			continue
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state:
			state.transform = state.transform.translated(Vector3.UP * correction)

func contact_motion() -> Dictionary:
	var contacts := 0
	var core_contacts := 0
	var supports := 0
	var core_supports := 0
	var leg_supports := 0
	var core_support_sum := Vector3.ZERO
	var leg_support_sum := Vector3.ZERO
	var peak_linear := 0.0
	var peak_angular := 0.0
	for name in bodies:
		var body: PhysicalBone3D = bodies[name]
		var direct := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if direct and direct.get_contact_count() > 0:
			contacts += 1
			var is_core: bool = name in ["Hips", "Chest", "Head"]
			var is_leg: bool = name in ["Leg.L", "Leg.R"]
			if is_core: core_contacts += 1
			for index in direct.get_contact_count():
				# The contact normal is reported in world axes by the lab backend.
				if direct.get_contact_local_normal(index).y < MIN_SUPPORT_NORMAL_Y:
					continue
				supports += 1
				if is_core:
					core_supports += 1
					core_support_sum += direct.get_contact_collider_position(index)
				if is_leg:
					leg_supports += 1
					leg_support_sum += direct.get_contact_collider_position(index)
				break
		peak_linear = maxf(peak_linear,body.linear_velocity.length())
		peak_angular = maxf(peak_angular,body.angular_velocity.length())
	var support_span := Vector3.ZERO
	if core_supports > 0 and leg_supports > 0:
		support_span = core_support_sum / core_supports - leg_support_sum / leg_supports
	return {"contacts":contacts,"core_contacts":core_contacts,"supports":supports,
		"core_supports":core_supports,"leg_supported":leg_supports > 0,"support_span":support_span,
		"linear":peak_linear,"angular":peak_angular}

func is_braced_against_terrain() -> bool:
	return terrain_support_margin(true) < 0.0

func terrain_support_margin(require_wall := false) -> float:
	var has_wall_contact := false
	var support_points := PackedVector2Array()
	var weighted_center := Vector3.ZERO
	var mass := 0.0
	for body: PhysicalBone3D in bodies.values():
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state == null:
			return NAN
		weighted_center += (state.transform.origin + state.center_of_mass) * body.mass
		mass += body.mass
		for index in state.get_contact_count():
			if not state.get_contact_collider_object(index) is StaticBody3D:
				continue
			var normal_y := state.get_contact_local_normal(index).y
			has_wall_contact = has_wall_contact or absf(normal_y) < MAX_WALL_NORMAL_Y
			if normal_y >= MIN_SUPPORT_NORMAL_Y:
				var point := state.get_contact_collider_position(index)
				support_points.append(Vector2(point.x, point.z))
	if (require_wall and not has_wall_contact) or support_points.is_empty():
		return NAN
	var footprint := Geometry2D.convex_hull(support_points)
	if footprint.size() < 4:
		return -INF
	var center := Vector2(weighted_center.x, weighted_center.z) / mass
	if not Geometry2D.is_point_in_polygon(center, footprint):
		return -INF
	var margin := INF
	for edge in range(footprint.size() - 1):
		var nearest := Geometry2D.get_closest_point_to_segment(center, footprint[edge], footprint[edge + 1])
		margin = minf(margin, center.distance_to(nearest))
	return margin

func has_flat_limb_support() -> bool:
	if not is_instance_valid(_flat_floor) or _flat_floor.disabled:
		return false
	var floor_body := _flat_floor.get_parent()
	return _body_supported_by(bodies["Leg.L"], floor_body) and _body_supported_by(bodies["Leg.R"], floor_body) \
		and (_body_supported_by(bodies["Arm.L"], floor_body) or _body_supported_by(bodies["Arm.R"], floor_body))

static func _body_supported_by(body: PhysicalBone3D, floor_body: Node) -> bool:
	var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state == null:
		return false
	for index in state.get_contact_count():
		if state.get_contact_local_normal(index).y >= MIN_SUPPORT_NORMAL_Y \
				and state.get_contact_collider_object(index) == floor_body:
			return true
	return false

func release(visible_world_pose: Array[Transform3D] = []) -> void:
	# Called outside the physics integration callback. Free native joints/bodies,
	# not just collisions/sleep flags. Optionally retain the final visible pose.
	var pose: Array[Transform3D] = []
	# Modifier poses are temporary: read the skeleton_updated cache, not the
	# reverted animation pose returned during _process.
	for world_pose in visible_world_pose: pose.append(skeleton.global_transform.affine_inverse()*world_pose)
	set_physics_process(false)
	running = false
	for joint: RID in source_joint_rids.values():
		PhysicsServer3D.free_rid(joint)
	source_joint_rids.clear()
	if is_instance_valid(simulator):
		simulator.physical_bones_stop_simulation()
		simulator.active = false
		simulator.free()
	simulator = null
	bodies.clear()
	_terrain_poses.clear()
	anchors.clear()
	joint_rest_rotations.clear()
	if not pose.is_empty():
		# Native physical bones have stopped writing. Restore final global poses in
		# parent-first order, including utility bones, without an AnimationPlayer RESET.
		for i in pose.size(): skeleton.set_bone_global_pose(i,pose[i])
