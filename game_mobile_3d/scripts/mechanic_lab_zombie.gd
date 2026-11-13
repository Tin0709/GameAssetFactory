extends CharacterBody3D

signal melee_hit(amount: int)
signal step_audio(point: Vector3)

enum DeathStrike { GROUND, AIR, SABRE_FINISHER, SABRE_GROUND }
signal melee_audio(point: Vector3, contact: bool)

const Feedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const HealthBars := preload("res://scripts/mechanic_lab_health_bars.gd")
const DamageNumbers := preload("res://scripts/mechanic_lab_damage_numbers.gd")
const Ragdoll := preload("res://scripts/mechanic_lab_ragdoll.gd")
const DeathProfile := preload("res://scenes/dev/zombie_death_physics/death_profile.gd")
const CORPSE_SHADER := preload("res://materials/mechanic_lab_zombie_corpse.gdshader")
const HIT_FLASH_SHADER := preload("res://materials/mechanic_lab_zombie_hit_flash.gdshader")
const IDLE := &"Zombie_Idle"
const WALK_CLIPS := [&"Zombie_Walk", &"Zombie_Walk_Variant1", &"Zombie_Walk_Variant2"]
# Forward sole-height minima in the pinned 30 Hz walk GLBs. The exports have no notify track.
const WALK_STEP_FRAMES := {
	&"Zombie_Walk": [Vector2(10, 0.095), Vector2(34, 0.127)],
	&"Zombie_Walk_Variant1": [Vector2(22, 0.112), Vector2(45, 0.193)],
	&"Zombie_Walk_Variant2": [Vector2(22, 0.112), Vector2(45, 0.193)],
}
const STEP_MIN_SPEED_SQUARED := 0.15 * 0.15
const SPAWN := &"Zombie_Spawn"
const ATTACK := &"Zombie_BasicAttack"
const STAGGER := &"Zombie_Staggered"
const BASE_HEALTH := 8
const TRAINING_HEALTH := 48
const MAX_POISE := 28.0
const POISE_RECOVERY_DELAY := 2.0
const POISE_RECOVERY_PER_SECOND := 20.0
const STAGGER_DURATION := 0.65 # DefaultHostile.GA_BecomeStaggered.
const KNOCKBACK_CONTROL_LOCK := 0.4 # DT_MeleePropertyDefinition: Sabre and Sword.
const KNOCKBACK_DECELERATION := 10.0
const DEFAULT_DEATH_IMPULSE := Vector2(285.0, 190.0)
# DT_MobDefinition.DefaultHostile -> GA_Ragdoll (HandleFinalDeath).
# Zombie inherits this row through MeleeAttackMob. The runtime solver formula
# is unavailable; Godot's speed, spin, and tier response are local calibration.
const DEATH_SOURCE_SPEED := 800.0
const DEATH_LAUNCH_ANGLE := 30.0
const DEATH_SOURCE_ANGULAR_SCALE := 40.0
const DEATH_TWIRL_CHANCE := 0.33
const DEATH_STRENGTH_THRESHOLDS := [400.0, 750.0, 1200.0]
const DEATH_ADDITIONAL_MULTIPLIERS := [0.5, 1.0, 1.5]
const DEATH_SPEED_TO_LAB := 0.0088
const DEATH_TIER_INFLUENCE := 0.75
const DEATH_ANGULAR_TO_LAB := 0.18
const DEATH_AIR_ATTACK_ANGULAR_TO_LAB := 0.14
const DEATH_FINISHER_ROLL_SPEED := 1.0
const ZOMBIE_GRAVITY := 50.0 # MD2 Overworld's default, converted from cm/s².
const SABRE_FINISHER_GRAVITY_HOLD := 0.30
const SABRE_GROUND_FLOOR_LIMB_SHARE := 0.35
const SABRE_FINISHER_FLOOR_LIMB_SHARE := 0.62
# MD2 DefaultPhysicalMaterial, shared by all six authored bodies.
const DEATH_SOURCE_FRICTION := 0.70
const DEATH_SOURCE_RESTITUTION := 0.30
const SOURCE_MASS_EXPONENT := 0.75
const SOURCE_RIG_LAB_MASS := 60.0
const DEATH_LANDING_BLEND_TIME := 0.20
const DEATH_AIR_LINEAR_DAMP := 0.01 # SK_Zombie_PhysicsAsset body defaults.
const DEATH_FLOOR_CONTACT_MARGIN := 0.02
const DEATH_LIMB_SUPPORT_DURATION := 0.10
const DEATH_LIMB_SUPPORT_MAX_SPEED := 2.0
const DEATH_LANDING_LINEAR_DAMP := 3.0
const DEATH_LANDING_ANGULAR_DAMP := 4.0
const DEATH_SUPPORTED_ANGULAR_DAMP := 12.0
const SABRE_LATE_ROLL_ANGULAR_DAMP := 6.0
const SABRE_ROLL_BLEND_END := 0.35
const SABRE_BRACE_MIN_AGE := 0.82
const SABRE_BRACE_GRAVITY_SHARE := 0.65
const SABRE_BRACE_BLEND_TIME := 0.10
const SABRE_ROLL_RESPONSE_TIME := 0.10
const DEATH_LANDING_ANGULAR_SPEED_LIMIT := 16.0
const HEIGHT := 1.95
const CHASE_SPEED := 3.1
const CROWD_RETRY_MIN_ZOMBIES := 32
const BLOCKED_CHASE_RETRY_HZ := 30.0
const PACKED_CHASE_RETRY_HZ := 15.0
const BLOCKED_CHASE_MAX_SPEED_SQUARED := 0.01
const BLOCKER_MOVE_DISTANCE_SQUARED := 0.025 * 0.025
const CHASE_TARGET_MOVE_DISTANCE_SQUARED := 0.10 * 0.10
const MELEE_RANGE := 1.36
const MELEE_RANGE_TOLERANCE := 0.025
# Zombie overrides damage and attack speed. MeleeAttackMob supplies the range,
# cone and cooldown. The two source times are landmarks on Zombie_BasicAttack.
const MELEE_DAMAGE := 6
const MELEE_REACH := 2.0
const MELEE_HEIGHT_LIMIT := 2.0
const MELEE_HALF_ANGLE_COS := 0.9659258263 # cos(30 degrees / 2).
const MELEE_COOLDOWN := 0.5
const TELEGRAPH_RATE := 1.5
const TELEGRAPH_END := 15.0 / 30.0
const MELEE_CONTACT_TIME := 17.0 / 30.0
const LEVEL_COLLISION_MASK := 1
const CORPSE_COLLISION_LAYER := 8
const CORPSE_LIFETIME := 5.0
const CORPSE_DESATURATION_START := 2.3
const CORPSE_DESATURATION_END := 3.6
const CORPSE_SETTLE_TIME := 0.10
const CORPSE_SETTLE_SPEED := 0.34
const CORPSE_SETTLE_SPIN := 1.6
const CORPSE_SETTLE_MAX_AXIS_Y := 0.32
const CORPSE_UPRIGHT_AXIS_Y := 0.70
const CORPSE_WALL_REST_TIME := 0.50
const CORPSE_TERRAIN_REST_TIME := 1.0
const CORPSE_TERRAIN_SUPPORT_MARGIN := 0.012
# Compare pose drift over a rest window using MD2's default material sleep speeds.
const CORPSE_TERRAIN_REST_SHIFT := 0.01 * CORPSE_WALL_REST_TIME
const CORPSE_TERRAIN_REST_TURN := 0.05 * CORPSE_WALL_REST_TIME
# Contact normals can oscillate against a wall even after visible motion stops.
const CORPSE_FLAT_WALL_REST_SHIFT := 0.015
const CORPSE_FLAT_WALL_REST_TURN := 0.05
const HIT_FLASH_DURATION := 0.083

