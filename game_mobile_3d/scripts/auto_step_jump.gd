extends RefCounted
## Grounded obstacle probe and actual-floor lifecycle. No pose or position writer.
var active := false
var _drop_pending := false
var _floor_y := 0.0
var _grounded_frames := 0
var _has_last_position := false
var _last_position := Vector3.ZERO
var _enabled := true

func reset() -> void:
	active = false
	_drop_pending = false
	_grounded_frames = 0
	_has_last_position = false

func before_move(body: CharacterBody3D, direction: Vector3, delta: float, gravity: float, enabled: bool, minimum: float, maximum: float, clearance: float, target_speed: float) -> float:
	_enabled = enabled
	if not enabled:
		reset()
		return 0.0
	# Existing level resets reposition the body directly; cancel the old lifecycle.
	if _has_last_position and body.global_position.distance_to(_last_position) > maxf(0.5, body.velocity.length() * delta * 3.0):
		reset()
	if body.is_on_floor():
		_grounded_frames += 1
		_floor_y = body.global_position.y
	else:
		_grounded_frames = 0
	if not enabled or active or _grounded_frames < 2 or direction.is_zero_approx() or gravity <= 0.0:
		return 0.0
	# Input gates intent; acceleration can still carry the capsule in its old
	# heading during a turn. Only probe the path it is physically following.
	var movement := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if movement.is_zero_approx(): return 0.0
	var rise := _probe(body, movement.normalized(), delta, gravity, minimum, maximum, maxf(clearance, 0.04), target_speed)
	if rise > 0.0:
		active = true
		_drop_pending = false
	return rise

func after_move(body: CharacterBody3D, was_grounded: bool) -> int:
	# 1 = confirmed descent, 2 = actual floor return, 0 = no event.
	var event := 0
	if not _enabled:
		_last_position = body.global_position
		_has_last_position = true
		return 0
	if active and body.is_on_floor():
		active = false
		_drop_pending = false
		event = 2
	elif not active:
		if was_grounded and _grounded_frames >= 2 and not body.is_on_floor(): _drop_pending = true
		if _drop_pending:
			if body.is_on_floor():
				_drop_pending = false
			elif body.velocity.y < -0.05 and body.global_position.y < _floor_y - 0.04:
				active = true
				_drop_pending = false
				event = 1
	_last_position = body.global_position
	_has_last_position = true
	return event

func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return space.intersect_ray(query)

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
	for offset in [Vector3.ZERO, direction * radius, -direction * radius, side * radius, -side * radius]:
		var support := _ray(space, point + offset + Vector3.UP * 0.06, point + offset - Vector3.UP * 0.06, mask, exclude)
		if support.is_empty() or support.normal.y < minimum_normal_y or absf(support.position.y - point.y) > 0.04:
			return false
	return true

func _probe(body: CharacterBody3D, direction: Vector3, delta: float, gravity: float, minimum: float, maximum: float, clearance: float, target_speed: float) -> float:
	var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or collision.disabled or maximum < minimum: return 0.0
	var capsule := collision.shape as CapsuleShape3D
	if capsule == null: return 0.0
	var space := body.get_world_3d().direct_space_state
	# Only static world layer is climbable; enemies on layer 4 are never steps.
	var mask := body.collision_mask & 1
	var exclude: Array[RID] = [body.get_rid()]
	var feet := collision.global_position - Vector3.UP * capsule.height * 0.5
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	if speed < 0.05 or mask == 0: return 0.0
	var maximum_impulse := sqrt(2.0 * gravity * (maximum + clearance))
	var rise_time := (maximum_impulse - sqrt(2.0 * gravity * clearance)) / gravity
	var reach := capsule.radius + speed * rise_time + 0.08
	var low := feet + Vector3.UP * maxf(0.04, minimum * 0.5)
	var front := _ray(space, low, low + direction * reach, mask, exclude)
	if front.is_empty() or absf(front.normal.y) > 0.2 or front.normal.dot(direction) > -0.25: return 0.0
	var landing: Vector3 = front.position + direction * (capsule.radius + 0.06)
	var top := _ray(space, Vector3(landing.x, feet.y + maximum + 0.04, landing.z), Vector3(landing.x, feet.y + minimum - 0.01, landing.z), mask, exclude)
	if top.is_empty() or top.normal.y < cos(body.floor_max_angle): return 0.0
	var rise: float = top.position.y - feet.y
	# CharacterBody's safe floor margin can leave the feet a fraction above the top.
	if rise < minimum - 0.002 or rise > maximum: return 0.0
	var impulse := sqrt(2.0 * gravity * (rise + clearance))
	var time_to_top := (impulse - sqrt(2.0 * gravity * clearance)) / gravity
	if feet.distance_to(Vector3(front.position.x, feet.y, front.position.z)) > capsule.radius + speed * time_to_top + 0.08:
		return 0.0
	landing.y = top.position.y
	# A full capsule footprint must fit, including its trailing edge and both sides.
	var radius := capsule.radius + 0.025
	if not _supported(space, landing, direction, radius, cos(body.floor_max_angle), mask, exclude): return 0.0
	# Keep input-driven horizontal motion: the top must also support its predicted
	# contact footprint. A short slab can fit the first footprint yet be overshot.
	var effective_impulse := impulse + gravity * delta * 0.5
	var contact_time := (effective_impulse + sqrt(maxf(0.0, effective_impulse * effective_impulse - 2.0 * gravity * rise))) / gravity
	var contact := feet + direction * maxf(speed, target_speed) * contact_time
	contact.y = landing.y
	if not _supported(space, contact, direction, radius, cos(body.floor_max_angle), mask, exclude): return 0.0
	var start := collision.global_transform
	start.origin += Vector3.UP * 0.025
	var lift := rise + clearance
	if not _clear_sweep(space, capsule, start, Vector3.UP * lift, mask, exclude): return 0.0
	var high := collision.global_transform
	high.origin += Vector3.UP * lift
	var across := Vector3(landing.x - feet.x, 0.0, landing.z - feet.z)
	if not _clear_sweep(space, capsule, high, across, mask, exclude): return 0.0
	# The empty vertical/apex sweeps alone miss a low obstruction between them.
	# Sweep the actual rising corridor too; each chord is conservatively below it.
	var previous := start
	var travel_time := across.length() / speed
	for index in range(1, 7):
		var time := travel_time * float(index) / 6.0
		var next := collision.global_transform
		next.origin += direction * speed * time + Vector3.UP * (impulse * time - 0.5 * gravity * time * time + 0.025)
		if not _clear_sweep(space, capsule, previous, next.origin - previous.origin, mask, exclude): return 0.0
		previous = next
	var finish := collision.global_transform
	finish.origin += landing - feet + Vector3.UP * 0.025
	if not _clear_sweep(space, capsule, finish, Vector3.ZERO, mask, exclude): return 0.0
	finish.origin += contact - landing
	if not _clear_sweep(space, capsule, finish, Vector3.ZERO, mask, exclude): return 0.0
	return rise
