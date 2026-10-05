extends "res://scripts/cuboid_animation.gd"
## Manual library sample + three cheap springs; death uses rigid pose interpolation.
const Spring = preload("res://scripts/secondary_spring.gd")
const RigidCache = preload("res://scripts/zombie_rigid_cache.gd")
@export var bounce_tuning: Resource = preload("res://materials/BounceTuning.tres")
var bounce_enabled := true
var skeleton: Skeleton3D
var body_spring := Spring.new()
var shoulder_spring := Spring.new()
var head_spring := Spring.new()
var base_positions: Array[Vector3] = []
var base_rotations: Array[Quaternion] = []
var last_phase := -1.0
var contact_count := 0
var hips: int
var chest: int
var head: int
var arm_left: int
var arm_right: int
var leg_left: int
var leg_right: int
var root_bone: int
signal death_finished
var dying := false
var secondary_frozen := false
var death_time := 0.0
var death_fall_duration := 0.62
var death_variant := 0
var death_direction := Vector3.BACK
var death_targets: Array[Quaternion] = []
var death_root_start := Transform3D.IDENTITY
var ground_bounce_count := 0
var bound_bones := PackedInt32Array()
var bound_corners: Array[Vector3] = []

func _ready() -> void:
	super._ready()
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	hips = skeleton.find_bone("Hips")
	chest = skeleton.find_bone("Chest")
	head = skeleton.find_bone("Head")
	arm_left = skeleton.find_bone("Arm.L")
	arm_right = skeleton.find_bone("Arm.R")
	leg_left = skeleton.find_bone("Leg.L")
	leg_right = skeleton.find_bone("Leg.R")
	root_bone = skeleton.find_bone("Root")
	for bone in skeleton.get_bone_count():
		base_positions.append(skeleton.get_bone_pose_position(bone))
		base_rotations.append(skeleton.get_bone_pose_rotation(bone))
	_cache_bounds()

func _capture_base() -> void:
	for bone in skeleton.get_bone_count():
		base_positions[bone] = skeleton.get_bone_pose_position(bone)
		base_rotations[bone] = skeleton.get_bone_pose_rotation(bone)

func _restore_base() -> void:
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(bone, base_positions[bone])
		skeleton.set_bone_pose_rotation(bone, base_rotations[bone])

func _process(delta: float) -> void:
	super._process(delta)
	if skeleton == null: return
	if secondary_frozen: return
	if dying:
		death_time += delta
		_evaluate_death()
		if death_time >= death_fall_duration + bounce_tuning.corpse_hold:
			set_process(false)
			death_finished.emit()
		return
	_restore_base()
	animation_player.advance(delta)
	_capture_base()
	if not bounce_enabled: return
	var phase := animation_player.current_animation_position / maxf(0.01, animation_player.current_animation_length)
	if current_state == &"Walk" and animation_player.is_playing():
		if last_phase >= 0.0:
			var travel := fposmod(phase - last_phase, 1.0)
			var contacts := Spring.contacts_crossed(last_phase, travel, bounce_tuning.contact_phase)
			if contacts > 0:
				contact_count += contacts
				var variation := lerpf(0.90, 1.10, phase_offset)
				body_spring.kick(Vector3(-bounce_tuning.zombie_contact_impulse * variation, 0, 0), bounce_tuning.max_velocity)
		last_phase = phase
	else: last_phase = -1.0
	var limits := Vector3(bounce_tuning.zombie_max_drop, bounce_tuning.zombie_max_angle, bounce_tuning.zombie_max_angle)
	var frequency: float = bounce_tuning.zombie_frequency * rate_variation
	var damping: float = bounce_tuning.zombie_damping + phase_offset * 0.08
	body_spring.advance(delta, Vector3.ZERO, frequency, damping, limits)
	shoulder_spring.advance(delta, body_spring.value, frequency * 1.12, damping, limits)
	head_spring.advance(delta, shoulder_spring.value * 0.6, frequency * 1.35, damping + 0.08, limits)
	var gain: float = bounce_tuning.bounce_strength
	var drop: float = body_spring.value.x * gain
	skeleton.set_bone_pose_position(hips, base_positions[hips] + Vector3.UP * drop)
	for leg in [leg_left, leg_right]:
		var parent_basis := skeleton.get_bone_global_pose(skeleton.get_bone_parent(leg)).basis
		skeleton.set_bone_pose_position(leg, base_positions[leg] + parent_basis.inverse() * Vector3.DOWN * drop)
	skeleton.set_bone_pose_position(chest, base_positions[chest] + Vector3.UP * (shoulder_spring.value.x - body_spring.value.x) * gain * bounce_tuning.zombie_shoulder_follow)
	skeleton.set_bone_pose_position(head, base_positions[head] + Vector3.UP * (head_spring.value.x - shoulder_spring.value.x) * gain * bounce_tuning.zombie_head_follow)
	_rotate(chest, Vector3(shoulder_spring.value.y, shoulder_spring.value.z, 0) * gain)
	_rotate(head, Vector3(head_spring.value.y - shoulder_spring.value.y, 0, head_spring.value.z * 0.6) * gain)
	var arm_lag := (head_spring.value - shoulder_spring.value) * gain
	_rotate(arm_left, Vector3(arm_lag.y + arm_lag.x, 0, arm_lag.z))
	_rotate(arm_right, Vector3(arm_lag.y + arm_lag.x, 0, -arm_lag.z * 0.8))