# Fit the existing seven-body solver to the verified SK_Zombie bind mesh.
const RAGDOLL_BONES := {
	"Hips": "J_Hip", "Chest": "J_Shoulders", "Head": "J_Head",
	"Arm.L": "J_L_Arm", "Arm.R": "J_R_Arm", "Leg.L": "J_L_Leg", "Leg.R": "J_R_Leg",
}
const RAGDOLL_PARTS := [
	["Hips", Vector3(0, 0.79, 0), Vector3(0.41, 0.16, 0.21), 8.0, 0.0, 0.0],
	["Chest", Vector3(0, 1.125, 0), Vector3(0.48, 0.71, 0.23), 22.0, 12.0, 8.0],
	["Head", Vector3(0, 1.742, 0), Vector3(0.48, 0.48, 0.48), 8.0, 22.0, 15.0],
	["Arm.L", Vector3(0.375, 1.117, 0), Vector3(0.23, 0.71, 0.23), 4.0, 48.0, 18.0],
	["Arm.R", Vector3(-0.375, 1.117, 0), Vector3(0.23, 0.71, 0.23), 4.0, 48.0, 18.0],
	["Leg.L", Vector3(0.125, 0.375, 0), Vector3(0.23, 0.71, 0.23), 7.0, 33.0, 14.0],
	["Leg.R", Vector3(-0.125, 0.375, 0), Vector3(0.23, 0.71, 0.23), 7.0, 33.0, 14.0],
]

var target: CharacterBody3D
var animation: AnimationPlayer
var ragdoll: Ragdoll
var max_health := TRAINING_HEALTH
var health := TRAINING_HEALTH
var ragdoll_launch_multiplier := 1.0
var ragdoll_gravity_multiplier := 1.0
var _feedback: Feedback
var _mesh: MeshInstance3D
var _walk_clip: StringName
var _knockback := Vector3.ZERO
var _knockback_deceleration := KNOCKBACK_DECELERATION
var _knockback_control_left := 0.0
var _death_direction := Vector3.ZERO
var _death_strength := 500.0
var _death_strike := DeathStrike.GROUND
var _death_rng := RandomNumberGenerator.new()
var _poise := MAX_POISE
var _poise_recovery_wait := 0.0
var _attack_cooldown := 0.0
var _crowd_slot := 0
var _blocked_chase := false
var _blocking_zombie_id := 0
var _blocking_position := Vector3.ZERO
var _blocked_target_position := Vector3.ZERO
var _skipped_blocked_step := false
var _flash_left := 0.0
var _corpse_age := 0.0
var _corpse_landed := false
var _limb_support_age := 0.0
var _corpse_parked := false
var _corpse_color_finished := false
var _settled_seconds := 0.0
var _landing_age := INF
var _roll_damping_weight := 0.0
var _late_roll_damping := 0.0
var _wall_brace_age := 0.0
var _wall_gravity := false
var _flat_brace_weight := 0.0
var _terrain_rest_age := 0.0
var _terrain_rest_duration := 0.0
var _terrain_rest_poses: Dictionary[String, Transform3D]
var _ragdoll_layout: Dictionary
var _corpse_floor: CollisionShape3D
static var _flash_material: ShaderMaterial
static var _death_profile: DeathProfile
static var _corpse_base_material: ShaderMaterial
static var _live_capsule: CapsuleShape3D

