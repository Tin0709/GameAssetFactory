extends "res://scripts/cuboid_animation.gd"
## AnimationPlayer is the imported library; this sole pose writer composes cached
## native Animation tracks, avoiding competing AnimationTree/modifier writers.
const Sampler = preload("res://scripts/animation_pose_sampler.gd")
const Socket = preload("res://scripts/player_weapon_socket.gd")
const Spring = preload("res://scripts/secondary_spring.gd")
@export var bounce_tuning: Resource = preload("res://materials/BounceTuning.tres")
## Opt-in integration mode: unchanged authored Idle/Run timing; legacy Walk and
## combat/socket composition stay available. Disabled for every existing scene.
@export var authored_locomotion: bool = false
var authored_run_time: float = 0.0
## Authored Run clock only. 1.60 balances measured support slip and readability;
## original clip duration, Walk cadence and gameplay speed remain untouched.
@export_range(0.5, 3.0, 0.01) var run_animation_speed_scale: float = 1.60
@export var generic_weapon_carry: bool = false
@export var long_gun_carry_v2: bool = false
@export_range(0.10, 0.18, 0.01) var weapon_hold_blend_duration: float = 0.13
var weapon_equipped: bool = true
var weapon_hold_weight: float = 0.0
var weapon_hold_pose: RefCounted
var long_gun_hold_pose: RefCounted
var long_gun_weight: float = 0.0
var weapon_behavior: Node
var fire_enabled_before_unequip: bool = true
var bounce_enabled := true
var bounce_override := 1.0
var body_spring := Spring.new()
var chest_spring := Spring.new()
var head_spring := Spring.new()
var arm_spring := Spring.new()
var weapon_spring := Spring.new()
var contact_count := 0
var leg_left: int
var leg_right: int
const PREFIXES = ["Pistol", "LongGun", "Shotgun"]
const WEAPON_NAMES = ["Pistol", "M4A1", "Shotgun"]
const RECOILS = ["Pistol_Recoil", "Rifle_Recoil", "Shotgun_Recoil"]
const LOCOMOTION_DEAD_ZONE := 0.12
## Visual full-stride cycles/second at the unchanged gameplay speed anchors.
## Short authored strides cannot simultaneously give natural cadence and plant
## feet at 4.25/6.25 m/s. Prefer readable rhythm over distance-locked fast bobbing.
@export_range(0.5, 3.0) var walk_cadence: float = 1.7
@export_range(0.5, 3.5) var run_cadence: float = 2.3
@export_range(0.1, 0.16) var cadence_transition: float = 0.13
var cycles_per_second: float = 0.0
var skeleton: Skeleton3D
var socket: BoneAttachment3D
var samples := {}
var idle: RefCounted
var walk: RefCounted
var run: RefCounted
var raise_pose: RefCounted
var recoil_pose: RefCounted
var upper := PackedInt32Array()
var recoil_mask := PackedInt32Array()
var hips: int
var chest: int
var head: int
var main_arm: int
var support_arm: int
var socket_bone: int
var has_target := false
var is_firing := false
var weapon_type := 0
var movement_speed := 0.0
var local_move_x := 0.0
var local_move_z := 0.0
var acceleration := Vector3.ZERO
var turn_rate := 0.0
var recoil_amount := 0.0
var locomotion_phase := 0.0
var aim_weight := 0.0
var run_weight := 0.0
var move_weight := 0.0
var idle_time := 0.0
var lower_yaw := 0.0
var lower_rotation := Quaternion.IDENTITY
var stride_sign := 1.0
var weapon_lag := 0.0
var previous_velocity := Vector3.ZERO
var frozen := false
var recoil_time := 100.0
var recoil_gain := 1.0
var queued_recoil := false
var switch_weight := 1.0
var switch_positions: Array[Vector3] = []
var switch_rotations: Array[Quaternion] = []

