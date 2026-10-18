extends Node
## Native skeletal adapter. No transform writers or scripted falling once handed off.
const PHYSICAL_PART = preload("res://scenes/dev/zombie_death_physics/physical_part.gd")
const PARTS := [
	# name, Skeleton Y-up rest center, inset box, kg, bend°, twist°
	["Hips", Vector3(0, 0.765, 0), Vector3(0.36, 0.18, 0.16), 8.0, 0.0, 0.0],
	["Chest", Vector3(0, 1.0125, 0), Vector3(0.43, 0.655, 0.205), 22.0, 12.0, 10.0],
	["Head", Vector3(0, 1.575, 0), Vector3(0.43, 0.43, 0.43), 8.0, 25.0, 25.0],
	["Arm.L", Vector3(0.3375, 1.0125, 0), Vector3(0.205, 0.655, 0.205), 4.0, 70.0, 35.0],
	["Arm.R", Vector3(-0.3375, 1.0125, 0), Vector3(0.205, 0.655, 0.205), 4.0, 70.0, 35.0],
	["Leg.L", Vector3(0.1125, 0.3375, 0), Vector3(0.205, 0.655, 0.205), 7.0, 45.0, 25.0],
	["Leg.R", Vector3(-0.1125, 0.3375, 0), Vector3(0.205, 0.655, 0.205), 7.0, 45.0, 25.0],
]
const PARENTS := {"Chest": "Hips", "Head": "Chest", "Arm.L": "Chest", "Arm.R": "Chest", "Leg.L": "Hips", "Leg.R": "Hips"}
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

func setup(target: Skeleton3D) -> void:
	skeleton = target
	# Reject unsupported rigs instead of quietly binding the wrong bones/scale.
	assert(skeleton.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Ragdoll requires unit-scale hierarchy")
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "DeathPhysicsSimulator"
	skeleton.add_child(simulator)
	simulator.active = false
	for part in PARTS:
		var id := skeleton.find_bone(part[0])
		assert(id >= 0, "Missing original Zombie bone: " + part[0])
		var body := PhysicalBone3D.new()
		body.set_script(PHYSICAL_PART)
		body.name = "Corpse_" + part[0]
		body.set("bone_name", part[0])
		body.body_offset = skeleton.get_bone_global_rest(id).affine_inverse() * Transform3D(Basis.IDENTITY, part[1])
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
		collider.shape = shape
		body.add_child(collider)
		simulator.add_child(body)
		PhysicsServer3D.body_set_enable_continuous_collision_detection(body.get_rid(), true)
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

func begin(profile: Resource, direction: Vector3, location: String, distance: float, gravity: float) -> bool:
	if running or sample_count < 2: return false
	running = true
	simulator.active = true
	# This refreshes all cached animated poses, sets all body transforms and changes mode.
	simulator.physical_bones_start_simulation()
	for part in PARTS:
		var body: PhysicalBone3D = bodies[part[0]]
		handoff_error = maxf(handoff_error, body.global_position.distance_to(current[part[0]].origin))
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
	# Rebuild frames only AFTER every body has the current pose. Native parent frame
	# is computed from this exact pose, accommodating animated bone translations.
	# Limits are relative to the captured pose; no rest-pose projection/correction.
	for part in PARTS:
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
	apply_impact(profile, direction, location, distance)
	return true

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
		impact_distribution[target.name] = total
	var axis := Vector3.UP.cross(dir).normalized()
	if axis.is_zero_approx(): axis = Vector3.RIGHT
	# A bounded whole-pattern art control, not an extra impulse per pellet.
	var torque: Vector3 = (axis + Vector3.UP * (-side * 2.0)).normalized() * profile.angular_impulse * last_strength
	PhysicsServer3D.body_apply_torque_impulse(target.get_rid(), torque)

func nearest_part(world_point: Vector3) -> PhysicalBone3D:
	var nearest: PhysicalBone3D = bodies.Chest
	var best := INF
	for part in PARTS:
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
	for name in anchors:
		var child: PhysicalBone3D = bodies[name]
		var parent: PhysicalBone3D = bodies[PARENTS[name]]
		result = maxf(result, (parent.global_transform * anchors[name]).origin.distance_to((child.global_transform * child.joint_offset).origin))
	return result

func minimum_corner_y() -> float:
	var result := INF
	for part in PARTS:
		var body: PhysicalBone3D = bodies[part[0]]
		var half: Vector3 = part[2] * 0.5
		for x in [-1, 1]:
			for y in [-1, 1]:
				for z in [-1, 1]:
					result = minf(result, (body.global_transform * (half * Vector3(x,y,z))).y)
	return result