func configure(model: Node, player: CharacterBody3D, effects: Node3D, digits: Array[Texture2D],
		serial: int, ragdoll_layout: Dictionary = {}, corpse_floor: CollisionShape3D = null,
		health_bars: HealthBars = null, damage_numbers: DamageNumbers = null) -> void:
	target = player
	_ragdoll_layout = ragdoll_layout
	_corpse_floor = corpse_floor
	_crowd_slot = serial
	_death_rng.seed = hash(Vector2i(serial, 1709))
	_walk_clip = WALK_CLIPS[serial % WALK_CLIPS.size()]
	add_child(model)
	animation = model.get_node("AnimationPlayer")
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_mesh = model.find_child("SK_Zombie", true, false)
	_feedback = Feedback.new()
	_feedback.digits = digits
	_feedback.effects = effects
	_feedback.health_bars = health_bars
	_feedback.damage_numbers = damage_numbers
	add_child(_feedback)
	if _live_capsule == null:
		_live_capsule = CapsuleShape3D.new()
		_live_capsule.radius = 0.43
		_live_capsule.height = HEIGHT
	var collision := CollisionShape3D.new()
	collision.position.y = HEIGHT * 0.5
	collision.shape = _live_capsule
	add_child(collision)
	collision_layer = 4
	collision_mask = 1 | 2 | 4

func _ready() -> void:
	set_process(false)
	health = max_health
	animation.play(SPAWN)
	animation.advance(0)
	ragdoll = Ragdoll.new()
	add_child(ragdoll)
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	var source := _ragdoll_layout
	if source.is_empty():
		ragdoll.setup(skeleton, RAGDOLL_PARTS, RAGDOLL_BONES)
	else:
		ragdoll.setup(skeleton, source.parts, source.bones, source.offsets, source.joints)
	for body: PhysicalBone3D in ragdoll.bodies.values():
		body.collision_layer = 0
		body.collision_mask = 0
	if _death_profile == null:
		_death_profile = DeathProfile.new()
		_death_profile.angular_impulse = 0.8
		_death_profile.transport_fraction = 0.96
		_death_profile.linear_damping = DEATH_AIR_LINEAR_DAMP
		_death_profile.angular_damping = 0.9
		_death_profile.joint_resistance = 0.45
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = HIT_FLASH_SHADER

# Asset Dumper swaps Unreal Y/Z and exports centimetres as metres. Validate
# the conversion against both authored anchors in the verified mesh's bind pose.
static func _from_unreal(v: Array) -> Vector3:
	return Vector3(v[0], v[2], v[1])

static func _source_frame(frame: Array) -> Transform3D:
	var primary := _from_unreal(frame[1])
	var secondary := _from_unreal(frame[2])
	return Transform3D(Basis(primary, secondary, primary.cross(secondary)).orthonormalized(),
		_from_unreal(frame[0]) * 0.01)

static func source_ragdoll_layout(skeleton: Skeleton3D, profile: Dictionary) -> Dictionary:
	if skeleton == null or profile.get("schema") != "md2-zombie-physics/1":
		return {}
	var roles := {"J_Spine": "Chest", "J_Neck": "Head", "J_L_Arm": "Arm.L", "J_R_Arm": "Arm.R",
		"J_L_Leg": "Leg.L", "J_R_Leg": "Leg.R"}
	var bones := {}
	var offsets := {}
	var parts := []
	var joints := {}
	var total_mass_weight := 0.0
	for entry: Dictionary in profile.bodies:
		var name: String = roles.get(entry.bone, "")
		if name.is_empty() or skeleton.find_bone(entry.bone) < 0:
			return {}
		var size := _from_unreal(entry.size_cm) * 0.01
		var mass_weight := pow(size.x * size.y * size.z, SOURCE_MASS_EXPONENT)
		total_mass_weight += mass_weight
		bones[name] = entry.bone
		offsets[name] = Transform3D(Basis.IDENTITY, _from_unreal(entry.center_cm) * 0.01)
		parts.append([name, Vector3.ZERO, size, mass_weight, 0.0, 0.0])
	# The density and mass scale are shared. Normalize the relative masses to the lab's total.
	for part: Array in parts:
		part[3] *= SOURCE_RIG_LAB_MASS / total_mass_weight
	for entry: Dictionary in profile.constraints:
		var child: String = roles[entry.child]
		var parent: String = roles[entry.parent]
		var child_frame := _source_frame(entry.child_frame)
		var parent_frame := _source_frame(entry.parent_frame)
		var child_bind := skeleton.get_bone_global_rest(skeleton.find_bone(entry.child)) * child_frame
		var parent_bind := skeleton.get_bone_global_rest(skeleton.find_bone(entry.parent)) * parent_frame
		if child_bind.origin.distance_to(parent_bind.origin) > 0.005 or child_bind.basis.get_rotation_quaternion().angle_to(parent_bind.basis.get_rotation_quaternion()) > 0.03:
			push_warning("MD2 zombie physics anchors do not match the imported bind pose.")
			return {}
		joints[child] = {"parent": parent, "child_frame": offsets[child].affine_inverse() * child_frame,
			"parent_frame": offsets[parent].affine_inverse() * parent_frame, "swing": entry.swing, "twist": entry.twist}
	return {"parts": parts, "bones": bones, "offsets": offsets, "joints": joints}

func _process(delta: float) -> void:
	# Sample before advancing so the first drawn frame gets the full flash.
	var flash := smoothstep(0.0, HIT_FLASH_DURATION * 0.65, _flash_left)
	_mesh.set_instance_shader_parameter("hit_flash", flash)
	if _flash_left <= 0.0:
		_mesh.material_overlay = null
		set_process(false)
	else:
		_flash_left = maxf(0.0, _flash_left - delta)

