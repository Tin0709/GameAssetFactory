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
# PlayDebrisEffect notifies in the MD2 walk sequences, with UE X offsets in metres.
const WALK_STEP_NOTIFIES := {
	&"Zombie_Walk": [Vector2(0.427282363, 0.20), Vector2(1.281282187, -0.20)],
	&"Zombie_Walk_Variant1": [Vector2(0.427282006, 0.20), Vector2(1.281281948, -0.20)],
	&"Zombie_Walk_Variant2": [Vector2(0.427282006, 0.20), Vector2(1.281281948, -0.20)],
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
const SABRE_GROUNDED_SLIDE_DRAG := 4.0
const SABRE_ROLL_BLEND_END := 0.35
const SABRE_BRACE_MIN_AGE := 0.82
const SABRE_CORNER_LANDING_MIN_AGE := 1.5
const SABRE_CORNER_LANDING_MAX_SPEED := 0.60
const SABRE_BRACE_GRAVITY_SHARE := 0.65
const SABRE_BRACE_BLEND_TIME := 0.10
const SABRE_ROLL_RESPONSE_TIME := 0.10
const DEATH_LANDING_ANGULAR_SPEED_LIMIT := 16.0
const HEIGHT := 1.95
const CHASE_SPEED := 3.1
# SW.Mob.Zombie specializes the hostile mob's AI attributes, with a 360°
# cone. The controller's generic engine sight defaults are broader.
const LAB_SIGHT_RADIUS_SQUARED := 10.0 * 10.0
const LAB_SIGHT_DELAY := 0.4
const LAB_SIGHT_LOSS_DELAY := 2.0
const LAB_CROWD_SIGHT_HZ := 15.0
const LAB_LAST_SEEN_STOP_DISTANCE := 0.10
const LAB_ROAM_RADIUS := 10.0
const LAB_ROAM_DELAY := 1.0
const LAB_ROAM_SPEED := 3.0
const LAB_ROAM_ARRIVAL := 0.10
const LAB_ROAM_BLOCKED_TIME := 0.25
const LAB_ROAM_MIN_PROGRESS_SPEED := LAB_ROAM_SPEED * 0.10
const LAB_ROAM_ATTEMPTS := 4
const CROWD_RETRY_MIN_ZOMBIES := 32
const BLOCKED_CHASE_RETRY_HZ := 30.0
const PACKED_WALK_RETRY_HZ := 15.0
const BLOCKED_WALK_MAX_SPEED_SQUARED := 0.01
const BLOCKER_MOVE_DISTANCE_SQUARED := 0.025 * 0.025
const WALK_DESTINATION_MOVE_DISTANCE_SQUARED := 0.10 * 0.10
const MELEE_RANGE := 1.36
const MELEE_RANGE_TOLERANCE := 0.025
# Zombie overrides damage and attack speed. MeleeAttackMob supplies the range,
# cone and cooldown. The Lab uses AM_Zombie_BasicAttack's section and notify.
const MELEE_DAMAGE := 6
const MELEE_REACH := 2.0
const MELEE_HEIGHT_LIMIT := 2.0
const MELEE_HALF_ANGLE_COS := 0.9659258263 # cos(30 degrees / 2).
const MELEE_COOLDOWN := 0.5
const TELEGRAPH_RATE := 1.5
const TELEGRAPH_END := 15.0 / 30.0
const LAB_ATTACK_HIT_SECTION := 13.0 / 30.0
const LAB_MELEE_MONTAGE_RATE := 1.1
const MELEE_CONTACT_TIME := 17.0 / 30.0
const LEVEL_COLLISION_MASK := 1
const CORPSE_COLLISION_LAYER := 8
const CORPSE_LIFETIME := 5.0
const CORPSE_DESATURATION_START := 2.3
const LAB_CORPSE_DESATURATION_START := 0.1 # DefaultHostile GA_Dissolve DesaturateDelay.
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
var _windup_target_start := Vector3.ZERO
var _target_visible := false
var _target_aggressive := false
var _sight_state_seconds := 0.0
var _last_seen_position := Vector3.ZERO
var _roam_origin := Vector3.ZERO
var _roam_destination := Vector3.INF
var _roam_wait := LAB_ROAM_DELAY
var _roam_blocked_seconds := 0.0
var _roam_rng := RandomNumberGenerator.new()
var _crowd_slot := 0
var _blocked_walk := false
var _blocking_zombie_id := 0
var _blocking_position := Vector3.ZERO
var _blocked_walk_destination := Vector3.ZERO
var _skipped_blocked_step := false
var _flash_left := 0.0
var _flash_pending := false
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
var _had_upper_body_brace := false
var _landing_gravity_sent := NAN
var _landing_linear_damp_sent := NAN
var _terrain_rest_age := 0.0
var _terrain_rest_duration := 0.0
var _terrain_rest_corner := false
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
	_roam_rng.seed = hash(Vector2i(serial, 4021))
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
	_roam_origin = global_position
	health = max_health
	animation.play(SPAWN)
	animation.advance(0)
	ragdoll = Ragdoll.new()
	ragdoll.wall_handoff_animation = animation
	ragdoll.wall_handoff_idle = IDLE
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
	# The first render delta includes time before the hit. Start the fade
	# after the full-strength frame that take_hit has already submitted.
	if _flash_pending:
		_flash_pending = false
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	var flash := smoothstep(0.0, HIT_FLASH_DURATION * 0.65, _flash_left)
	_mesh.set_instance_shader_parameter("hit_flash", flash)
	if _flash_left <= 0.0:
		_mesh.material_overlay = null
		set_process(false)

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
	var in_lab := is_instance_valid(_corpse_floor)
	var crowd := in_lab and get_parent().get_child_count() >= CROWD_RETRY_MIN_ZOMBIES
	var sample_ai := true
	if crowd:
		var stride := maxi(1, roundi(Engine.physics_ticks_per_second / LAB_CROWD_SIGHT_HZ))
		sample_ai = Engine.get_physics_frames() % stride == _crowd_slot % stride
	if in_lab:
		_update_target_sight(delta, sample_ai)
	var controlled_time := maxf(0.0, delta - _knockback_control_left)
	_knockback_control_left = maxf(0.0, _knockback_control_left - delta)
	var pushed := not _knockback.is_zero_approx()
	var travel := _integrate_knockback(delta)
	if controlled_time > 0.000001:
		travel += _chase_velocity(controlled_time, in_lab, sample_ai) * (controlled_time / delta)
	velocity.x = travel.x
	velocity.z = travel.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * _gravity_scale(ZOMBIE_GRAVITY) * delta
	var crowd_walking := crowd and not pushed and controlled_time == delta and not travel.is_zero_approx() \
		and animation.current_animation in WALK_CLIPS
	var destination := _last_seen_position if _target_aggressive else _roam_destination
	_skipped_blocked_step = false
	if crowd_walking and _blocked_walk and is_on_floor() and (_target_aggressive or _blocking_zombie_id != 0):
		# Spread collision retries across zombies. Keep animation and pose history
		# on the full physics clock, including frames without a movement query.
		_skipped_blocked_step = _wait_for_walk_retry(destination)
	if not _skipped_blocked_step:
		move_and_slide()
		_blocked_walk = crowd_walking and is_on_floor() and is_on_wall() \
			and get_real_velocity().slide(Vector3.UP).length_squared() < BLOCKED_WALK_MAX_SPEED_SQUARED
		_update_walk_blocker(destination)
	_advance_animation(delta)
	ragdoll.sample(delta)

func _wait_for_walk_retry(destination: Vector3) -> bool:
	var retry_hz := BLOCKED_CHASE_RETRY_HZ
	if _blocking_zombie_id != 0:
		var blocker := instance_from_id(_blocking_zombie_id) as CharacterBody3D
		if (blocker == null or blocker.is_queued_for_deletion() or blocker.collision_layer == 0
				or blocker.global_position.distance_squared_to(_blocking_position) > BLOCKER_MOVE_DISTANCE_SQUARED
				or destination.distance_squared_to(_blocked_walk_destination) > WALK_DESTINATION_MOVE_DISTANCE_SQUARED):
			return false
		retry_hz = PACKED_WALK_RETRY_HZ
	var stride := maxi(1, roundi(Engine.physics_ticks_per_second / retry_hz))
	return Engine.get_physics_frames() % stride != _crowd_slot % stride

func _update_walk_blocker(destination: Vector3) -> void:
	if not _blocked_walk or get_slide_collision_count() == 0:
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
	# Retry when the destination changes, including on a new sighting.
	_blocked_walk_destination = destination

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
		var play_steps := (step_audio.has_connections() and clip in WALK_STEP_NOTIFIES and is_on_floor()
			and not _skipped_blocked_step and get_real_velocity().slide(Vector3.UP).length_squared() >= STEP_MIN_SPEED_SQUARED)
		var previous_phase := animation.current_animation_position if play_steps else 0.0
		animation.advance(delta)
		if play_steps:
			_emit_walk_step(clip, previous_phase)
		return
	var before := animation.current_animation_position
	var lab := is_instance_valid(_corpse_floor)
	var montage_rate := LAB_MELEE_MONTAGE_RATE if lab else 1.0
	var hit_section := LAB_ATTACK_HIT_SECTION if lab else TELEGRAPH_END
	var windup_rate := TELEGRAPH_RATE * montage_rate
	var telegraph_seconds := clampf((hit_section - before) / windup_rate, 0.0, delta)
	if lab and telegraph_seconds > 0.0 and _target_visible:
		var target_position := _last_seen_position
		var target_travel := target_position - _windup_target_start
		# Keep the entry heading for a stationary target. AN_FocusOnTarget
		# disables any tracking at the start of Attack_Hit.
		if Vector2(target_travel.x, target_travel.z).length_squared() > 0.0001:
			_face_target(target_position - global_position, telegraph_seconds)
	var advance_seconds := telegraph_seconds * windup_rate + (delta - telegraph_seconds) * montage_rate
	animation.advance(advance_seconds)
	if before < MELEE_CONTACT_TIME and before + advance_seconds >= MELEE_CONTACT_TIME:
		_check_melee_contact()

func _emit_walk_step(clip: StringName, previous_phase: float) -> void:
	var phase := animation.current_animation_position
	var wrapped := phase < previous_phase
	for contact: Vector2 in WALK_STEP_NOTIFIES[clip]:
		var at := contact.x
		var crossed := (at > previous_phase or at <= phase) if wrapped else (at > previous_phase and at <= phase)
		if crossed:
			step_audio.emit(to_global(Vector3(contact.y, 0.0, 0.0)))

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
	if _clear_sight_to(target.global_position):
		melee_audio.emit(global_position + height, true)
		melee_hit.emit(MELEE_DAMAGE)

func _clear_sight_to(point: Vector3) -> bool:
	var height := Vector3.UP * (HEIGHT * 0.5)
	var ray := PhysicsRayQueryParameters3D.create(global_position + height, point + height, LEVEL_COLLISION_MASK)
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _update_target_sight(delta: float, sample_ai: bool) -> void:
	if target.get("is_dead") == true:
		if _target_aggressive:
			_reset_roam()
		_target_visible = false
		_target_aggressive = false
		_sight_state_seconds = 0.0
		return
	var point := target.global_position
	if global_position.distance_squared_to(point) > LAB_SIGHT_RADIUS_SQUARED:
		_target_visible = false
	elif sample_ai:
		_target_visible = _clear_sight_to(point)
		if _target_visible:
			_last_seen_position = point
	if _target_visible == _target_aggressive:
		_sight_state_seconds = 0.0
	else:
		_sight_state_seconds += delta
		var delay := LAB_SIGHT_DELAY if _target_visible else LAB_SIGHT_LOSS_DELAY
		if _sight_state_seconds >= delay - 0.000001:
			_target_aggressive = _target_visible
			_sight_state_seconds = 0.0
			_reset_roam()

func _reset_roam() -> void:
	_roam_destination = Vector3.INF
	_roam_wait = LAB_ROAM_DELAY
	_roam_blocked_seconds = 0.0

func _roam_velocity(delta: float, sample_ai: bool) -> Vector3:
	if not is_on_floor() or _corpse_floor.disabled:
		_play_loop(IDLE)
		return Vector3.ZERO
	if not _roam_destination.is_finite():
		_roam_wait = maxf(0.0, _roam_wait - delta)
		if sample_ai and _roam_wait <= 0.000001:
			_roam_destination = _pick_roam_destination()
			if not _roam_destination.is_finite():
				_reset_roam()
		if not _roam_destination.is_finite():
			_play_loop(IDLE)
			return Vector3.ZERO
	var offset := (_roam_destination - global_position).slide(Vector3.UP)
	var distance := offset.length()
	# A wall slide can have speed without making meaningful progress to the goal.
	var stalled := is_on_wall() and get_real_velocity().dot(offset) < LAB_ROAM_MIN_PROGRESS_SPEED * distance
	_roam_blocked_seconds = _roam_blocked_seconds + delta if stalled else 0.0
	if distance <= LAB_ROAM_ARRIVAL or _roam_blocked_seconds >= LAB_ROAM_BLOCKED_TIME:
		_reset_roam()
		_play_loop(IDLE)
		return Vector3.ZERO
	_face_target(offset, delta)
	_play_loop(_walk_clip)
	return offset * (minf(LAB_ROAM_SPEED, (distance - LAB_ROAM_ARRIVAL) / delta) / distance)

func _pick_roam_destination() -> Vector3:
	# Keep the capsule inside the flat Lab floor and test the body along
	# each proposed leg. A chest ray can clear low or narrow obstacles.
	var bounds := _corpse_floor.shape as BoxShape3D
	if bounds == null:
		return Vector3.INF
	var extent := bounds.size * 0.5 - Vector3.ONE * _live_capsule.radius
	var space := get_world_3d().direct_space_state
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = _live_capsule
	sweep.collision_mask = LEVEL_COLLISION_MASK
	sweep.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (HEIGHT * 0.5))
	# The support plane already bounds the patrol. Other terrain still
	# participates in both the sweep and the destination overlap check.
	var floor_body := _corpse_floor.get_parent() as StaticBody3D
	if floor_body != null:
		sweep.exclude = [floor_body.get_rid()]
	for i in LAB_ROAM_ATTEMPTS:
		var angle := _roam_rng.randf_range(0.0, TAU)
		var radius := sqrt(_roam_rng.randf()) * LAB_ROAM_RADIUS
		var point := _roam_origin + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var local := _corpse_floor.to_local(point)
		local.x = clampf(local.x, -extent.x, extent.x)
		local.z = clampf(local.z, -extent.z, extent.z)
		point = _corpse_floor.to_global(local)
		var travel := (point - global_position).slide(Vector3.UP)
		if travel.length_squared() <= 1.0:
			continue
		sweep.motion = travel
		var fractions := space.cast_motion(sweep)
		if fractions.is_empty() or fractions[0] < 1.0:
			continue
		var start := sweep.transform
		sweep.transform = start.translated(travel)
		if space.intersect_shape(sweep, 1).is_empty():
			return point
		sweep.transform = start
	return Vector3.INF