func _ready() -> void:
	super._ready()
	animation_player.stop()
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	assert(skeleton != null)
	for key in animation_player.get_animation_list():
		samples[key] = Sampler.new(animation_player.get_animation(key), skeleton)
	idle = samples["Player_Idle"]
	walk = samples["Player_Walk"]
	run = samples["Player_Run"]
	if authored_locomotion:
		idle = samples["Idle"]
		run = samples["Run"]
		idle.clip.loop_mode = Animation.LOOP_LINEAR
		run.clip.loop_mode = Animation.LOOP_LINEAR
	for name in ["Arm.L", "Arm.R", "WeaponSocket"]: upper.append(skeleton.find_bone(name))
	for name in ["Chest", "Neck", "Head", "Arm.L", "Arm.R", "WeaponSocket"]: recoil_mask.append(skeleton.find_bone(name))
	hips = skeleton.find_bone("Hips")
	chest = skeleton.find_bone("Chest")
	head = skeleton.find_bone("Head")
	main_arm = skeleton.find_bone("Arm.R")
	support_arm = skeleton.find_bone("Arm.L")
	socket_bone = skeleton.find_bone("WeaponSocket")
	leg_left = skeleton.find_bone("Leg.L")
	leg_right = skeleton.find_bone("Leg.R")
	for i in skeleton.get_bone_count():
		switch_positions.append(skeleton.get_bone_pose_position(i))
		switch_rotations.append(skeleton.get_bone_pose_rotation(i))
	if generic_weapon_carry:
		var hold: Animation = load("res://assets/characters/WeaponHold.tres")
		animation_player.get_animation_library("").add_animation("WeaponHold", hold)
		weapon_hold_pose = Sampler.new(hold, skeleton)
		var long_hold: Animation = load("res://assets/characters/LongGunHold_V2.tres")
		animation_player.get_animation_library("").add_animation("LongGunHold_V2", long_hold)
		long_gun_hold_pose = Sampler.new(long_hold, skeleton)
	socket = _new_weapon_socket()
	socket.name = "WeaponAttachment"
	skeleton.add_child(socket)
	_select_clips()
	_evaluate(0.0)

func _new_weapon_socket() -> BoneAttachment3D:
	return Socket.new()

func _select_clips() -> void:
	raise_pose = samples[PREFIXES[weapon_type] + "_Raise"]
	recoil_pose = samples[RECOILS[weapon_type]]

func equip_weapon(index: int) -> void:
	if frozen: return
	if generic_weapon_carry: set_weapon_equipped(true)
	if index == weapon_type: return
	for i in upper:
		switch_positions[i] = skeleton.get_bone_pose_position(i)
		switch_rotations[i] = skeleton.get_bone_pose_rotation(i)
	weapon_type = clampi(index, 0, 2)
	switch_weight = 0.0
	recoil_time = 100.0
	queued_recoil = false
	recoil_amount = 0.0
	socket.equip(weapon_type)
	_select_clips()
	if weapon_behavior != null: weapon_behavior.on_weapon_switched()

func set_weapon_equipped(equipped: bool) -> void:
	if weapon_equipped == equipped: return
	weapon_equipped = equipped
	if is_instance_valid(socket): socket.visible = equipped
	# Use the existing enabled gate; firing/profile/projectile mechanics are unchanged.
	var gun := get_parent().get_node_or_null("Pistol")
	if gun != null:
		if not equipped:
			fire_enabled_before_unequip = gun.enabled
			gun.enabled = false
		else: gun.enabled = fire_enabled_before_unequip
	if is_instance_valid(socket): socket.set_equipped_visible(equipped)

func update_motion(velocity_world: Vector3, target: Node3D, delta: float) -> void:
	if frozen: return
	velocity_world.y = 0.0
	movement_speed = velocity_world.length()
	has_target = is_instance_valid(target)
	var direction := target.global_position - global_position if has_target else (velocity_world if movement_speed >= LOCOMOTION_DEAD_ZONE else Vector3.ZERO)
	var old_yaw := rotation.y
	face_direction(direction, delta, 16.0)
	turn_rate = lerpf(turn_rate, wrapf(rotation.y - old_yaw, -PI, PI) / maxf(delta, 0.001), 1.0 - exp(-12.0 * delta))
	var local := global_basis.inverse() * velocity_world
	local_move_x = local.x
	local_move_z = local.z
	acceleration = acceleration.lerp(global_basis.inverse() * (velocity_world - previous_velocity) / maxf(delta, 0.001), 1.0 - exp(-10.0 * delta))
	previous_velocity = velocity_world
	# Fold the stride plane into +/-90 degrees and reverse phase for backpedal.
	if movement_speed >= LOCOMOTION_DEAD_ZONE:
		var yaw := lower_yaw + wrapf(atan2(local.x, local.z) - lower_yaw, -PI / 2.0, PI / 2.0)
		lower_yaw = wrapf(lerp_angle(lower_yaw, yaw, 1.0 - exp(-delta / 0.13)), -PI, PI)
		stride_sign = -1.0 if local.dot(Vector3(sin(lower_yaw), 0, cos(lower_yaw))) < -0.05 else 1.0

