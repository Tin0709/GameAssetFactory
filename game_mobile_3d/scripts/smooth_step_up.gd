extends RefCounted
## Collision-probed, controlled ascent. Never writes the root transform or a pose.
var active := false
var _elapsed := 0.0
var _duration := 0.32
var _start_y := 0.0
var _target_y := 0.0
var _entry_direction := Vector3.ZERO
var _front_normal := Vector3.ZERO
var _front_point := Vector3.ZERO
var _support_y := 0.0
var _capsule_radius := 0.3
var _grounded_frames := 0
var _has_last_position := false
var _last_position := Vector3.ZERO

func reset() -> void:
	active = false
	_elapsed = 0.0
	_grounded_frames = 0
	_has_last_position = false

func _cancel(body: CharacterBody3D) -> void:
	if active: body.velocity.y = minf(0.0, body.velocity.y)
	reset()

func before_move(body: CharacterBody3D, intent: Vector3, delta: float, enabled: bool, minimum: float, maximum: float, duration: float) -> bool:
	if _has_last_position and body.global_position.distance_to(_last_position) > maxf(0.5, body.velocity.length() * delta * 3.0):
		_cancel(body)
	if not enabled or intent.is_zero_approx():
		_cancel(body)
		return false
	# The landing corridor was validated for entry direction. A substantial turn
	# ends that ascent immediately instead of lifting over an unvalidated edge.
	if active and intent.normalized().dot(_entry_direction) < 0.9:
		_cancel(body)
		return false
	if active and _elapsed > _duration + 0.5:
		_cancel(body)
		return false
	if body.is_on_floor(): _grounded_frames += 1
	else: _grounded_frames = 0
	if not active:
		if _grounded_frames < 2: return false
		var movement := Vector3(body.velocity.x, 0.0, body.velocity.z)
		if movement.length() < 0.05: return false
		var rise := _probe(body, movement.normalized(), delta, minimum, maximum)
		if rise <= 0.0: return false
		active = true
		_elapsed = 0.0
		_start_y = body.global_position.y
		_target_y = _start_y + rise
		_entry_direction = movement.normalized()
		_duration = clampf(duration, 0.16, 0.6)
	if not _still_supported(body):
		_cancel(body)
		return false
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var desired_y := lerpf(_start_y, _target_y, smoothstep(0.0, 1.0, progress))
	var maximum_speed := (_target_y - _start_y) * 1.5 / _duration
	body.velocity.y = clampf((desired_y - body.global_position.y) / maxf(delta, 0.001), 0.0, maximum_speed)
	return true

func after_move(body: CharacterBody3D) -> void:
	if active and body.is_on_floor() and body.global_position.y >= _target_y - 0.02:
		reset()
	_last_position = body.global_position
	_has_last_position = true

func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array[RID]) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask, exclude))

func _clear_sweep(space: PhysicsDirectSpaceState3D, shape: Shape3D, transform: Transform3D, motion: Vector3, mask: int, exclude: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.motion = motion
	query.collision_mask = mask
	query.exclude = exclude
	query.margin = 0.001
	if not space.intersect_shape(query, 1).is_empty(): return false
	if motion.is_zero_approx(): return true
	var fraction := space.cast_motion(query)
	return fraction.size() == 2 and fraction[0] >= 0.999

func _supported(space: PhysicsDirectSpaceState3D, point: Vector3, direction: Vector3, radius: float, minimum_normal_y: float, mask: int, exclude: Array[RID]) -> bool:
	var side := Vector3(-direction.z, 0.0, direction.x)
	var offsets: Array[Vector3] = [Vector3.ZERO]
	for index in 8:
		var angle := float(index) * TAU / 8.0
		offsets.append((direction * cos(angle) + side * sin(angle)) * (radius + 0.025))
	for offset in offsets:
		var sample := point + offset
		var support := _ray(space, sample + Vector3.UP * 0.06, sample - Vector3.UP * 0.06, mask, exclude)
		if support.is_empty() or support.normal.y < minimum_normal_y or absf(support.position.y - point.y) > 0.04:
			return false
	return true

func _still_supported(body: CharacterBody3D) -> bool:
	# Revalidate the footprint directly above the current XZ position. While the
	# body is outside the face, project it just far enough into the accepted top.
	# This detects small analog steering and glancing drift before continuing rise.
	var candidate := Vector3(body.global_position.x, _support_y, body.global_position.z)
	var signed_distance := (candidate - _front_point).dot(_front_normal)
	var inset := _capsule_radius + 0.06
	if signed_distance > -inset: candidate -= _front_normal * (signed_distance + inset)
	var exclude: Array[RID] = [body.get_rid()]
	return _supported(body.get_world_3d().direct_space_state, candidate, _entry_direction, _capsule_radius, cos(body.floor_max_angle), body.collision_mask & 1, exclude)

func _probe(body: CharacterBody3D, direction: Vector3, delta: float, minimum: float, maximum: float) -> float:
	var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or collision.disabled or maximum < minimum: return 0.0
	var capsule := collision.shape as CapsuleShape3D
	if capsule == null: return 0.0
	var space := body.get_world_3d().direct_space_state
	var mask := body.collision_mask & 1 # Static world only; enemies are not steps.
	var exclude: Array[RID] = [body.get_rid()]
	var feet := collision.global_position - Vector3.UP * capsule.height * 0.5
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	# A center ray needs a longer reach on diagonal/glancing approaches. Gate the
	# result by distance to its plane so this never starts a climb at a distance.
	var reach := capsule.radius / 0.25 + speed * delta + 0.08
	var low := feet + Vector3.UP * maxf(0.04, minimum * 0.5)
	var front := _ray(space, low, low + direction * reach, mask, exclude)
	if front.is_empty() or absf(front.normal.y) > 0.2 or front.normal.dot(direction) > -0.25: return 0.0
	var approach: float = -front.normal.dot(direction)
	var distance_to_plane: float = absf((front.position - low).dot(front.normal))
	if distance_to_plane > capsule.radius + speed * delta * approach + 0.08: return 0.0
	var landing: Vector3 = front.position - front.normal * (capsule.radius + 0.06)
	var top := _ray(space, Vector3(landing.x, feet.y + maximum + 0.04, landing.z), Vector3(landing.x, feet.y + minimum - 0.01, landing.z), mask, exclude)
	if top.is_empty() or top.normal.y < cos(body.floor_max_angle): return 0.0
	var rise: float = top.position.y - feet.y
	if rise < minimum - 0.002 or rise > maximum: return 0.0
	landing.y = top.position.y
	if not _supported(space, landing, direction, capsule.radius, cos(body.floor_max_angle), mask, exclude): return 0.0
	# Full capsule headroom in the current rise and across the top. A tiny backward
	# query offset avoids treating existing wall contact as headroom obstruction.
	var start := collision.global_transform
	start.origin += Vector3.UP * 0.025 - direction * 0.003
	if not _clear_sweep(space, capsule, start, Vector3.UP * rise, mask, exclude): return 0.0
	var high := collision.global_transform
	high.origin += Vector3.UP * (rise + 0.025)
	var across := Vector3(landing.x - feet.x, 0.0, landing.z - feet.z)
	if not _clear_sweep(space, capsule, high, across, mask, exclude): return 0.0
	var finish := collision.global_transform
	finish.origin += landing - feet + Vector3.UP * 0.025
	if not _clear_sweep(space, capsule, finish, Vector3.ZERO, mask, exclude): return 0.0
	_front_normal = Vector3(front.normal.x, 0.0, front.normal.z).normalized()
	_front_point = front.position
	_support_y = landing.y
	_capsule_radius = capsule.radius
	return rise