func _is_in_melee_cone(planar_offset: Vector3) -> bool:
	return global_basis.z.dot(planar_offset) >= planar_offset.length() * MELEE_HALF_ANGLE_COS

func _face_target(offset: Vector3, delta: float) -> void:
	if Vector2(offset.x, offset.z).length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), minf(delta * 10.0, 1.0))

func _chase_velocity(delta: float, in_lab: bool, sample_ai: bool) -> Vector3:
	if animation.current_animation in [SPAWN, ATTACK, STAGGER]:
		return Vector3.ZERO
	if in_lab and not _target_aggressive:
		return _roam_velocity(delta, sample_ai)
	if not in_lab and target.get("is_dead") == true:
		_play_loop(IDLE)
		return Vector3.ZERO
	var target_visible := not in_lab or _target_visible
	var point := _last_seen_position if in_lab else target.global_position
	var offset := point - global_position
	var height_delta := absf(offset.y)
	offset.y = 0.0
	var distance := offset.length()
	_face_target(offset, delta)
	var stop_distance := MELEE_RANGE if target_visible else LAB_LAST_SEEN_STOP_DISTANCE
	if distance > stop_distance + MELEE_RANGE_TOLERANCE:
		_play_loop(_walk_clip)
		return offset.normalized() * minf(CHASE_SPEED, (distance - stop_distance) / delta)
	# Complete the approach turn before locking the swing's heading.
	var facing_target := _is_in_melee_cone(offset)
	if target_visible and height_delta <= MELEE_HEIGHT_LIMIT and facing_target and _attack_cooldown <= 0.0:
		var target_position := target.global_position
		if in_lab and not sample_ai and not _confirm_windup_target(target_position):
			_play_loop(IDLE)
			return Vector3.ZERO
		_windup_target_start = target_position
		animation.play(ATTACK, 0.1)
		_attack_cooldown = MELEE_COOLDOWN
		melee_audio.emit(global_position + Vector3.UP * (HEIGHT * 0.5), false)
	else:
		_play_loop(IDLE)
	return Vector3.ZERO