func _process(delta: float) -> void:
	super._process(delta)
	if frozen or skeleton == null: return
	if generic_weapon_carry:
		var carry: bool = weapon_equipped if weapon_behavior == null else weapon_behavior.carry_requested()
		weapon_hold_weight = move_toward(weapon_hold_weight, 1.0 if carry else 0.0, delta / weapon_hold_blend_duration)
		long_gun_weight = move_toward(long_gun_weight, 1.0 if long_gun_carry_v2 and carry and Socket.Profiles.category(weapon_type) == Socket.Profiles.Category.LONG_GUN else 0.0, delta / weapon_hold_blend_duration)
	var ready: bool = weapon_behavior == null or weapon_behavior.is_ready()
	aim_weight = move_toward(aim_weight, 1.0 if has_target and ready else 0.0, delta / 0.13)
	move_weight = move_toward(move_weight, clampf(movement_speed / 0.5, 0.0, 1.0) if movement_speed >= LOCOMOTION_DEAD_ZONE else 0.0, delta / 0.13)
	var desired_lower := Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, lower_yaw), move_weight).normalized()
	var lower_angle := lower_rotation.angle_to(desired_lower)
	# At +/-PI, a partially weighted direction can change its shortest branch.
	# Limit that seam to the same 0.13s turn-back rate instead of a one-frame flip.
	lower_rotation = lower_rotation.slerp(desired_lower, minf(1.0, delta * PI / 0.13 / maxf(lower_angle, 0.00001))).normalized()
	run_weight = move_toward(run_weight, smoothstep(4.25, 6.25, movement_speed), delta / 0.13)
	switch_weight = minf(1.0, switch_weight + delta / 0.13)
	# Blend calibrated visual stride lengths with the same weight as the poses.
	# Cadence remains speed-responsive below the anchors and bounded above them.
	var visual_stride := lerpf(4.25 / walk_cadence, 6.25 / run_cadence, run_weight)
	var desired_cycles := clampf(movement_speed / visual_stride, 0.0, run_cadence) if movement_speed >= LOCOMOTION_DEAD_ZONE else 0.0
	cycles_per_second = move_toward(cycles_per_second, desired_cycles, delta * run_cadence / cadence_transition)
	var phase_travel := delta * cycles_per_second * stride_sign
	var contacts := Spring.contacts_crossed(locomotion_phase, phase_travel, bounce_tuning.contact_phase)
	locomotion_phase = fposmod(locomotion_phase + phase_travel, 1.0)
	if bounce_enabled and move_weight > 0.1 and contacts > 0:
		contact_count += contacts
		var impulse: float = lerpf(bounce_tuning.walk_contact_impulse, bounce_tuning.run_contact_impulse, run_weight) * move_weight
		var pitch: float = lerpf(bounce_tuning.walk_pitch_impulse, bounce_tuning.run_pitch_impulse, run_weight) * move_weight
		body_spring.kick(Vector3(-impulse * contacts, pitch * contacts, 0), bounce_tuning.player_max_velocity)
	_advance_springs(delta)
	weapon_lag = lerpf(weapon_lag, clampf(acceleration.z * 0.0004, -0.012, 0.012), 1.0 - exp(-8.0 * delta))
	idle_time = fposmod(idle_time + delta, idle.clip.length)
	if authored_locomotion:
		# Continuous authored seconds; changing direction never resets phase.
		authored_run_time = fposmod(authored_run_time + delta * run_animation_speed_scale, run.clip.length)
	recoil_time += delta
	if recoil_time >= recoil_pose.clip.length and queued_recoil:
		recoil_time = fposmod(recoil_time, recoil_pose.clip.length)
		recoil_gain = 1.0
		queued_recoil = false
	is_firing = recoil_time < recoil_pose.clip.length
	recoil_amount = (1.0 - recoil_time / recoil_pose.clip.length) * recoil_gain if is_firing else 0.0
	var state: StringName = &"Idle" if movement_speed < LOCOMOTION_DEAD_ZONE else (&"Run" if run_weight > 0.5 else &"Walk")
	if state != current_state:
		current_state = state
		state_changes += 1
	_evaluate(delta)