func _rotate(bone: int, euler: Vector3) -> void:
	skeleton.set_bone_pose_rotation(bone, (skeleton.get_bone_pose_rotation(bone) * Quaternion.from_euler(euler)).normalized())

func hit_impulse(world_direction: Vector3) -> void:
	if dying or not bounce_enabled: return
	var local := global_basis.inverse() * world_direction.normalized()
	if local.is_zero_approx(): local = Vector3.BACK
	body_spring.kick(Vector3(-bounce_tuning.zombie_hit_impulse * 0.15, local.z * bounce_tuning.zombie_hit_impulse, -local.x * bounce_tuning.zombie_hit_impulse), bounce_tuning.max_velocity)

func start_death(world_direction: Vector3, fall_duration: float) -> void:
	# Capture the actual final additive hit/walk pose once; no competing writer.
	_capture_base()
	dying = true
	secondary_frozen = false
	death_time = 0.0
	death_fall_duration = maxf(0.3, fall_duration)
	death_variant = RigidCache.death_serial % 6
	RigidCache.death_serial += 1
	death_direction = global_basis.inverse() * world_direction
	death_direction.y = 0
	if death_direction.length_squared() < 0.01: death_direction = Vector3.BACK
	death_direction = death_direction.normalized()
	# Six combinations of directional fall, twist and asymmetric limb spread.
	var side: float = [-1.0, 1.0, -1.0, 1.0, -1.0, 1.0][death_variant]
	var bias: float = [0.0, 0.22, -0.22, 1.0, -1.0, 0.45][death_variant]
	death_direction = death_direction.rotated(Vector3.UP, bias)
	death_targets.clear()
	for bone in skeleton.get_bone_count(): death_targets.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	# Imported limb +Y points down and +X points left: these signs fling outward.
	death_targets[arm_left] *= Quaternion.from_euler(Vector3(0.30 + phase_offset * 0.3, 0.1 * side, 0.65 + 0.08 * death_variant))
	death_targets[arm_right] *= Quaternion.from_euler(Vector3(-0.15, -0.15 * side, -0.50 - 0.12 * (death_variant % 3)))
	death_targets[leg_left] *= Quaternion.from_euler(Vector3(0.15 * side, 0.0, 0.18 + phase_offset * 0.15))
	death_targets[leg_right] *= Quaternion.from_euler(Vector3(-0.22 * side, 0.0, -0.22))
	death_targets[head] *= Quaternion.from_euler(Vector3(0.12, 0.16 * side, -0.10 * side))
	death_root_start = skeleton.get_bone_pose(root_bone)