func _confirm_windup_target(point: Vector3) -> bool:
	# Crowd sight runs on a staggered clock. The current target must still
	# be in reach and in front before this tick can commit the windup.
	var offset := point - global_position
	if absf(offset.y) > MELEE_HEIGHT_LIMIT:
		return false
	offset.y = 0.0
	if offset.length_squared() > (MELEE_RANGE + MELEE_RANGE_TOLERANCE) ** 2 or not _is_in_melee_cone(offset):
		return false
	_target_visible = _clear_sight_to(point)
	if _target_visible:
		_last_seen_position = point
	return _target_visible

func _play_loop(clip: StringName) -> void:
	if animation.current_animation != clip:
		animation.play(clip, 0.13)

func take_hit(amount: int, direction: Vector3, launch_impulse: Vector2 = DEFAULT_DEATH_IMPULSE,
		stagger: float = MAX_POISE, knockback_strength: float = 500.0, death_strike := DeathStrike.GROUND,
		push_duration := 0.0) -> void:
	if health <= 0 or amount <= 0:
		return
	_blocked_walk = false
	health = maxi(0, health - amount)
	direction.y = 0.0
	direction = direction.normalized()
	_feedback.show_hit(amount, health, max_health)
	_mesh.material_overlay = _flash_material
	_mesh.set_instance_shader_parameter("hit_flash", 1.0)
	_flash_left = HIT_FLASH_DURATION
	_flash_pending = true
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
	if not _corpse_color_finished:
		var fade_start := LAB_CORPSE_DESATURATION_START if is_instance_valid(_corpse_floor) else CORPSE_DESATURATION_START
		if _corpse_age >= fade_start - 0.00001:
			_update_corpse_material(fade_start)
	if _corpse_parked:
		return
	var sabre_finisher := _death_strike == DeathStrike.SABRE_FINISHER
	var source_rig := not ragdoll.source_joints.is_empty()
	if not ragdoll.running:
		ragdoll.prepare_handoff_samples(delta, is_instance_valid(_corpse_floor))
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
		var angle := deg_to_rad(DEATH_LAUNCH_ANGLE)
		var launch_impulse := _death_launch_speed(_death_strength) * mass * ragdoll_launch_multiplier
		var direction := Vector3.FORWARD if _death_direction.is_zero_approx() else _death_direction
		var floor_impact_limb_share := 0.0
		if sabre_finisher:
			floor_impact_limb_share = SABRE_FINISHER_FLOOR_LIMB_SHARE
		elif _death_strike == DeathStrike.SABRE_GROUND:
			floor_impact_limb_share = SABRE_GROUND_FLOOR_LIMB_SHARE
		var flight_gravity := ZOMBIE_GRAVITY * ragdoll_gravity_multiplier
		if ragdoll.begin(_death_profile, direction, "Chest", 0.0, flight_gravity,
				_corpse_floor, floor_impact_limb_share, sabre_finisher, cos(angle) * launch_impulse, sin(angle) * launch_impulse):
			_apply_death_tumble(_death_spin(direction), mass)
		return
	var contact := ragdoll.contact_motion()
	if not _corpse_landed:
		# On a terrace, limbs can carry the body before the core reaches a surface.
		# Require sustained support so a brief grazing hit keeps its flight response.
		var limbs_supporting: bool = contact.supports >= 2 and contact.linear < DEATH_LIMB_SUPPORT_MAX_SPEED
		# An upright corpse can stop on one foot when the corner carries its
		# upper body. Give it the same sustained-support landing transition.
		if not limbs_supporting and sabre_finisher and source_rig and is_instance_valid(_corpse_floor) \
				and not _corpse_floor.disabled and _corpse_age >= SABRE_CORNER_LANDING_MIN_AGE \
				and contact.supports == 1 and contact.leg_supported \
				and contact.linear < SABRE_CORNER_LANDING_MAX_SPEED and contact.angular < CORPSE_SETTLE_SPIN:
			limbs_supporting = ragdoll.has_flat_corner_brace()
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
	if flat_sabre_finisher and damp_supported_roll and roll_weight > 0.9 and not _had_upper_body_brace:
		# Keep the existing fall from an upper-body brace through its roll.
		var drag := smoothstep(0.78, 1.00, _corpse_age) * (1.0 - smoothstep(0.9, 2.0, motion.linear))
		if drag > 0.0:
			_resist_grounded_slide(drag * SABRE_GROUNDED_SLIDE_DRAG)
	var wall_gravity := _update_wall_brace(delta, motion)
	# A slow corpse propped on its upper body can take seconds for its
	# feet to come down. Restore some flight gravity until it rolls off.
	var braced: bool = flat_sabre_finisher and not ragdoll.source_joints.is_empty() \
		and contact_age >= gravity_blend_end - 0.00001 and _corpse_age >= SABRE_BRACE_MIN_AGE \
		and motion.core_supports > 0 and motion.supports == 2 and not motion.leg_supported
	_had_upper_body_brace = _had_upper_body_brace or braced
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
	var final_gravity := gravity_scale * ragdoll_gravity_multiplier
	# The six Lab bodies receive the same values. Roll damping can keep
	# changing after these channels have finished their landing blend.
	# GodotPhysics can wake a body when its old gravity is near zero.
	var write_gravity := not flat_floor or final_gravity != _landing_gravity_sent or is_zero_approx(final_gravity)
	var write_linear_damp := not flat_floor or linear_damp != _landing_linear_damp_sent
	for body: PhysicalBone3D in ragdoll.bodies.values():
		if write_gravity:
			body.gravity_scale = final_gravity
		if write_linear_damp:
			body.linear_damp = linear_damp
		body.angular_damp = angular_damp
	_landing_gravity_sent = final_gravity
	_landing_linear_damp_sent = linear_damp