func _evaluate(_delta: float) -> void:
	if _evaluate_locomotion_pose(_delta): return
	var wt: float = locomotion_phase * walk.clip.length
	var rt: float = authored_run_time if authored_locomotion else locomotion_phase * run.clip.length
	for i in skeleton.get_bone_count():
		var p: Vector3 = idle.position(i, idle_time).lerp(walk.position(i, wt).lerp(run.position(i, rt), run_weight), move_weight)
		var q: Quaternion = idle.rotation(i, idle_time).slerp(walk.rotation(i, wt).slerp(run.rotation(i, rt), run_weight), move_weight)
		if i in upper:
			p = raise_pose.position(i, aim_weight * raise_pose.clip.length)
			q = raise_pose.rotation(i, aim_weight * raise_pose.clip.length)
			if i == main_arm or i == support_arm:
				var parent_rest := skeleton.get_bone_global_rest(skeleton.get_bone_parent(i))
				var shoulder_offset: Vector3 = Socket.SHOULDER_OFFSETS[weapon_type] + Vector3(0, 0, Socket.LOW_READY_SHOULDER_FORWARD[weapon_type] * (1.0 - aim_weight))
				p += parent_rest.basis.inverse() * shoulder_offset
			elif i == socket_bone:
				p += Basis(q) * Vector3(0, Socket.LOW_READY_FORWARD[weapon_type] * (1.0 - aim_weight), 0)
		skeleton.set_bone_pose_position(i, p)
		skeleton.set_bone_pose_rotation(i, q.normalized())
	# Rotate hips in skeleton space, then cancel that rotation at chest: arms,
	# socket and head follow target while the leg stride follows local movement.
	# Never fade an unwrapped Euler angle: multiple turns would unwind on stop.
	# The normalized direction quaternion returns to Idle by its shortest path.
	_rotate_global(hips, lower_rotation)
	_rotate_global(chest, lower_rotation.inverse())
	# Carry the whole chest/arms/socket together to retain both fixed contacts.
	var lean := clampf(acceleration.z * 0.0012, -0.035, 0.035) + weapon_lag + run_weight * (1.0 - aim_weight) * 0.025
	var lag := clampf(turn_rate * -0.008, -0.025, 0.025)
	_rotate_global(chest, Quaternion.from_euler(Vector3(lean, lag, clampf(-acceleration.x * 0.0006, -0.02, 0.02))))
	_rotate_global(head, Quaternion.from_euler(Vector3(-lean * 0.65, -lag * 0.6, 0)))
	_apply_firing_recoil()
	_apply_springs()
	# Follow the final layered socket, including recoil, with each arm's outer
	# palm edge. Arm lengths, twist and socket recoil stay authored; long-gun
	# shoulders use the small front-shoulder stance offset above.
	var socket_pose := skeleton.get_bone_global_pose(socket_bone)
	if not generic_weapon_carry:
		_hold_arm(main_arm, socket_pose * socket.grips[weapon_type], Socket.MAIN_HAND_CONTACTS[weapon_type])
		_hold_arm(support_arm, socket_pose * socket.supports[weapon_type], Socket.SUPPORT_HAND_CONTACTS[weapon_type])
	# Blend final corrected destinations once; switching never reapplies offsets
	# to an already-corrected captured pose.
	for i in upper:
		skeleton.set_bone_pose_position(i, switch_positions[i].lerp(skeleton.get_bone_pose_position(i), switch_weight))
		skeleton.set_bone_pose_rotation(i, switch_rotations[i].slerp(skeleton.get_bone_pose_rotation(i), switch_weight).normalized())
	if authored_locomotion:
		# Keep existing Walk/aim/recoil behavior. For unarmed locomotion review,
		# restore the authored body instead of layering extra lean, springs or
		# arm gripping onto V7. Socket/weapon attachment remains fully functional.
		var authored_weight := maxf(1.0 - move_weight, run_weight) * (1.0 - aim_weight)
		if is_firing: authored_weight = 0.0
		for i in skeleton.get_bone_count():
			if i == socket_bone: continue
			var authored_p: Vector3 = idle.position(i, idle_time).lerp(run.position(i, rt), move_weight)
			var authored_q: Quaternion = idle.rotation(i, idle_time).slerp(run.rotation(i, rt), move_weight)
			skeleton.set_bone_pose_position(i, skeleton.get_bone_pose_position(i).lerp(authored_p, authored_weight))
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i).slerp(authored_q, authored_weight).normalized())
	if generic_weapon_carry:
		_apply_weapon_carry()