func _physics_process(delta: float) -> void:
	if health <= 0:
		_update_death(delta)
		return
	if global_position.y < -6.0:
		queue_free()
		return
	var recovery_time := maxf(0.0, delta - _poise_recovery_wait)
	_poise_recovery_wait = maxf(0.0, _poise_recovery_wait - delta)
	_poise = minf(MAX_POISE, _poise + POISE_RECOVERY_PER_SECOND * recovery_time)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	var controlled_time := maxf(0.0, delta - _knockback_control_left)
	_knockback_control_left = maxf(0.0, _knockback_control_left - delta)
	var pushed := not _knockback.is_zero_approx()
	var travel := _integrate_knockback(delta)
	if controlled_time > 0.000001:
		travel += _chase_velocity(controlled_time) * (controlled_time / delta)
	velocity.x = travel.x
	velocity.z = travel.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * _gravity_scale(ZOMBIE_GRAVITY) * delta
	var crowd := is_instance_valid(_corpse_floor) and get_parent().get_child_count() >= CROWD_RETRY_MIN_ZOMBIES
	var chasing := crowd and not pushed and controlled_time == delta and not travel.is_zero_approx() \
		and animation.current_animation in WALK_CLIPS
	_skipped_blocked_step = false
	if chasing and _blocked_chase and is_on_floor():
		# Spread collision retries across zombies. Keep animation and pose history
		# on the full physics clock, including frames without a movement query.
		_skipped_blocked_step = _wait_for_chase_retry()
	if not _skipped_blocked_step:
		move_and_slide()
		_blocked_chase = chasing and is_on_floor() and is_on_wall() \
			and get_real_velocity().slide(Vector3.UP).length_squared() < BLOCKED_CHASE_MAX_SPEED_SQUARED
		_update_chase_blocker()
	_advance_animation(delta)
	ragdoll.sample(delta)

func _wait_for_chase_retry() -> bool:
	var retry_hz := BLOCKED_CHASE_RETRY_HZ
	if _blocking_zombie_id != 0:
		var blocker := instance_from_id(_blocking_zombie_id) as CharacterBody3D
		if (blocker == null or blocker.is_queued_for_deletion() or blocker.collision_layer == 0
				or blocker.global_position.distance_squared_to(_blocking_position) > BLOCKER_MOVE_DISTANCE_SQUARED
				or target.global_position.distance_squared_to(_blocked_target_position) > CHASE_TARGET_MOVE_DISTANCE_SQUARED):
			return false
		retry_hz = PACKED_CHASE_RETRY_HZ
	var stride := maxi(1, roundi(Engine.physics_ticks_per_second / retry_hz))
	return Engine.get_physics_frames() % stride != _crowd_slot % stride

func _update_chase_blocker() -> void:
	if not _blocked_chase or get_slide_collision_count() == 0:
		_blocking_zombie_id = 0
		return
	var blocker := get_last_slide_collision().get_collider() as CharacterBody3D
	if blocker == null or blocker.get_parent() != get_parent():
		_blocking_zombie_id = 0
		return
	_blocking_zombie_id = blocker.get_instance_id()
	# The node can move before the physics space sees its new position.
	var collider_transform: Transform3D = PhysicsServer3D.body_get_state(
		blocker.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	_blocking_position = collider_transform.origin
	_blocked_target_position = target.global_position

func _integrate_knockback(delta: float) -> Vector3:
	var speed := _knockback.length()
	if speed <= 0.0:
		return Vector3.ZERO
	var direction := _knockback / speed
	var moving_time := minf(delta, speed / _knockback_deceleration)
	var end_speed := maxf(0.0, speed - _knockback_deceleration * moving_time)
	_knockback = Vector3.ZERO if is_zero_approx(end_speed) else direction * end_speed
	# move_and_slide uses a step velocity. Integrate the falling speed through
	# the moving part of the step so the push distance is independent of tick rate.
	return direction * ((speed + end_speed) * 0.5 * moving_time / delta)

func _advance_animation(delta: float) -> void:
	var clip := animation.current_animation
	if clip != ATTACK:
		var play_steps := (step_audio.has_connections() and clip in WALK_STEP_FRAMES and is_on_floor()
			and not _skipped_blocked_step and get_real_velocity().slide(Vector3.UP).length_squared() >= STEP_MIN_SPEED_SQUARED)
		var previous_phase := animation.current_animation_position if play_steps else 0.0
		animation.advance(delta)
		if play_steps:
			_emit_walk_step(clip, previous_phase)
		return
	var before := animation.current_animation_position
	var telegraph_seconds := clampf((TELEGRAPH_END - before) / TELEGRAPH_RATE, 0.0, delta)
	var advance_seconds := delta + telegraph_seconds * (TELEGRAPH_RATE - 1.0)
	animation.advance(advance_seconds)
	if before < MELEE_CONTACT_TIME and before + advance_seconds >= MELEE_CONTACT_TIME:
		_check_melee_contact()

func _emit_walk_step(clip: StringName, previous_phase: float) -> void:
	var phase := animation.current_animation_position
	var wrapped := phase < previous_phase
	for i in 2:
		var contact: Vector2 = WALK_STEP_FRAMES[clip][i]
		var at := contact.x / 30.0
		var crossed := (at > previous_phase or at <= phase) if wrapped else (at > previous_phase and at <= phase)
		if crossed:
			var side := 0.125 if i == 0 else -0.130
			step_audio.emit(to_global(Vector3(side, 0.0, contact.y)))

func _check_melee_contact() -> void:
	if target.get("is_dead") == true:
		return
	var offset := target.global_position - global_position
	if absf(offset.y) > MELEE_HEIGHT_LIMIT:
		return
	offset.y = 0.0
	if offset.length_squared() > MELEE_REACH * MELEE_REACH or not _is_in_melee_cone(offset):
		return
	var height := Vector3.UP * (HEIGHT * 0.5)
	var ray := PhysicsRayQueryParameters3D.create(global_position + height, target.global_position + height, LEVEL_COLLISION_MASK)
	ray.hit_from_inside = true
	if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		melee_audio.emit(global_position + height, true)
		melee_hit.emit(MELEE_DAMAGE)

func _is_in_melee_cone(planar_offset: Vector3) -> bool:
	return global_basis.z.dot(planar_offset) >= planar_offset.length() * MELEE_HALF_ANGLE_COS

func _chase_velocity(delta: float) -> Vector3:
	if animation.current_animation in [SPAWN, ATTACK, STAGGER]:
		return Vector3.ZERO
	if target.get("is_dead") == true:
		_play_loop(IDLE)
		return Vector3.ZERO
	var offset := target.global_position - global_position
	var height_delta := absf(offset.y)
	offset.y = 0.0
	var distance := offset.length()
	if distance > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), minf(delta * 10.0, 1.0))
	if distance > MELEE_RANGE + MELEE_RANGE_TOLERANCE:
		_play_loop(_walk_clip)
		return offset.normalized() * minf(CHASE_SPEED, (distance - MELEE_RANGE) / delta)
	# Complete the approach turn before locking the swing's heading.
	var facing_target := _is_in_melee_cone(offset)
	if height_delta <= MELEE_HEIGHT_LIMIT and facing_target and _attack_cooldown <= 0.0:
		animation.play(ATTACK, 0.1)
		_attack_cooldown = MELEE_COOLDOWN
		melee_audio.emit(global_position + Vector3.UP * (HEIGHT * 0.5), false)
	else:
		_play_loop(IDLE)
	return Vector3.ZERO