func _evaluate_death() -> void:
	_restore_base()
	var ground_time: float = death_fall_duration * bounce_tuning.death_ground_fraction
	var fall := clampf(death_time / ground_time, 0.0, 1.0)
	var settle := clampf((death_time - ground_time) / (death_fall_duration - ground_time), 0.0, 1.0)
	if death_time >= ground_time: ground_bounce_count = 1
	var rotation_axis := Vector3.UP.cross(death_direction).normalized()
	var side: float = -1.0 if death_variant % 2 == 0 else 1.0
	var main_rotation := Quaternion(rotation_axis, PI * 0.5 * fall * fall)
	var twist := Quaternion(Vector3.UP, side * 0.12 * fall)
	var rebound: float = bounce_tuning.ground_rebound * sin(PI * settle)
	var root_q := (main_rotation * twist * death_root_start.basis.get_rotation_quaternion()).normalized()
	var pivot := skeleton.get_bone_global_rest(hips).origin
	var shift: Vector3 = death_direction * bounce_tuning.death_launch * (1.0 + 0.08 * death_variant) * fall
	var root_p: Vector3 = pivot - Basis(root_q) * pivot + shift + Vector3.UP * (bounce_tuning.death_lift * sin(PI * fall) + rebound)
	skeleton.set_bone_pose_rotation(root_bone, root_q)
	skeleton.set_bone_pose_position(root_bone, root_p)
	for bone in [arm_left, arm_right, leg_left, leg_right, head]:
		var delay := 0.18 if bone == head else (0.10 if bone in [leg_left, leg_right] else 0.0)
		var blend := smoothstep(delay, 0.80, fall)
		var q := base_rotations[bone].slerp(death_targets[bone], blend)
		# One diminishing rotational rebound, not a continually running oscillator.
		q *= Quaternion(Vector3.RIGHT, side * sin(PI * settle) * 0.035)
		skeleton.set_bone_pose_rotation(bone, q.normalized())
	# Rigid cuboid corners cached once across all zombies keep corpses above floor.
	var minimum := INF
	var cached_bone := -1
	var pose := Transform3D.IDENTITY
	for i in bound_corners.size():
		if bound_bones[i] != cached_bone:
			cached_bone = bound_bones[i]
			pose = skeleton.get_bone_global_pose(cached_bone)
		minimum = minf(minimum, (pose * bound_corners[i]).y)
	var floor_y: float = bounce_tuning.ground_clearance - get_parent().global_position.y
	if minimum < floor_y + rebound:
		skeleton.set_bone_pose_position(root_bone, root_p + Vector3.UP * (floor_y + rebound - minimum))

func death_smoke_position() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(chest).origin

func freeze_animation() -> void:
	secondary_frozen = true
	super.freeze_animation()

func _cache_bounds() -> void:
	if not RigidCache.bound_corners.is_empty():
		bound_bones = RigidCache.bound_bones
		bound_corners = RigidCache.bound_corners
		return
	var bounds := {}
	for mesh in meshes:
		if mesh.skin == null: continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX].size():
				for slot in 4:
					if arrays[Mesh.ARRAY_WEIGHTS][vertex * 4 + slot] < 0.5: continue
					var bind: int = arrays[Mesh.ARRAY_BONES][vertex * 4 + slot]
					var bone := skeleton.find_bone(mesh.skin.get_bind_name(bind))
					var point: Vector3 = mesh.skin.get_bind_pose(bind) * arrays[Mesh.ARRAY_VERTEX][vertex]
					bounds[bone] = bounds[bone].expand(point) if bounds.has(bone) else AABB(point, Vector3.ZERO)
	for bone in bounds:
		for corner in 8:
			bound_bones.append(bone)
			bound_corners.append(bounds[bone].get_endpoint(corner))
	RigidCache.bound_bones = bound_bones
	RigidCache.bound_corners = bound_corners