func _evaluate_locomotion_pose(_delta: float) -> bool:
	return false # Extension hook; the complete Legacy branch above remains available.

func _apply_firing_recoil() -> void:
	if not is_firing: return
	for i in recoil_mask:
		var offset: Vector3 = (recoil_pose.position(i, recoil_time) - recoil_pose.position(i, 0.0)) * recoil_gain
		var difference: Quaternion = recoil_pose.rotation(i, 0.0).inverse() * recoil_pose.rotation(i, recoil_time)
		skeleton.set_bone_pose_position(i, skeleton.get_bone_pose_position(i) + offset)
		skeleton.set_bone_pose_rotation(i, (skeleton.get_bone_pose_rotation(i) * Quaternion.IDENTITY.slerp(difference, recoil_gain)).normalized())

func _apply_weapon_carry() -> void:
	# Add a restrained model-space Chest bias, retaining all locomotion delta.
	var chest_bias: Quaternion = Quaternion.IDENTITY.slerp(long_gun_hold_pose.rotation(chest, 0.0), long_gun_weight)
	_rotate_global(chest, chest_bias)
	# A filtered Animation pose layer in the existing sole writer. No IK or
	# grip correction: arms/socket inherit Chest's authored locomotion rhythm.
	for i in upper:
		var p: Vector3 = weapon_hold_pose.position(i, 0.0).lerp(long_gun_hold_pose.position(i, 0.0), long_gun_weight)
		var q: Quaternion = weapon_hold_pose.rotation(i, 0.0).slerp(long_gun_hold_pose.rotation(i, 0.0), long_gun_weight)
		skeleton.set_bone_pose_position(i, skeleton.get_bone_pose_position(i).lerp(p, weapon_hold_weight))
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i).slerp(q, weapon_hold_weight).normalized())

func _hold_arm(bone: int, contact: Vector3, palm: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var from := (pose.basis * palm).normalized()
	var toward := (contact - pose.origin).normalized()
	_rotate_global(bone, Quaternion(from, toward))

func _rotate_global(bone: int, offset: Quaternion) -> void:
	if bone < 0: return
	var parent := skeleton.get_bone_parent(bone)
	var basis := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (basis.inverse() * offset * basis * skeleton.get_bone_pose_rotation(bone)).normalized())

func shot_recoil(_world_direction: Vector3) -> void:
	if frozen: return
	if bounce_enabled:
		var impulse: float = bounce_tuning.recoil_follow_impulses[weapon_type]
		body_spring.kick(Vector3(0, -impulse * 0.6, 0), bounce_tuning.max_velocity)
		weapon_spring.kick(Vector3(0, -impulse, 0), bounce_tuning.max_velocity)
	# Preserve an active impulse's time: repeated rifle shots cannot hard-reset it.
	if recoil_time < recoil_pose.clip.length:
		recoil_gain = minf(1.45, recoil_gain + 0.3)
		queued_recoil = true
	else:
		recoil_time = 0.0
		recoil_gain = 1.0

func freeze_animation() -> void:
	frozen = true
	is_firing = false
	super.freeze_animation()

func set_bounce(enabled: bool, strength: float = 1.0) -> void:
	bounce_enabled = enabled
	bounce_override = clampf(strength, 0.0, 2.0)
	for spring in [body_spring, chest_spring, head_spring, arm_spring, weapon_spring]: spring.reset()

func hit_impulse(world_direction: Vector3 = Vector3.ZERO) -> void:
	if frozen or not bounce_enabled: return
	var local := global_basis.inverse() * world_direction.normalized()
	if local.is_zero_approx(): local = Vector3.BACK
	body_spring.kick(Vector3(-bounce_tuning.hit_impulse * 0.15, local.z * bounce_tuning.hit_impulse, -local.x * bounce_tuning.hit_impulse), bounce_tuning.max_velocity)

func landing_response() -> void:
	if bounce_enabled: body_spring.kick(Vector3(-bounce_tuning.landing_impulse, 0, 0), bounce_tuning.max_velocity)