func _play_loop(clip: StringName) -> void:
	if animation.current_animation != clip:
		animation.play(clip, 0.13)

func take_hit(amount: int, direction: Vector3, launch_impulse: Vector2 = DEFAULT_DEATH_IMPULSE,
		stagger: float = MAX_POISE, knockback_strength: float = 500.0, death_strike := DeathStrike.GROUND,
		push_duration := 0.0) -> void:
	if health <= 0 or amount <= 0:
		return
	_blocked_chase = false
	health = maxi(0, health - amount)
	direction.y = 0.0
	direction = direction.normalized()
	_feedback.show_hit(amount, health, max_health)
	_mesh.material_overlay = _flash_material
	_mesh.set_instance_shader_parameter("hit_flash", 1.0)
	_flash_left = HIT_FLASH_DURATION
	set_process(true)
	if health <= 0:
		_death_direction = direction
		_death_strength = knockback_strength
		_death_strike = death_strike
		if is_instance_valid(_corpse_floor) and animation.current_animation == SPAWN:
			# The source spawn clip scales J_Hip to 1%. The ragdoll's authored
			# colliders and joint frames require the full-size skeleton.
			animation.play(IDLE, 0.0)
			animation.advance(0.0)
			ragdoll.sample_count = 0
		animation.pause()
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
	elif stagger > 0.0:
		_knockback = direction * launch_impulse.x / 80.0
		_knockback_deceleration = KNOCKBACK_DECELERATION
		if not _knockback.is_zero_approx():
			if push_duration > 0.0:
				# Fit the push time while retaining the strength-derived open-floor travel.
				var speed := _knockback.length()
				var scale := speed / (KNOCKBACK_DECELERATION * push_duration)
				_knockback *= scale
				_knockback_deceleration = speed * scale / push_duration
			_knockback_control_left = KNOCKBACK_CONTROL_LOCK
		_poise -= stagger
		_poise_recovery_wait = POISE_RECOVERY_DELAY
		if _poise <= 0.0:
			_poise = MAX_POISE
			if animation.current_animation != STAGGER:
				animation.stop(true)
				var clip_duration := animation.get_animation(STAGGER).length
				animation.play(STAGGER, 0.0, clip_duration / STAGGER_DURATION)
		elif _knockback_control_left > 0.0 and animation.current_animation in WALK_CLIPS:
			_play_loop(IDLE)

func _update_death(delta: float) -> void:
	_corpse_age += delta
	if _corpse_age >= CORPSE_LIFETIME - 0.00001:
		queue_free()
		return
	if not _corpse_color_finished and _corpse_age >= CORPSE_DESATURATION_START:
		_update_corpse_material()
	if _corpse_parked:
		return
	var sabre_finisher := _death_strike == DeathStrike.SABRE_FINISHER
	var source_rig := not ragdoll.source_joints.is_empty()
	if not ragdoll.running:
		if ragdoll.sample_count < 2:
			# A fresh spawn has no measured motion. Seed both snapshots from
			# the paused pose so the hit can launch on this physics tick.
			ragdoll.sample(delta)
			ragdoll.sample(delta)
		var mass := 0.0
		for body: PhysicalBone3D in ragdoll.bodies.values():
			# The player uses layer 2, which the living controllers can stand on.
			body.collision_layer = CORPSE_COLLISION_LAYER
			body.collision_mask = LEVEL_COLLISION_MASK
			if source_rig:
				body.bounce = DEATH_SOURCE_RESTITUTION
				# The flat lab uses its calibrated floor traction during contact recovery.
				if not is_instance_valid(_corpse_floor):
					body.friction = DEATH_SOURCE_FRICTION
			mass += body.mass
		if sabre_finisher:
			# Start with MD2's default material values on the leading contact.
			var head: PhysicalBone3D = ragdoll.bodies.Head
			head.friction = DEATH_SOURCE_FRICTION
			head.bounce = DEATH_SOURCE_RESTITUTION
		var launch := _death_profile.duplicate() as DeathProfile
		var angle := deg_to_rad(DEATH_LAUNCH_ANGLE)
		var launch_impulse := _death_launch_speed(_death_strength) * mass * ragdoll_launch_multiplier
		launch.linear_impulse = cos(angle) * launch_impulse
		launch.upward_impulse = sin(angle) * launch_impulse
		var direction := Vector3.FORWARD if _death_direction.is_zero_approx() else _death_direction
		var floor_impact_limb_share := 0.0
		if sabre_finisher:
			floor_impact_limb_share = SABRE_FINISHER_FLOOR_LIMB_SHARE
		elif _death_strike == DeathStrike.SABRE_GROUND:
			floor_impact_limb_share = SABRE_GROUND_FLOOR_LIMB_SHARE
		var flight_gravity := ZOMBIE_GRAVITY * ragdoll_gravity_multiplier
		if ragdoll.begin(launch, direction, "Chest", 0.0, flight_gravity, _corpse_floor, floor_impact_limb_share, sabre_finisher):
			_apply_death_tumble(_death_spin(direction), mass)
		return
	var contact := ragdoll.contact_motion()
	if not _corpse_landed:
		# On a terrace, limbs can carry the body before the core reaches a surface.
		# Require sustained support so a brief grazing hit keeps its flight response.
		var limbs_supporting: bool = contact.supports >= 2 and contact.linear < DEATH_LIMB_SUPPORT_MAX_SPEED
		_limb_support_age = _limb_support_age + delta if limbs_supporting else 0.0
	if not _corpse_landed and (contact.core_supports > 0 or _limb_support_age >= DEATH_LIMB_SUPPORT_DURATION - 0.00001):
		_corpse_landed = true
		_landing_age = 0.0
		ragdoll.set_physics_process(false)
		for body: PhysicalBone3D in ragdoll.bodies.values():
			# Leave room for the floor impulse to roll the body over a limb.
			body.set("maximum_angular_speed", DEATH_LANDING_ANGULAR_SPEED_LIMIT)
			# The source material supplies the first impacts. Godot's resting
			# contact phase uses an inelastic response to avoid repeated rebounds.
			if source_rig:
				body.bounce = 0.0
	if _corpse_landed:
		var supported: bool = contact.supports > 0
		if supported and source_rig and contact.core_supports == 0 and not is_instance_valid(_corpse_floor):
			# Keep Overworld gravity while the corpse is perched upright without core support.
			supported = absf(_corpse_axis().normalized().y) <= CORPSE_UPRIGHT_AXIS_Y
		_update_landing_forces(delta, sabre_finisher, supported, contact)
		_check_corpse_settled(delta, contact)