func _resist_grounded_slide(drag: float) -> void:
	# A uniform horizontal acceleration opposes whole-body drift. Leave
	# the downward motion and the relative motion at each joint to the solver.
	var momentum := Vector3.ZERO
	var mass := 0.0
	for body: PhysicalBone3D in ragdoll.bodies.values():
		momentum += body.linear_velocity * body.mass
		mass += body.mass
	momentum.y = 0.0
	var acceleration := -momentum * (drag / mass)
	if acceleration.length_squared() <= 0.0001:
		return
	for body: PhysicalBone3D in ragdoll.bodies.values():
		PhysicsServer3D.body_apply_central_force(body.get_rid(), acceleration * body.mass)

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
	var intermittent_foot: bool = flat_floor and _death_strike == DeathStrike.SABRE_FINISHER \
		and motion.supports == 1 and motion.leg_supported
	var slow_support: bool = not normally_supported and not ragdoll.source_joints.is_empty() \
		and (motion.supports >= 2 or intermittent_foot) \
		and motion.linear <= CORPSE_SETTLE_SPEED * speed_scale and motion.angular <= CORPSE_SETTLE_SPIN * speed_scale
	var corner_support := false
	if slow_support:
		if flat_floor:
			# A wall can carry the upper body while the floor carries the
			# chest and legs, or both feet. Verify the pose stays put.
			slow_support = motion.leg_supported and (not two_parts or motion.core_supports == 0)
			if slow_support and intermittent_foot:
				slow_support = ragdoll.has_wall_rest_with_near_foot()
				# Two wall faces can carry the torso even with the second leg
				# off the floor. Require the tighter terrain pose envelope.
				corner_support = not slow_support and not _corpse_floor.disabled \
					and _corpse_age >= SABRE_CORNER_LANDING_MIN_AGE \
					and ragdoll.floor_landing_blended and ragdoll.has_flat_corner_brace()
				slow_support = slow_support or corner_support
			elif slow_support:
				slow_support = ragdoll.has_flat_wall_rest_support(motion.core_supports > 0)
			slow_support = slow_support and ragdoll.max_anchor_error() <= Ragdoll.SOURCE_ANCHOR_TOLERANCE
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
	var flat_wall_support := flat_floor and not corner_support
	var shift_limit := CORPSE_FLAT_WALL_REST_SHIFT if flat_wall_support else CORPSE_TERRAIN_REST_SHIFT
	var turn_limit := CORPSE_FLAT_WALL_REST_TURN if flat_wall_support else CORPSE_TERRAIN_REST_TURN
	var moved := false
	for name in _terrain_rest_poses:
		var body: PhysicalBone3D = ragdoll.bodies[name]
		var start := _terrain_rest_poses[name]
		var pose := body.global_transform
		if pose.origin.distance_to(start.origin) > shift_limit \
				or pose.basis.get_rotation_quaternion().angle_to(start.basis.get_rotation_quaternion()) > turn_limit:
			moved = true
			break
	if moved or _terrain_rest_poses.is_empty() or duration != _terrain_rest_duration or corner_support != _terrain_rest_corner:
		for name: String in ragdoll.bodies:
			_terrain_rest_poses[name] = ragdoll.bodies[name].global_transform
		_terrain_rest_duration = duration
		_terrain_rest_corner = corner_support
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

func _update_corpse_material(fade_start: float) -> void:
	if _mesh.material_override == null:
		if _corpse_base_material == null:
			var skin := _mesh.get_active_material(0) as StandardMaterial3D
			if skin == null:
				return
			_corpse_base_material = ShaderMaterial.new()
			_corpse_base_material.shader = CORPSE_SHADER
			_corpse_base_material.set_shader_parameter("skin", skin.albedo_texture)
		_mesh.material_override = _corpse_base_material
	var gray := smoothstep(fade_start, CORPSE_DESATURATION_END, _corpse_age) * 0.80
	_mesh.set_instance_shader_parameter("desaturation", gray)
	_corpse_color_finished = is_instance_valid(_corpse_floor) and _corpse_age >= CORPSE_DESATURATION_END

func _exit_tree() -> void:
	if is_instance_valid(ragdoll):
		ragdoll.release()