func _advance_springs(delta: float) -> void:
	if not bounce_enabled: return
	var limits := Vector3(bounce_tuning.player_max_drop, bounce_tuning.player_max_angle, bounce_tuning.player_max_angle)
	var target := Vector3(0, clampf(-acceleration.z * bounce_tuning.acceleration_strength, -limits.y, limits.y), clampf(-turn_rate * bounce_tuning.turn_spring_strength, -limits.z, limits.z))
	target.x = (idle.position(hips, idle_time).y - idle.position(hips, 0).y) * bounce_tuning.idle_follow_strength * (1.0 - move_weight)
	var substeps := clampi(ceili(delta * bounce_tuning.integration_hz), 1, bounce_tuning.max_substeps)
	for substep in substeps:
		var dt := delta / substeps
		body_spring.advance(dt, target, bounce_tuning.player_frequency, bounce_tuning.player_damping, limits)
		chest_spring.advance(dt, body_spring.value, bounce_tuning.chest_frequency, bounce_tuning.player_damping + 0.10, limits)
		head_spring.advance(dt, chest_spring.value * bounce_tuning.head_follow_strength, bounce_tuning.head_frequency, bounce_tuning.player_damping + 0.18, limits)
		arm_spring.advance(dt, chest_spring.value, bounce_tuning.arm_frequency, bounce_tuning.player_damping + 0.12, limits)
		weapon_spring.advance(dt, arm_spring.value, bounce_tuning.weapon_frequencies[weapon_type], bounce_tuning.player_damping + 0.10, limits)

func _apply_springs() -> void:
	if not bounce_enabled: return
	var gain: float = bounce_tuning.bounce_strength * bounce_override * lerpf(1.0, bounce_tuning.combat_body_response, aim_weight)
	var drop: float = body_spring.value.x * gain
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips) + Vector3.UP * drop)
	# Counter-translate rigid leg anchors: the secondary layer does not move soles.
	for leg in [leg_left, leg_right]:
		var parent_basis := skeleton.get_bone_global_pose(skeleton.get_bone_parent(leg)).basis
		skeleton.set_bone_pose_position(leg, skeleton.get_bone_pose_position(leg) + parent_basis.inverse() * Vector3.DOWN * drop)
	var chest_offset := chest_spring.value * gain
	skeleton.set_bone_pose_position(chest, skeleton.get_bone_pose_position(chest) + Vector3.UP * (chest_spring.value.x - body_spring.value.x) * gain * bounce_tuning.chest_vertical_follow)
	_rotate_global(chest, Quaternion.from_euler(Vector3(chest_offset.y, chest_offset.z, 0)))
	var head_offset := (head_spring.value - chest_spring.value) * gain
	skeleton.set_bone_pose_position(head, skeleton.get_bone_pose_position(head) + Vector3.UP * head_offset.x * bounce_tuning.head_vertical_follow)
	_rotate_global(head, Quaternion.from_euler(Vector3(head_offset.y, head_offset.z, 0)))
	var follow: float = bounce_tuning.bounce_strength * bounce_override * bounce_tuning.weapon_follow_strength * lerpf(1.0, bounce_tuning.aim_stabilization, aim_weight) * bounce_tuning.weapon_mass[weapon_type]
	var relative := (weapon_spring.value - chest_spring.value) * follow
	relative.x = clampf(relative.x, -bounce_tuning.max_weapon_shift, bounce_tuning.max_weapon_shift)
	relative.y = clampf(relative.y, -bounce_tuning.max_weapon_angle, bounce_tuning.max_weapon_angle)
	relative.z = clampf(relative.z, -bounce_tuning.max_weapon_angle, bounce_tuning.max_weapon_angle)
	var pivot := skeleton.get_bone_global_pose(chest).origin
	var rotation := Basis(Quaternion.from_euler(Vector3(relative.y, relative.z, 0)))
	# One rigid transform for the two hands and socket; final contact solver remains.
	for bone in upper:
		var pose := skeleton.get_bone_global_pose(bone)
		pose.origin = pivot + rotation * (pose.origin - pivot) + Vector3.UP * relative.x
		pose.basis = rotation * pose.basis
		var local := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).affine_inverse() * pose
		skeleton.set_bone_pose_position(bone, local.origin)
		skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion().normalized())

func debug_text() -> String:
	var text := "%s | %s | %s | target %s | firing %s | %.2f m/s" % [WEAPON_NAMES[weapon_type], current_state, "Aim" if aim_weight > 0.5 else "LowReady", has_target, is_firing, movement_speed]
	if weapon_behavior != null and weapon_behavior.debug_visible: text += "\n" + weapon_behavior.debug_text()
	return text