func _update_landing_forces(delta: float, sabre_finisher: bool, supported: bool, motion: Dictionary) -> void:
	var flat_floor := is_instance_valid(_corpse_floor) and not _corpse_floor.disabled
	if not supported and flat_floor:
		# The solver can omit contact for a frame while rolling close to the floor.
		supported = ragdoll.is_near_flat_floor(DEATH_FLOOR_CONTACT_MARGIN)
	var flat_sabre_finisher := flat_floor and sabre_finisher
	# The flat floor can support the roll immediately. Keep the extra
	# gravity hold for the finisher's bank and ledge contacts.
	var gravity_hold := SABRE_FINISHER_GRAVITY_HOLD if sabre_finisher and not flat_floor else 0.0
	var gravity_blend_end := gravity_hold + DEATH_LANDING_BLEND_TIME
	var landing_blend_end := maxf(gravity_blend_end, SABRE_ROLL_BLEND_END) if flat_sabre_finisher else gravity_blend_end
	var contact_age := minf(_landing_age + delta, landing_blend_end) if supported else 0.0
	# Add rolling resistance once the flat floor carries the slow, low pose.
	# The original response still drives the first impact and free flight.
	var damp_supported_roll: bool = flat_floor and not ragdoll.source_joints.is_empty() \
		and contact_age >= gravity_blend_end - 0.00001 and motion.supports >= 3 \
		and motion.core_supports > 0 and motion.leg_supported and motion.linear <= DEATH_LIMB_SUPPORT_MAX_SPEED \
		and absf(_corpse_axis().normalized().y) <= CORPSE_SETTLE_MAX_AXIS_Y
	var roll_weight := 1.0 if damp_supported_roll else 0.0
	if flat_sabre_finisher and not ragdoll.source_joints.is_empty():
		roll_weight = _sabre_roll_weight(delta, contact_age, motion, damp_supported_roll) if supported else 0.0
	var wall_gravity := _update_wall_brace(delta, motion)
	# A slow corpse propped on its upper body can take seconds for its
	# feet to come down. Restore some flight gravity until it rolls off.
	var braced: bool = flat_sabre_finisher and not ragdoll.source_joints.is_empty() \
		and contact_age >= gravity_blend_end - 0.00001 and _corpse_age >= SABRE_BRACE_MIN_AGE \
		and motion.core_supports > 0 and motion.supports == 2 and not motion.leg_supported
	var brace_target := 1.0 - smoothstep(0.6, 1.6, motion.linear) if braced else 0.0
	var flat_brace_weight := move_toward(_flat_brace_weight, brace_target, delta / SABRE_BRACE_BLEND_TIME)
	var late_roll_damping := 0.0
	if flat_sabre_finisher and contact_age >= DEATH_LANDING_BLEND_TIME and motion.leg_supported and motion.core_supports > 0:
		# Fade in more resistance during the slow final roll on the lab floor.
		var slow_roll := (1.0 - smoothstep(0.4, 1.5, motion.linear)) * smoothstep(0.60, 0.90, _corpse_age)
		var target := SABRE_LATE_ROLL_ANGULAR_DAMP * roll_weight * slow_roll
		var roll_gain := DEATH_SUPPORTED_ANGULAR_DAMP - DEATH_LANDING_ANGULAR_DAMP
		var damping_step := roll_gain * delta / SABRE_ROLL_RESPONSE_TIME
		# Share the existing ramp with the ordinary supported-roll damping.
		var head: PhysicalBone3D = ragdoll.bodies.Head
		var base_damping := lerpf(DEATH_LANDING_ANGULAR_DAMP, DEATH_SUPPORTED_ANGULAR_DAMP, roll_weight)
		late_roll_damping = minf(target, maxf(head.angular_damp + damping_step - base_damping, 0.0))
	if is_equal_approx(contact_age, _landing_age) and is_equal_approx(roll_weight, _roll_damping_weight) \
			and wall_gravity == _wall_gravity and is_equal_approx(flat_brace_weight, _flat_brace_weight) \
			and is_equal_approx(late_roll_damping, _late_roll_damping):
		return
	_landing_age = contact_age
	_roll_damping_weight = roll_weight
	_late_roll_damping = late_roll_damping
	_wall_gravity = wall_gravity
	_flat_brace_weight = flat_brace_weight
	var blend := smoothstep(0.0, DEATH_LANDING_BLEND_TIME, _landing_age)
	var gravity_blend := smoothstep(gravity_hold, gravity_blend_end, _landing_age)
	var flight_gravity_scale := _gravity_scale(ZOMBIE_GRAVITY)
	var gravity_scale := flight_gravity_scale if wall_gravity else lerpf(flight_gravity_scale, 1.0, gravity_blend)
	gravity_scale = lerpf(gravity_scale, flight_gravity_scale, _flat_brace_weight * SABRE_BRACE_GRAVITY_SHARE)
	ragdoll.floor_impact_blend = gravity_blend if flat_sabre_finisher else 0.0
	ragdoll.floor_landing_blended = not wall_gravity and is_equal_approx(gravity_blend, 1.0)
	var linear_damp := lerpf(_death_profile.linear_damping, DEATH_LANDING_LINEAR_DAMP, blend)
	var base_angular_damp := lerpf(_death_profile.angular_damping, DEATH_LANDING_ANGULAR_DAMP, blend)
	var angular_damp := lerpf(base_angular_damp, DEATH_SUPPORTED_ANGULAR_DAMP, roll_weight) + late_roll_damping
	for body: PhysicalBone3D in ragdoll.bodies.values():
		body.gravity_scale = gravity_scale * ragdoll_gravity_multiplier
		body.linear_damp = linear_damp
		body.angular_damp = angular_damp

func _sabre_roll_weight(delta: float, contact_age: float, motion: Dictionary, fully_supported: bool) -> float:
	var target := 0.0
	if fully_supported:
		target = 1.0
	elif motion.supports > 0 and contact_age > DEATH_LANDING_BLEND_TIME:
		# A low body starts to lose spin with its first support. More parts
		# touching the floor bring the roll gradually toward full resistance.
		var grounded := lerpf(0.15, 1.0, clampf((motion.supports - 1.0) / 3.0, 0.0, 1.0))
		var low := 1.0 - smoothstep(0.20, 0.45, absf(_corpse_axis().normalized().y))
		target = grounded * low * smoothstep(DEATH_LANDING_BLEND_TIME, SABRE_ROLL_BLEND_END, contact_age)
	return move_toward(_roll_damping_weight, target, delta / SABRE_ROLL_RESPONSE_TIME)

func _update_wall_brace(delta: float, motion: Dictionary) -> bool:
	if is_instance_valid(_corpse_floor) or ragdoll.source_joints.is_empty():
		return false
	var slow: bool = motion.linear <= CORPSE_SETTLE_SPEED and motion.angular <= CORPSE_SETTLE_SPIN
	# Wait until the corpse stalls against a wall with its weight outside its floor contacts.
	# Once it begins to tip, keep Overworld gravity until the brace releases.
	if (slow or _wall_gravity) and absf(_corpse_axis().normalized().y) > CORPSE_SETTLE_MAX_AXIS_Y \
			and ragdoll.is_braced_against_terrain():
		_wall_brace_age += delta
	else:
		_wall_brace_age = 0.0
	return _wall_brace_age >= CORPSE_SETTLE_TIME

static func _gravity_scale(acceleration: float) -> float:
	return acceleration / float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _corpse_axis() -> Vector3:
	var bodies := ragdoll.bodies
	var feet: Vector3 = (bodies["Leg.L"].global_position + bodies["Leg.R"].global_position) * 0.5
	return bodies.Head.global_position - feet

func _check_corpse_settled(delta: float, motion: Dictionary) -> void:
	var normally_supported := _has_rest_support(motion)
	_settled_seconds = _settled_seconds + delta if normally_supported else 0.0
	if _settled_seconds >= CORPSE_SETTLE_TIME or _check_terrain_rest(delta, motion, normally_supported):
		_queue_corpse_pose_capture()

func _has_rest_support(motion: Dictionary) -> bool:
	if not motion.leg_supported or motion.supports < 3 \
		or motion.linear > CORPSE_SETTLE_SPEED or motion.angular > CORPSE_SETTLE_SPIN:
		return false
	# A head-first hit can stall before the body falls over. On terraces,
	# compare the pose with the actual surface span between core and feet.
	var head_to_feet := _corpse_axis()
	var axis := head_to_feet.normalized()
	var near_horizontal := absf(axis.y) <= CORPSE_SETTLE_MAX_AXIS_Y
	# On the flat floor a near-horizontal corpse can rest on both legs and an arm.
	if motion.core_supports == 0 and (not near_horizontal or not ragdoll.has_flat_limb_support()):
		return false
	if near_horizontal:
		return true
	var span: Vector3 = motion.support_span
	var horizontal_span := Vector2(span.x, span.z).length()
	var support_up := Vector3.UP.slide(span.normalized()).normalized()
	return horizontal_span >= head_to_feet.length() * 0.5 and absf(axis.dot(support_up)) <= CORPSE_SETTLE_MAX_AXIS_Y

func _check_terrain_rest(delta: float, motion: Dictionary, normally_supported: bool) -> bool:
	var two_parts: bool = motion.supports == 2
	var flat_floor := is_instance_valid(_corpse_floor)
	var speed_scale := 1.0 if flat_floor else 0.5
	var slow_support: bool = not normally_supported and not ragdoll.source_joints.is_empty() \
		and motion.supports >= 2 \
		and motion.linear <= CORPSE_SETTLE_SPEED * speed_scale and motion.angular <= CORPSE_SETTLE_SPIN * speed_scale
	if slow_support:
		if flat_floor:
			# A wall can carry the upper body while the floor carries the
			# chest and legs, or both feet. Verify the pose stays put.
			slow_support = motion.leg_supported and (not two_parts or motion.core_supports == 0) \
				and ragdoll.has_flat_wall_rest_support(motion.core_supports > 0) \
				and ragdoll.max_anchor_error() <= Ragdoll.SOURCE_ANCHOR_TOLERANCE
		else:
			slow_support = motion.core_supports > 0 and (not two_parts or motion.leg_supported) \
				and ragdoll.terrain_support_margin(two_parts) > CORPSE_TERRAIN_SUPPORT_MARGIN
	if not slow_support:
		_terrain_rest_age = 0.0
		_terrain_rest_poses.clear()
		return false
	# Solver velocities can oscillate on a supported edge. Check that each
	# body stays near the same pose throughout the whole rest window.
	var duration := CORPSE_WALL_REST_TIME if flat_floor or two_parts else CORPSE_TERRAIN_REST_TIME
	var shift_limit := CORPSE_FLAT_WALL_REST_SHIFT if flat_floor else CORPSE_TERRAIN_REST_SHIFT
	var turn_limit := CORPSE_FLAT_WALL_REST_TURN if flat_floor else CORPSE_TERRAIN_REST_TURN
	var moved := false
	for name in _terrain_rest_poses:
		var body: PhysicalBone3D = ragdoll.bodies[name]
		var start := _terrain_rest_poses[name]
		var pose := body.global_transform
		if pose.origin.distance_to(start.origin) > shift_limit \
				or pose.basis.get_rotation_quaternion().angle_to(start.basis.get_rotation_quaternion()) > turn_limit:
			moved = true
			break
	if moved or _terrain_rest_poses.is_empty() or duration != _terrain_rest_duration:
		for name: String in ragdoll.bodies:
			_terrain_rest_poses[name] = ragdoll.bodies[name].global_transform
		_terrain_rest_duration = duration
		_terrain_rest_age = 0.0
		return false
	_terrain_rest_age += delta
	return _terrain_rest_age >= _terrain_rest_duration - 0.00001

func _queue_corpse_pose_capture() -> void:
	var skeleton := ragdoll.skeleton
	if not skeleton.skeleton_updated.is_connected(_capture_corpse_pose):
		skeleton.skeleton_updated.connect(_capture_corpse_pose, CONNECT_ONE_SHOT)

func _capture_corpse_pose() -> void:
	# Read the evaluated physical pose while the skeleton modifiers are applied.
	var skeleton := ragdoll.skeleton
	var pose: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		pose.append(skeleton.global_transform * skeleton.get_bone_global_pose(i))
	_park_corpse.call_deferred(pose)

func _park_corpse(pose: Array[Transform3D]) -> void:
	if not is_queued_for_deletion() and ragdoll.running:
		ragdoll.release(pose)
		_corpse_parked = true

static func _death_launch_speed(strength: float) -> float:
	var extra := 0.0
	for tier in DEATH_STRENGTH_THRESHOLDS.size():
		if strength < DEATH_STRENGTH_THRESHOLDS[tier]:
			break
		extra = DEATH_ADDITIONAL_MULTIPLIERS[tier]
	return DEATH_SOURCE_SPEED * DEATH_SPEED_TO_LAB * (1.0 + extra * DEATH_TIER_INFLUENCE)

func _death_spin(direction: Vector3) -> Vector3:
	var angular_scale := DEATH_AIR_ATTACK_ANGULAR_TO_LAB if _death_strike == DeathStrike.AIR else DEATH_ANGULAR_TO_LAB
	var speed := DEATH_SOURCE_ANGULAR_SCALE * angular_scale
	var spin := Vector3.UP.cross(direction) * speed
	if _death_strike != DeathStrike.AIR and _death_strength >= DEATH_STRENGTH_THRESHOLDS[1]:
		# An off-axis launch lets the grounded finisher roll onto its side.
		spin -= direction * DEATH_FINISHER_ROLL_SPEED
	if _death_rng.randf() < DEATH_TWIRL_CHANCE:
		spin.y = speed * (0.45 if _death_rng.randf() < 0.5 else -0.45)
	return spin

func _apply_death_tumble(spin: Vector3, mass: float) -> void:
	var centre := Vector3.ZERO
	for body: PhysicalBone3D in ragdoll.bodies.values():
		centre += body.global_position * body.mass
	centre /= mass
	# Start a shared rotation about the mass centre. Its tangential impulses
	# sum to zero, so this does not add another push along the strike.
	for body: PhysicalBone3D in ragdoll.bodies.values():
		body.apply_central_impulse(spin.cross(body.global_position - centre) * body.mass)
		body.angular_velocity += spin

func _update_corpse_material() -> void:
	if _mesh.material_override == null:
		if _corpse_base_material == null:
			var skin := _mesh.get_active_material(0) as StandardMaterial3D
			if skin == null:
				return
			_corpse_base_material = ShaderMaterial.new()
			_corpse_base_material.shader = CORPSE_SHADER
			_corpse_base_material.set_shader_parameter("skin", skin.albedo_texture)
		_mesh.material_override = _corpse_base_material
	var gray := smoothstep(CORPSE_DESATURATION_START, CORPSE_DESATURATION_END, _corpse_age) * 0.80
	_mesh.set_instance_shader_parameter("desaturation", gray)
	_corpse_color_finished = is_instance_valid(_corpse_floor) and _corpse_age >= CORPSE_DESATURATION_END

func _exit_tree() -> void:
	if is_instance_valid(ragdoll):
		ragdoll.release()
