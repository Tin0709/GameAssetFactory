extends CharacterBody3D

signal melee_hit(amount: int)
signal living_changed(alive: bool)
signal step_audio(point: Vector3)
signal idle_audio(point: Vector3)
signal swing_audio(point: Vector3)

enum DeathStrike { GROUND, AIR, SABRE_FINISHER, SABRE_GROUND }
signal melee_audio(point: Vector3, contact: bool)

const Feedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const HealthBars := preload("res://scripts/mechanic_lab_health_bars.gd")
const DamageNumbers := preload("res://scripts/mechanic_lab_damage_numbers.gd")
const Ragdoll := preload("res://scripts/mechanic_lab_ragdoll.gd")
const Gait := preload("res://scripts/mechanic_lab_zombie_gait.gd")
const DeathProfile := preload("res://scenes/dev/zombie_death_physics/death_profile.gd")
const CORPSE_SHADER := preload("res://materials/mechanic_lab_zombie_corpse.gdshader")
const LAB_SKIN_SHADER := preload("res://materials/mechanic_lab_zombie_skin.gdshader")
const LAB_SKIN_FLASH_SHADER := preload("res://materials/mechanic_lab_zombie_skin_flash.gdshader")
const LAB_FLASH_SKIN_META := &"lab_flash_skin"
const HIT_FLASH_SHADER := preload("res://materials/mechanic_lab_zombie_hit_flash.gdshader")
const IDLE := &"Zombie_Idle"
const ActionsStuff := preload("res://scripts/mechanic_lab_zombie_actions_stuff.gd")
const IDLE_AUDIO_NOTIFY_TIME := 0.066887535
const IDLE_AUDIO_CHANCE := 0.5
const WALK_CLIPS := [&"Zombie_Walk", &"Zombie_Walk_Variant1", &"Zombie_Walk_Variant2"]
const CHASE_SPEED := 3.1
const LAB_ROAM_SPEED := 3.0
const EXPRESSIVE_WALK_REACH := 0.5 * LAB_ROAM_SPEED * Gait.WALK_DURATION * Gait.WALK_SUPPORT
const EXPRESSIVE_RUN_REACH := 0.5 * CHASE_SPEED * Gait.RUN_DURATION * Gait.RUN_SUPPORT
# PlayDebrisEffect notifies store phase in seconds and lateral/forward offsets in metres.
const WALK_STEP_NOTIFIES := {
	&"Zombie_Walk": [Vector3(0.427282363, 0.20, 0.0), Vector3(1.281282187, -0.20, 0.0)],
	&"Zombie_Walk_Variant1": [Vector3(0.427282006, 0.20, 0.0), Vector3(1.281281948, -0.20, 0.0)],
	&"Zombie_Walk_Variant2": [Vector3(0.427282006, 0.20, 0.0), Vector3(1.281281948, -0.20, 0.0)],
	Gait.WALK: [Vector3(Gait.PLANT * Gait.WALK_DURATION, 0.125, EXPRESSIVE_WALK_REACH),
		Vector3((Gait.PLANT + 0.5) * Gait.WALK_DURATION, -0.125, EXPRESSIVE_WALK_REACH)],
	Gait.RUN: [Vector3(Gait.PLANT * Gait.RUN_DURATION, 0.125, EXPRESSIVE_RUN_REACH),
		Vector3((Gait.PLANT + 0.5) * Gait.RUN_DURATION, -0.125, EXPRESSIVE_RUN_REACH)],
	# Source stride touchdown near 0.30 s left and 0.73 s right.
	ActionsStuff.MOVE: [Vector3(0.30, 0.125, 0.24), Vector3(0.73, -0.125, 0.16)],
}
const STEP_MIN_SPEED_SQUARED := 0.15 * 0.15
const SPAWN := &"Zombie_Spawn"
const PREPARED_SPAWN_POSE := &"lab_spawn_pose_prepared"
const ATTACK := &"Zombie_BasicAttack"
const STAGGER := &"Zombie_Staggered"
const BASE_HEALTH := 8
const TRAINING_HEALTH := 48
const BABY_HEIGHT := 1.125
const BABY_SPEED := 8.5
const BABY_SIGHT_RADIUS_SQUARED := 15.0 * 15.0
const BABY_MELEE_DAMAGE := 5
const BABY_MELEE_REACH := 1.5
const BABY_MELEE_APPROACH := 1.02
const BABY_MAX_POISE := 50.0
const BABY_ATTACK_RATE := 1.1
const BABY_DEATH_LAUNCH_SCALE := 0.85
# Local contact and focus markers derived from the leading hand's swing.
const BABY_ATTACK_CONTACT := 20.0 / 30.0
const BABY_ATTACK_FOCUS_END := 18.0 / 30.0
# First source frames within 5 mm of the floor and the centres of those sole edges.
const BABY_STEP_CONTACTS := [Vector3(2.0 / 30.0, -0.117, 0.116), Vector3(8.0 / 30.0, 0.102, 0.083)]
const BABY_STEP_PHASE_TOLERANCE := 0.000001
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
const SABRE_LOW_ROLL_MAX_AXIS_Y := 0.45
const SABRE_BRACE_MIN_AGE := 0.82
const WALL_BRACE_MIN_AGE := 1.5
const SABRE_CORNER_LANDING_MAX_SPEED := 0.60
const SABRE_BRACE_GRAVITY_SHARE := 0.65
const SABRE_BRACE_LIMB_SPEED_SHARE := 0.60
const SABRE_SUSPENDED_DESCENT_MIN_AGE := 0.88
const SABRE_SUSPENDED_DESCENT_MAX_SPEED := 1.50
const SABRE_SUSPENDED_DESCENT_MIN_FALL_SPEED := 0.08
const SABRE_SUSPENDED_DESCENT_GRAVITY_SHARE := 0.33
const SABRE_BRACE_BLEND_TIME := 0.10
const SABRE_ROLL_RESPONSE_TIME := 0.10
const DEATH_LANDING_ANGULAR_SPEED_LIMIT := 16.0
const HEIGHT := 1.95
# SW.Mob.Zombie specializes the hostile mob's AI attributes, with a 360°
# cone. The controller's generic engine sight defaults are broader.
const LAB_SIGHT_RADIUS_SQUARED := 10.0 * 10.0
const LAB_SIGHT_DELAY := 0.4
const LAB_SIGHT_LOSS_DELAY := 2.0
const LAB_CROWD_SIGHT_HZ := 15.0
const LAB_LAST_SEEN_STOP_DISTANCE := 0.10
const LAB_ROAM_RADIUS := 10.0
const LAB_ROAM_DELAY := 1.0
const LAB_WAYPOINT_ARRIVAL := 0.10
const LAB_WALL_STALL_TIME := 0.25
const MIN_WALL_PROGRESS_SPEED := LAB_ROAM_SPEED * 0.10
const LAB_ROAM_ATTEMPTS := 4
const LAB_DETOUR_LENGTH := 3.0
const LAB_DETOUR_MIN_LENGTH := 0.6
const LAB_DETOUR_TIMEOUT := 1.4
const LAB_DETOUR_WALL_CLEARANCE := 0.035
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
const LIVING_ZOMBIE_LAYER := 4
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
var health := TRAINING_HEALTH:
	set(value):
		var was_alive := health > 0
		health = value
		var alive := health > 0
		if alive != was_alive:
			living_changed.emit(alive)
var is_baby := false
var expressive_gait := false
var actions_stuff_animation := false
var _body_height := HEIGHT
var _chase_speed := CHASE_SPEED
var _roam_speed := LAB_ROAM_SPEED
var _sight_radius_squared := LAB_SIGHT_RADIUS_SQUARED
var _sight_delay := LAB_SIGHT_DELAY
var _melee_approach := MELEE_RANGE
var _melee_reach := MELEE_REACH
var _melee_damage := MELEE_DAMAGE
var _max_poise := MAX_POISE
var _knockback_resistance := 1.0
var _attack_contact := MELEE_CONTACT_TIME
var _attack_focus_end := LAB_ATTACK_HIT_SECTION
var _telegraph_rate := TELEGRAPH_RATE
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
var _chase_detour := Vector3.INF
var _chase_detour_time := 0.0
var _partial_detour_origin := Vector3.INF
var _partial_detour_target := Vector3.INF
var _chase_detour_around_zombie := false
var _chase_stalled_seconds := 0.0
var _roam_origin := Vector3.ZERO
var _roam_destination := Vector3.INF
var _roam_wait := LAB_ROAM_DELAY
var _roam_blocked_seconds := 0.0
var _roam_rng := RandomNumberGenerator.new()
var _stationary_gait_phase := -1.0
var _idle_audio_index := 0
var _idle_audio_phase := 0.0
var _idle_audio_period := 0.0
var _crowd_slot := 0
var _blocked_walk := false
var _blocking_zombie_id := 0
var _blocking_position := Vector3.ZERO
var _blocking_peer_id := 0
var _blocking_peer_position := Vector3.ZERO
var _repeated_blocking_pair := false
var _blocked_walk_destination := Vector3.ZERO
var _skipped_blocked_step := false
var _flash_left := 0.0
var _flash_pending := false
var _lab_skin: ShaderMaterial
var _lab_flash_skin: ShaderMaterial
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
var _wall_descent_weight := 0.0
var _wall_descent_unsupported_age := 0.0
var _wall_gravity := false
var _flat_brace_weight := 0.0
var _had_upper_body_brace := false
var _landing_gravity_sent := NAN
var _landing_linear_damp_sent := NAN
var _wall_landing_age := 0.0
var _wall_landing_chest: Transform3D
var _wall_landing_head: Transform3D
var _terrain_rest_age := 0.0
var _terrain_rest_duration := 0.0
var _terrain_rest_strict := false
var _terrain_rest_poses: Dictionary[String, Transform3D]
var _ragdoll_layout: Dictionary
var _corpse_floor: CollisionShape3D
static var _flash_material: ShaderMaterial
static var _death_profile: DeathProfile
static var _baby_death_profile: DeathProfile
static var _corpse_base_material: ShaderMaterial
var _live_capsule: CapsuleShape3D
static var _adult_capsule: CapsuleShape3D
static var _baby_capsule: CapsuleShape3D
# These main-thread queries run synchronously and store no results.
static var _sight_ray: PhysicsRayQueryParameters3D
static var _lab_path_sweep: PhysicsShapeQueryParameters3D

static func prepare_lab_skin(model: Node, mesh_name := "SK_Zombie") -> void:
	var mesh := model.find_child(mesh_name, true, false) as MeshInstance3D
	var skin := mesh.get_active_material(0) as StandardMaterial3D if mesh != null else null
	if skin == null or skin.albedo_texture == null:
		return
	# Pack the same material for the living and ragdoll states.
	var material := ShaderMaterial.new()
	material.shader = LAB_SKIN_SHADER
	material.set_shader_parameter("living_skin", skin.albedo_texture)
	material.set_shader_parameter("corpse_skin", skin.albedo_texture)
	if RenderingServer.get_current_rendering_method() == &"mobile":
		var flash := ShaderMaterial.new()
		flash.shader = LAB_SKIN_FLASH_SHADER
		flash.set_shader_parameter("living_skin", skin.albedo_texture)
		flash.set_shader_parameter("corpse_skin", skin.albedo_texture)
		material.set_meta(LAB_FLASH_SKIN_META, flash)
	mesh.material_override = material

func configure(model: Node, player: CharacterBody3D, effects: Node3D, digits: Array[Texture2D],
		serial: int, ragdoll_layout: Dictionary = {}, corpse_floor: CollisionShape3D = null,
		health_bars: HealthBars = null, damage_numbers: DamageNumbers = null, baby := false) -> void:
	is_baby = baby
	if is_baby:
		_body_height = BABY_HEIGHT
		_chase_speed = BABY_SPEED
		_roam_speed = BABY_SPEED
		_sight_radius_squared = BABY_SIGHT_RADIUS_SQUARED
		_sight_delay = 0.0 # DefaultHostile acquisition delay.
		_melee_approach = BABY_MELEE_APPROACH
		_melee_reach = BABY_MELEE_REACH
		_melee_damage = BABY_MELEE_DAMAGE
		_max_poise = BABY_MAX_POISE
		_poise = _max_poise
		_knockback_resistance = 2.0
		_attack_contact = BABY_ATTACK_CONTACT
		_attack_focus_end = BABY_ATTACK_FOCUS_END
		_telegraph_rate = BABY_ATTACK_RATE
	target = player
	_ragdoll_layout = ragdoll_layout
	_corpse_floor = corpse_floor
	_crowd_slot = serial
	_death_rng.seed = hash(Vector2i(serial, 1709))
	_roam_rng.seed = hash(Vector2i(serial, 4021))
	_walk_clip = WALK_CLIPS[0 if is_baby else serial % WALK_CLIPS.size()]
	add_child(model)
	animation = model.get_node("AnimationPlayer")
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_mesh = model.find_child("SK_BabyZombie" if is_baby else "SK_Zombie", true, false)
	var skin := _mesh.material_override as ShaderMaterial if _mesh != null else null
	if skin != null and skin.has_meta(LAB_FLASH_SKIN_META):
		_lab_skin = skin
		_lab_flash_skin = skin.get_meta(LAB_FLASH_SKIN_META) as ShaderMaterial
	_feedback = Feedback.new()
	_feedback.digits = digits
	_feedback.effects = effects
	_feedback.health_bars = health_bars
	_feedback.damage_numbers = damage_numbers
	_feedback.position.y = _body_height - HEIGHT
	add_child(_feedback)
	if is_baby and _baby_capsule == null:
		_baby_capsule = CapsuleShape3D.new()
		_baby_capsule.radius = 0.24
		_baby_capsule.height = BABY_HEIGHT
	elif not is_baby and _adult_capsule == null:
		_adult_capsule = CapsuleShape3D.new()
		_adult_capsule.radius = 0.43
		_adult_capsule.height = HEIGHT
	_live_capsule = _baby_capsule if is_baby else _adult_capsule
	if _lab_path_sweep == null:
		_lab_path_sweep = PhysicsShapeQueryParameters3D.new()
		_lab_path_sweep.collision_mask = LEVEL_COLLISION_MASK
	var collision := CollisionShape3D.new()
	collision.position.y = _body_height * 0.5
	collision.shape = _live_capsule
	add_child(collision)
	collision_layer = LIVING_ZOMBIE_LAYER
	collision_mask = LEVEL_COLLISION_MASK | 2 | LIVING_ZOMBIE_LAYER

func combat_center() -> Vector3:
	return global_position + Vector3.UP * (_body_height * 0.5)

func _ready() -> void:
	set_process(false)
	_roam_origin = global_position
	health = max_health
	var spawn_clip := _living_clip(SPAWN)
	animation.play(spawn_clip)
	if spawn_clip != SPAWN or not animation.get_parent().has_meta(PREPARED_SPAWN_POSE):
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
		var prepared := source.get("simulator_template") as PackedScene if is_instance_valid(_corpse_floor) else null
		ragdoll.setup(skeleton, source.parts, source.bones, source.offsets, source.joints, prepared)
		if source.has("wall_handoff_idle_pose"):
			ragdoll.wall_handoff_idle_pose = source.wall_handoff_idle_pose
	for body: PhysicalBone3D in ragdoll.bodies.values():
		body.collision_layer = 0
		body.collision_mask = 0
	if is_instance_valid(_corpse_floor):
		ragdoll.prepare_source_joints()
		if animation.has_animation(ActionsStuff.MOVE):
			animation.animation_started.connect(_invalidate_stationary_gait)
			animation.caches_cleared.connect(_invalidate_stationary_gait)
		if animation.has_animation(IDLE):
			_idle_audio_period = animation.get_animation(IDLE).length
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
		if _lab_flash_skin != null:
			_mesh.material_override = _lab_skin
		else:
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
	_poise = minf(_max_poise, _poise + POISE_RECOVERY_PER_SECOND * recovery_time)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	var in_lab := is_instance_valid(_corpse_floor)
	var crowd: bool = in_lab and get_parent().has_living_crowd
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
		and animation.current_animation in WALK_STEP_NOTIFIES
	var destination := _roam_destination
	if _target_aggressive:
		destination = _chase_detour if _chase_detour.is_finite() else _last_seen_position
	_skipped_blocked_step = false
	if crowd_walking and _blocked_walk and is_on_floor() and (_target_aggressive or _blocking_zombie_id != 0):
		# Spread collision retries across zombies. Keep animation and pose history
		# on the full physics clock, including frames without a movement query.
		_skipped_blocked_step = _wait_for_walk_retry(destination)
	if not _skipped_blocked_step:
		move_and_slide()
		if crowd and not pushed and controlled_time == delta and not is_on_floor():
			var clip := animation.current_animation
			if _living_state(clip) == IDLE or clip in WALK_STEP_NOTIFIES:
				_recover_crowd_floor()
		_blocked_walk = crowd_walking and is_on_floor() and is_on_wall() \
			and get_real_velocity().slide(Vector3.UP).length_squared() < BLOCKED_WALK_MAX_SPEED_SQUARED
		_update_walk_blocker(destination)
	_advance_animation(delta, travel)
	ragdoll.sample(delta)

func _recover_crowd_floor() -> void:
	if _corpse_floor.disabled or not is_on_wall() or get_slide_collision_count() < max_slides \
			or (collision_mask & LEVEL_COLLISION_MASK) == 0:
		return
	var hit := get_last_slide_collision()
	var peer := hit.get_collider() as CharacterBody3D
	if peer == null or peer.get_parent() != get_parent() \
			or (peer.collision_layer & LIVING_ZOMBIE_LAYER) == 0 or absf(hit.get_normal().y) > 0.05:
		return
	var box := _corpse_floor.shape as BoxShape3D
	if box == null or not _corpse_floor.global_basis.is_equal_approx(Basis.IDENTITY):
		return
	var foot := _corpse_floor.to_local(global_position)
	var half := box.size * 0.5
	if absf(foot.y - half.y) > safe_margin or absf(foot.x) + _live_capsule.radius > half.x \
			or absf(foot.z) + _live_capsule.radius > half.z:
		return
	# A packed capsule can spend every slide on a neighboring zombie while its
	# feet stay within the flat floor's margin. Check the floor without peers.
	var movement_mask := collision_mask
	collision_mask = LEVEL_COLLISION_MASK
	apply_floor_snap()
	collision_mask = movement_mask
	if is_on_floor():
		velocity.y = 0.0

func _wait_for_walk_retry(destination: Vector3) -> bool:
	var retry_hz := BLOCKED_CHASE_RETRY_HZ if _blocking_zombie_id == 0 else PACKED_WALK_RETRY_HZ
	var stride := maxi(1, roundi(Engine.physics_ticks_per_second / retry_hz))
	if _blocking_peer_id != 0 and _repeated_blocking_pair:
		stride *= 2
	# Blocker movement can only bring a retry forward on an unscheduled tick.
	if Engine.get_physics_frames() % stride == _crowd_slot % stride:
		return false
	if _blocking_zombie_id == 0:
		return true
	if destination.distance_squared_to(_blocked_walk_destination) > WALK_DESTINATION_MOVE_DISTANCE_SQUARED \
			or _walk_blocker_moved(_blocking_zombie_id, _blocking_position):
		return false
	return _blocking_peer_id == 0 or not _walk_blocker_moved(_blocking_peer_id, _blocking_peer_position)

func _walk_blocker_moved(id: int, position_at_contact: Vector3) -> bool:
	var blocker := instance_from_id(id) as CharacterBody3D
	return blocker == null or blocker.is_queued_for_deletion() or blocker.collision_layer == 0 \
		or blocker.global_position.distance_squared_to(position_at_contact) > BLOCKER_MOVE_DISTANCE_SQUARED

func _update_walk_blocker(destination: Vector3) -> void:
	var previous_blocker := _blocking_zombie_id
	var previous_peer := _blocking_peer_id
	_blocking_peer_id = 0
	_repeated_blocking_pair = false
	var contacts := get_slide_collision_count() if _blocked_walk else 0
	if contacts == 0:
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
	if contacts < 2:
		return
	var peer: CharacterBody3D
	for i in contacts - 1:
		var other := get_slide_collision(i).get_collider() as CharacterBody3D
		if other == null or other == blocker or other.get_parent() != get_parent():
			continue
		if peer != null and peer != other:
			return
		peer = other
	if peer == null:
		return
	_blocking_peer_id = peer.get_instance_id()
	var peer_transform: Transform3D = PhysicsServer3D.body_get_state(
		peer.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	_blocking_peer_position = peer_transform.origin
	# Only slow a repeat jam. Either peer can wake the existing collision test.
	_repeated_blocking_pair = (previous_blocker == _blocking_zombie_id and previous_peer == _blocking_peer_id) \
		or (previous_blocker == _blocking_peer_id and previous_peer == _blocking_zombie_id)

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

func _advance_animation(delta: float, travel: Vector3) -> void:
	var clip := animation.current_animation
	var state := _living_state(clip)
	if state != IDLE:
		_idle_audio_phase = 0.0
	if state != ATTACK:
		var expressive := Gait.is_gait(clip)
		var source_stride := clip == ActionsStuff.MOVE
		var play_steps := (not _skipped_blocked_step and clip in WALK_STEP_NOTIFIES and is_on_floor()
			and step_audio.has_connections())
		if play_steps or expressive or source_stride:
			var motion := get_real_velocity().slide(Vector3.UP)
			play_steps = motion.length_squared() >= STEP_MIN_SPEED_SQUARED \
				and (not is_on_wall() or motion.dot(travel) >= MIN_WALL_PROGRESS_SPEED * travel.length()) \
				and not travel.is_zero_approx() and play_steps
			if source_stride:
				var speed := BABY_SPEED if _has_source_baby_stride() else ActionsStuff.SOURCE_STRIDE_SPEED * _body_height / 2.0
				var forward_speed := motion.dot(global_basis.z) if not _skipped_blocked_step else 0.0
				delta *= maxf(forward_speed / speed, 0.0)
			elif expressive:
				# Keep the animated stance proportional to distance moved, including
				# a short final step and the lower speed along oblique walls.
				var speed := CHASE_SPEED if clip == Gait.RUN else LAB_ROAM_SPEED
				var forward_speed := motion.dot(global_basis.z) if not _skipped_blocked_step else 0.0
				delta *= clampf(forward_speed / speed, 0.0, 1.0)
		var play_idle := state == IDLE and idle_audio.has_connections()
		var clip_drives_audio := play_steps or (play_idle and _idle_audio_period <= 0.0)
		var previous_phase := animation.current_animation_position if clip_drives_audio else 0.0
		if source_stride and delta == 0.0:
			# The first stationary tick can still apply a new pose or blend weight.
			# The authored A&S move clip only writes transforms.
			if _stationary_gait_phase != animation.current_animation_position:
				animation.advance(0.0)
				_stationary_gait_phase = animation.current_animation_position
		else:
			_stationary_gait_phase = -1.0
			animation.advance(delta)
		if play_steps:
			_emit_walk_step(clip, previous_phase)
		elif play_idle:
			if _idle_audio_period > 0.0:
				# Follow the MD2 idle duration for this rig through visual style changes.
				previous_phase = _idle_audio_phase
				_idle_audio_phase = fposmod(previous_phase + delta, _idle_audio_period)
				_emit_idle_audio(previous_phase, _idle_audio_phase)
			else:
				_emit_idle_audio(previous_phase, animation.current_animation_position)
		return
	_stationary_gait_phase = -1.0
	var before := animation.current_animation_position
	var lab := is_instance_valid(_corpse_floor)
	var montage_rate := LAB_MELEE_MONTAGE_RATE if lab and not is_baby else 1.0
	var hit_section := _attack_focus_end if lab else TELEGRAPH_END
	var windup_rate := _telegraph_rate * montage_rate
	var telegraph_seconds := clampf((hit_section - before) / windup_rate, 0.0, delta)
	# AN_FocusOnTarget disables tracking at the start of Attack_Hit.
	if lab and telegraph_seconds > 0.0 and _target_visible and _windup_target_has_moved(_last_seen_position):
		_face_target(_last_seen_position - global_position, telegraph_seconds)
	var advance_seconds := telegraph_seconds * windup_rate + (delta - telegraph_seconds) * montage_rate
	animation.advance(advance_seconds)
	var after := before + advance_seconds
	# In the source Baby Zombie clip, the leading hand accelerates at release.
	if is_baby and before < BABY_ATTACK_FOCUS_END and after >= BABY_ATTACK_FOCUS_END:
		swing_audio.emit(combat_center())
	if before < _attack_contact and after >= _attack_contact:
		_check_melee_contact()

func _invalidate_stationary_gait(_clip := &"") -> void:
	_stationary_gait_phase = -1.0

func _emit_idle_audio(previous_phase: float, phase: float) -> void:
	var crossed := IDLE_AUDIO_NOTIFY_TIME > previous_phase and IDLE_AUDIO_NOTIFY_TIME <= phase
	if phase < previous_phase:
		crossed = IDLE_AUDIO_NOTIFY_TIME > previous_phase or IDLE_AUDIO_NOTIFY_TIME <= phase
	if crossed:
		_idle_audio_index += 1
		# Keep idle chance independent of the zombie's patrol and ragdoll draws.
		var roll := float(hash(Vector2i(_crowd_slot, _idle_audio_index))) / 4294967296.0
		if roll < IDLE_AUDIO_CHANCE:
			idle_audio.emit(combat_center())

func _emit_walk_step(clip: StringName, previous_phase: float) -> void:
	var phase := animation.current_animation_position
	var wrapped := phase < previous_phase
	if clip == ActionsStuff.MOVE:
		var end := phase + animation.current_animation_length if wrapped else phase
		var baby_stride := _has_source_baby_stride()
		var contacts: Array = ActionsStuff.BABY_CONTACTS if baby_stride else WALK_STEP_NOTIFIES[clip]
		var stride := ActionsStuff.BABY_STRIDE_SECONDS if baby_stride else ActionsStuff.STRIDE_SECONDS
		var size := 0.5 if is_baby and not baby_stride else 1.0
		for contact: Vector3 in contacts:
			var next_step := contact.x + (floorf((previous_phase - contact.x) / stride) + 1.0) * stride
			if next_step <= end:
				step_audio.emit(to_global(Vector3(contact.y, 0.0, contact.z) * size))
		return
	var contacts: Array = BABY_STEP_CONTACTS if is_baby else WALK_STEP_NOTIFIES[clip]
	# The Baby contacts are exact 30 FPS keys stored in float32 vectors.
	# Apply the rounding tolerance to both bounds to avoid a late or repeated cue.
	var tolerance := BABY_STEP_PHASE_TOLERANCE if is_baby and is_instance_valid(_corpse_floor) else 0.0
	for contact: Vector3 in contacts:
		var after_previous := contact.x > previous_phase + tolerance
		var reached := contact.x <= phase + tolerance
		var crossed := (after_previous or reached) if wrapped else (after_previous and reached)
		if crossed:
			step_audio.emit(to_global(Vector3(contact.y, 0.0, contact.z)))

func _has_source_baby_stride() -> bool:
	return is_baby and is_equal_approx(animation.current_animation_length, ActionsStuff.BABY_STRIDE_SECONDS)

func _check_melee_contact() -> void:
	if target.get("is_dead") == true:
		return
	var offset := target.global_position - global_position
	if absf(offset.y) > _melee_reach:
		return
	offset.y = 0.0
	if offset.length_squared() > _melee_reach * _melee_reach or not _is_in_melee_cone(offset):
		return
	if _clear_sight_to(target.global_position):
		melee_audio.emit(combat_center(), true)
		melee_hit.emit(_melee_damage)

func _clear_sight_to(point: Vector3) -> bool:
	var height := Vector3.UP * (HEIGHT * 0.5)
	if _sight_ray == null:
		_sight_ray = PhysicsRayQueryParameters3D.new()
		_sight_ray.collision_mask = LEVEL_COLLISION_MASK
		_sight_ray.hit_from_inside = true
	_sight_ray.from = combat_center()
	_sight_ray.to = point + height
	return get_world_3d().direct_space_state.intersect_ray(_sight_ray).is_empty()

func _update_target_sight(delta: float, sample_ai: bool) -> void:
	if target.get("is_dead") == true:
		if _target_aggressive:
			_reset_roam()
		_target_visible = false
		_target_aggressive = false
		_sight_state_seconds = 0.0
		return
	var point := target.global_position
	if global_position.distance_squared_to(point) > _sight_radius_squared:
		_target_visible = false
	elif sample_ai or _target_visible != _target_aggressive or _needs_windup_sight(point):
		# Once a transition starts, a brief change in cover must interrupt its clock.
		# Keep routine crowd checks staggered after the state stabilizes.
		_target_visible = _clear_sight_to(point)
		if _target_visible:
			_last_seen_position = point
	if _target_visible == _target_aggressive:
		_sight_state_seconds = 0.0
	else:
		var delay := LAB_SIGHT_LOSS_DELAY if _target_aggressive else _sight_delay
		_sight_state_seconds += delta
		if _sight_state_seconds >= delay - 0.000001:
			_target_aggressive = _target_visible
			_sight_state_seconds = 0.0
			_reset_roam()

func _needs_windup_sight(point: Vector3) -> bool:
	if _living_state(animation.current_animation) != ATTACK or animation.current_animation_position >= _attack_focus_end:
		return false
	# A moving target can sidestep or enter cover before the next crowd ray.
	# Check both positions so a return to the start also stops the old turn.
	return _windup_target_has_moved(point) or _windup_target_has_moved(_last_seen_position)

func _windup_target_has_moved(point: Vector3) -> bool:
	var travel := point - _windup_target_start
	return Vector2(travel.x, travel.z).length_squared() > 0.0001

func _reset_roam() -> void:
	_roam_destination = Vector3.INF
	_roam_wait = LAB_ROAM_DELAY
	_roam_blocked_seconds = 0.0
	_partial_detour_origin = Vector3.INF
	_clear_chase_detour()

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
	var stalled := is_on_wall() and get_real_velocity().dot(offset) < MIN_WALL_PROGRESS_SPEED * distance
	_roam_blocked_seconds = _roam_blocked_seconds + delta if stalled else 0.0
	if distance <= LAB_WAYPOINT_ARRIVAL or _roam_blocked_seconds >= LAB_WALL_STALL_TIME:
		_reset_roam()
		_play_loop(IDLE)
		return Vector3.ZERO
	_face_target(offset, delta)
	_play_gait()
	return offset * (minf(_roam_speed, (distance - LAB_WAYPOINT_ARRIVAL) / delta) / distance)

func _pick_roam_destination() -> Vector3:
	# Keep the capsule inside the flat Lab floor and test the body along
	# each proposed leg. A chest ray can clear low or narrow obstacles.
	var bounds := _corpse_floor.shape as BoxShape3D
	if bounds == null:
		return Vector3.INF
	var extent := bounds.size * 0.5 - Vector3.ONE * _live_capsule.radius
	var space := get_world_3d().direct_space_state
	_prepare_lab_path_sweep()
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
		if _lab_path_fraction(space, travel) >= 1.0 and _lab_path_end_clear(space, travel):
			return point
	return Vector3.INF

func _prepare_lab_path_sweep(include_zombies := false) -> void:
	if _lab_path_sweep.shape != _live_capsule:
		_lab_path_sweep.shape = _live_capsule
	_lab_path_sweep.transform = Transform3D(Basis.IDENTITY, combat_center())
	# Keep terrain in the query and exclude the flat floor supporting the capsule.
	var floor_body := _corpse_floor.get_parent() as StaticBody3D
	var exclude: Array[RID] = []
	if floor_body != null:
		exclude.append(floor_body.get_rid())
	_lab_path_sweep.collision_mask = LEVEL_COLLISION_MASK
	if include_zombies:
		_lab_path_sweep.collision_mask |= LIVING_ZOMBIE_LAYER
		exclude.append(get_rid())
	_lab_path_sweep.exclude = exclude

func _lab_path_fraction(space: PhysicsDirectSpaceState3D, travel: Vector3) -> float:
	_lab_path_sweep.motion = travel
	var fractions := space.cast_motion(_lab_path_sweep)
	return 0.0 if fractions.is_empty() else fractions[0]

func _lab_path_end_clear(space: PhysicsDirectSpaceState3D, travel: Vector3) -> bool:
	var start := _lab_path_sweep.transform
	_lab_path_sweep.transform = start.translated(travel)
	var clear := space.intersect_shape(_lab_path_sweep, 1).is_empty()
	_lab_path_sweep.transform = start
	return clear

func _clear_chase_detour() -> void:
	_chase_detour = Vector3.INF
	_chase_detour_time = 0.0
	_chase_stalled_seconds = 0.0
	_chase_detour_around_zombie = false

func _chase_detour_velocity(offset: Vector3, target_distance: float, stop_distance: float,
		delta: float, sample_ai: bool) -> Vector3:
	if _chase_detour.is_finite():
		_chase_detour_time -= delta
		var travel := (_chase_detour - global_position).slide(Vector3.UP)
		var distance := travel.length()
		var stalled := is_on_wall() and get_real_velocity().dot(travel) < MIN_WALL_PROGRESS_SPEED * distance
		_chase_stalled_seconds = _chase_stalled_seconds + delta if stalled else 0.0
		if (_chase_detour_time > 0.0 and distance > LAB_WAYPOINT_ARRIVAL
				and _chase_stalled_seconds < LAB_WALL_STALL_TIME):
			var direct_clear := false
			if sample_ai:
				var space := get_world_3d().direct_space_state
				_prepare_lab_path_sweep(_chase_detour_around_zombie)
				# Chase stops at the approach margin, even if the target's center
				# has no room for this zombie's capsule.
				var approach := offset.move_toward(Vector3.ZERO, stop_distance)
				if _chase_detour_around_zombie:
					# A crowded destination often rejects the route before the sweep.
					direct_clear = _lab_path_end_clear(space, approach) and _lab_path_fraction(space, approach) >= 1.0
				else:
					direct_clear = _lab_path_fraction(space, approach) >= 1.0 and _lab_path_end_clear(space, approach)
			if not direct_clear:
				return travel * (minf(_chase_speed, (distance - LAB_WAYPOINT_ARRIVAL) / delta) / distance)
			_partial_detour_origin = Vector3.INF
		_clear_chase_detour()

	# The offset uses the last confirmed sighting. Plan around a new
	# obstacle on that route while the target is still remembered.
	if not is_on_wall() or get_real_velocity().dot(offset) >= MIN_WALL_PROGRESS_SPEED * target_distance:
		_chase_stalled_seconds = 0.0
		return Vector3.ZERO
	_chase_stalled_seconds += delta
	if not sample_ai or _chase_stalled_seconds < LAB_WALL_STALL_TIME:
		return Vector3.ZERO
	_chase_stalled_seconds = 0.0

	var bounds := _corpse_floor.shape as BoxShape3D
	if bounds == null:
		return Vector3.ZERO
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var obstacle := collision.get_collider() as CollisionObject3D
		var living_blocker := obstacle is CharacterBody3D and obstacle.get_parent() == get_parent() \
			and (obstacle.collision_layer & LIVING_ZOMBIE_LAYER) != 0
		var fixed_blocker: bool = obstacle is StaticBody3D or (obstacle is RigidBody3D and obstacle.freeze)
		var normal := collision.get_normal().slide(Vector3.UP)
		if (not fixed_blocker and not living_blocker) \
				or obstacle == _corpse_floor.get_parent() or normal.dot(offset) >= -0.1:
			continue
		var space := get_world_3d().direct_space_state
		var packed_blocker: bool = living_blocker and get_parent().has_living_crowd
		_chase_detour = _choose_detour_waypoint(space, bounds, normal, offset, stop_distance, packed_blocker, fixed_blocker)
		if not _chase_detour.is_finite() and not _target_visible and not living_blocker:
			# The remembered route can reach farther with a faster chaser.
			# Bound the second search by the time left on the sighting.
			var available := minf(LAB_DETOUR_TIMEOUT, LAB_SIGHT_LOSS_DELAY - _sight_state_seconds)
			var reach := _chase_speed * available
			if reach > LAB_DETOUR_LENGTH:
				_chase_detour = _choose_detour_waypoint(space, bounds, normal, offset, stop_distance, false, true, reach)
		if _chase_detour.is_finite():
			_chase_detour_time = LAB_DETOUR_TIMEOUT
			# Returning directly through the blocker would undo this side step.
			_chase_detour_around_zombie = living_blocker
			return (_chase_detour - global_position).slide(Vector3.UP).normalized() * _chase_speed
		break
	return Vector3.ZERO

func _choose_detour_waypoint(space: PhysicsDirectSpaceState3D, bounds: BoxShape3D, normal: Vector3,
		target_offset: Vector3, stop_distance: float, packed_blocker: bool, fixed_blocker: bool,
		search_distance := LAB_DETOUR_LENGTH) -> Vector3:
	_prepare_lab_path_sweep(true)
	# Open a small gap beside the wall before testing the two legs.
	# A shape cast can omit contacts already touching its start.
	var extent := bounds.size * 0.5 - Vector3.ONE * _live_capsule.radius
	var clearance := normal.normalized() * LAB_DETOUR_WALL_CLEARANCE
	var clear_origin := _corpse_floor.to_local(global_position + clearance)
	if absf(clear_origin.x) > extent.x or absf(clear_origin.z) > extent.z \
			or not _lab_path_end_clear(space, clearance):
		clearance = Vector3.ZERO
	_lab_path_sweep.transform = _lab_path_sweep.transform.translated(clearance)
	var origin := global_position + clearance
	var lateral := normal.cross(Vector3.UP).normalized()
	if _crowd_slot % 2 != 0:
		lateral = -lateral
	var best := Vector3.INF
	var min_distance := LAB_DETOUR_MIN_LENGTH * LAB_DETOUR_MIN_LENGTH
	var best_distance := min_distance
	var best_remaining := INF
	var best_route_length := INF
	var best_connects := false
	var approach := target_offset - clearance
	for direction in [lateral, -lateral]:
		var local := _corpse_floor.to_local(origin + direction * search_distance)
		local.x = clampf(local.x, -extent.x, extent.x)
		local.z = clampf(local.z, -extent.z, extent.z)
		var travel := (_corpse_floor.to_global(local) - origin).slide(Vector3.UP)
		var max_distance := travel.length_squared()
		# A sweep can only shorten this leg. Keep the earlier connected leg on a tie.
		if max_distance <= min_distance or (best_connects and not fixed_blocker and max_distance <= best_distance):
			continue
		if packed_blocker:
			# Reject only a confirmed hit well inside the minimum usable leg.
			_lab_path_sweep.motion = travel.limit_length(LAB_DETOUR_MIN_LENGTH * 0.5)
			var prefix := space.cast_motion(_lab_path_sweep)
			if prefix.size() == 2 and prefix[1] < 0.75:
				continue
		travel *= _lab_path_fraction(space, travel)
		var distance := travel.length_squared()
		if distance <= min_distance or (best_connects and not fixed_blocker and distance <= best_distance):
			continue
		var remaining := 0.0
		var route_length := 0.0
		if fixed_blocker:
			remaining = (approach - travel).length_squared()
			route_length = sqrt(distance) + maxf(0.0, sqrt(remaining) - stop_distance)
			# Test a second endpoint and approach only if they can improve a connected route.
			if best_connects and (route_length >= best_route_length or is_equal_approx(route_length, best_route_length)):
				continue
		if not _lab_path_end_clear(space, travel):
			continue
		var connects := _detour_reaches_approach(space, travel, approach, stop_distance)
		var better_leg := distance > best_distance
		if fixed_blocker and connects:
			better_leg = route_length < best_route_length
		elif fixed_blocker and is_equal_approx(distance, best_distance):
			# Equal partial legs favor the side that leaves less distance to the target.
			better_leg = remaining < best_remaining and not is_equal_approx(remaining, best_remaining)
		# A remembered position needs a connected route. With fresh sight,
		# the chaser can use a partial leg and plan again at the next corner.
		if (connects or _target_visible) and ((connects and not best_connects)
				or (connects == best_connects and better_leg)):
			best = origin + travel
			best_distance = distance
			best_remaining = remaining
			best_route_length = route_length
			best_connects = connects
	if not fixed_blocker or search_distance != LAB_DETOUR_LENGTH or not best.is_finite():
		return best
	if best_connects:
		_partial_detour_origin = Vector3.INF
		return best
	# A partial leg can return the zombie to the same corner. Give a repeated
	# attempt its full reachable distance while keeping the same swept checks.
	var target_position := global_position + target_offset
	var revisits := _partial_detour_origin.distance_squared_to(global_position) <= LAB_WAYPOINT_ARRIVAL ** 2 \
		and _partial_detour_target.distance_squared_to(target_position) <= LAB_WAYPOINT_ARRIVAL ** 2
	_partial_detour_origin = global_position
	_partial_detour_target = target_position
	var reachable_length := _chase_speed * LAB_DETOUR_TIMEOUT
	if revisits and reachable_length > search_distance:
		var longer := _choose_detour_waypoint(space, bounds, normal, target_offset,
			stop_distance, packed_blocker, fixed_blocker, reachable_length)
		if longer.is_finite() and longer.distance_squared_to(global_position) > best.distance_squared_to(global_position):
			return longer
	return best

func _detour_reaches_approach(space: PhysicsDirectSpaceState3D, detour: Vector3,
		target_offset: Vector3, stop_distance: float) -> bool:
	var approach := target_offset - detour
	var distance := approach.length()
	if distance <= stop_distance:
		return true
	approach *= (distance - stop_distance) / distance
	var start := _lab_path_sweep.transform
	var mask := _lab_path_sweep.collision_mask
	# Test the remainder against terrain. Other zombies can move by the
	# time the current chaser reaches the waypoint.
	_lab_path_sweep.transform = start.translated(detour)
	_lab_path_sweep.collision_mask = LEVEL_COLLISION_MASK
	var clear := _lab_path_fraction(space, approach) >= 1.0 and _lab_path_end_clear(space, approach)
	_lab_path_sweep.transform = start
	_lab_path_sweep.collision_mask = mask
	return clear

func _is_in_melee_cone(planar_offset: Vector3) -> bool:
	return global_basis.z.dot(planar_offset) >= planar_offset.length() * MELEE_HALF_ANGLE_COS

func _face_target(offset: Vector3, delta: float) -> void:
	if Vector2(offset.x, offset.z).length_squared() > 0.0001:
		var current_rotation := rotation
		var next_rotation := current_rotation
		next_rotation.y = lerp_angle(current_rotation.y, atan2(offset.x, offset.z), minf(delta * 10.0, 1.0))
		# A body motion can change the basis without changing the reported Euler angle.
		# Only skip the write if Godot would rebuild the same local basis.
		if next_rotation.y != current_rotation.y or not is_instance_valid(_corpse_floor) \
				or basis != Basis.from_euler(next_rotation, rotation_order) * Basis.from_scale(scale):
			rotation = next_rotation

func _chase_velocity(delta: float, in_lab: bool, sample_ai: bool) -> Vector3:
	var clip := _living_state(animation.current_animation)
	if clip == SPAWN or clip == ATTACK or clip == STAGGER:
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
	var stop_distance := _melee_approach if target_visible else LAB_LAST_SEEN_STOP_DISTANCE
	var needs_approach := distance > stop_distance + MELEE_RANGE_TOLERANCE
	var grounded_lab_approach := in_lab and needs_approach and is_on_floor() and not _corpse_floor.disabled
	if grounded_lab_approach:
		var detour := _chase_detour_velocity(offset, distance, stop_distance, delta, sample_ai)
		if not detour.is_zero_approx():
			_face_target(detour, delta)
			_play_gait()
			return detour
	elif in_lab:
		_clear_chase_detour()
	_face_target(offset, delta)
	if needs_approach:
		var direction := offset / distance if grounded_lab_approach else offset.normalized()
		var travel := direction * minf(_chase_speed, (distance - stop_distance) / delta)
		if grounded_lab_approach:
			travel = _limit_lab_pursuit_to_floor(travel, delta)
		if travel.is_zero_approx():
			_play_loop(IDLE)
		else:
			_play_gait()
		return travel
	# Complete the approach turn before locking the swing's heading.
	var facing_target := _is_in_melee_cone(offset)
	if target_visible and height_delta <= _melee_reach and facing_target and _attack_cooldown <= 0.0:
		var target_position := target.global_position
		if in_lab and not sample_ai and not _confirm_windup_target(target_position):
			_play_loop(IDLE)
			return Vector3.ZERO
		_windup_target_start = target_position
		animation.play(_living_clip(ATTACK), 0.1)
		_attack_cooldown = MELEE_COOLDOWN
		melee_audio.emit(combat_center(), false)
	else:
		_play_loop(IDLE)
	return Vector3.ZERO

func _limit_lab_pursuit_to_floor(travel: Vector3, delta: float) -> Vector3:
	var floor_box := _corpse_floor.shape as BoxShape3D
	if floor_box == null or not _corpse_floor.global_basis.y.is_equal_approx(Vector3.UP):
		return travel
	var extent := floor_box.size * 0.5 - Vector3.ONE * _live_capsule.radius
	var end := _corpse_floor.to_local(global_position + travel * delta)
	if absf(end.x) <= extent.x and absf(end.z) <= extent.z:
		return travel
	# Steer back toward supported ground when a capsule slides beyond the inset.
	end.x = clampf(end.x, -extent.x, extent.x)
	end.z = clampf(end.z, -extent.z, extent.z)
	var endpoint := _corpse_floor.to_global(end)
	if endpoint.is_equal_approx(global_position):
		return Vector3.ZERO
	return ((endpoint - global_position) / delta).limit_length(travel.length())

func _confirm_windup_target(point: Vector3) -> bool:
	# Crowd sight runs on a staggered clock. The current target must still
	# be in reach and in front before this tick can commit the windup.
	var offset := point - global_position
	if absf(offset.y) > _melee_reach:
		return false
	offset.y = 0.0
	if offset.length_squared() > (_melee_approach + MELEE_RANGE_TOLERANCE) ** 2 or not _is_in_melee_cone(offset):
		return false
	_target_visible = _clear_sight_to(point)
	if _target_visible:
		_last_seen_position = point
	return _target_visible

func _living_state(clip: StringName) -> StringName:
	match clip:
		ActionsStuff.IDLE: return IDLE
		ActionsStuff.SPAWN: return SPAWN
		ActionsStuff.ATTACK: return ATTACK
		ActionsStuff.STAGGER: return STAGGER
	return clip

func _living_clip(clip: StringName) -> StringName:
	if actions_stuff_animation and animation.has_animation(ActionsStuff.IDLE):
		match clip:
			IDLE: return ActionsStuff.IDLE
			SPAWN: return ActionsStuff.SPAWN
			ATTACK: return ActionsStuff.ATTACK
			STAGGER: return ActionsStuff.STAGGER
	return clip

func _play_loop(clip: StringName) -> void:
	clip = _living_clip(clip)
	if animation.current_animation != clip:
		animation.play(clip, 0.13)

func _play_gait() -> void:
	var clip := _walk_clip
	if actions_stuff_animation and animation.has_animation(ActionsStuff.MOVE):
		clip = ActionsStuff.MOVE
	elif expressive_gait:
		clip = Gait.RUN if _target_aggressive else Gait.WALK
	var previous := animation.current_animation
	if clip == previous:
		return
	if (clip == ActionsStuff.MOVE or previous == ActionsStuff.MOVE
			or previous not in WALK_STEP_NOTIFIES or not (expressive_gait or Gait.is_gait(previous))):
		_play_loop(clip)
		return
	# Match the leading foot on live switches and on patrol/pursuit transitions.
	var progress := animation.current_animation_position / animation.current_animation_length
	var phase := fposmod(progress - Gait.plant_phase(previous) + Gait.plant_phase(clip), 1.0)
	animation.play(clip, 0.13)
	animation.seek(phase * animation.current_animation_length)

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
	if _flash_left <= 0.0:
		if _lab_flash_skin != null:
			_mesh.material_override = _lab_flash_skin
			# The normalized Mobile buffer clips the old overlay before blending.
			_mesh.set_instance_shader_parameter(&"flash_red", 3.2 if get_viewport().use_hdr_2d else 2.0)
		else:
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
		_knockback = direction * launch_impulse.x / (80.0 * _knockback_resistance)
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
			_poise = _max_poise
			if _living_state(animation.current_animation) != STAGGER:
				var clip := _living_clip(STAGGER)
				if clip == STAGGER:
					animation.stop(true)
				var clip_duration := animation.get_animation(clip).length
				animation.play(clip, 0.0 if clip == STAGGER else 0.12, clip_duration / STAGGER_DURATION)
		elif _knockback_control_left > 0.0 and animation.current_animation in WALK_STEP_NOTIFIES:
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
		var lab_floor := is_instance_valid(_corpse_floor)
		ragdoll.prepare_handoff_samples(delta, lab_floor)
		ragdoll.use_tuned_floor_support = lab_floor and ragdoll_gravity_multiplier > 1.0
		ragdoll.use_tuned_wall_sweep = lab_floor and (
			ragdoll_launch_multiplier > 1.0 or ragdoll_gravity_multiplier > 1.0)
		ragdoll.use_baby_floor_anchors = is_baby and lab_floor
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
		if is_baby:
			launch_impulse *= BABY_DEATH_LAUNCH_SCALE
		var direction := Vector3.FORWARD if _death_direction.is_zero_approx() else _death_direction
		var floor_impact_limb_share := 0.0
		if sabre_finisher:
			floor_impact_limb_share = SABRE_FINISHER_FLOOR_LIMB_SHARE
		elif _death_strike == DeathStrike.SABRE_GROUND:
			floor_impact_limb_share = SABRE_GROUND_FLOOR_LIMB_SHARE
		var flight_gravity := ZOMBIE_GRAVITY * ragdoll_gravity_multiplier
		var profile := _death_profile
		if is_baby:
			if _baby_death_profile == null:
				_baby_death_profile = _death_profile.duplicate() as DeathProfile
				# Match the smaller rig's inertia and share more of the hit across its body.
				_baby_death_profile.angular_impulse *= mass / SOURCE_RIG_LAB_MASS * (BABY_HEIGHT / HEIGHT) ** 2
				_baby_death_profile.transport_fraction = 0.98
			profile = _baby_death_profile
		if ragdoll.begin(profile, direction, "Chest", 0.0, flight_gravity,
				_corpse_floor, floor_impact_limb_share, sabre_finisher, cos(angle) * launch_impulse, sin(angle) * launch_impulse):
			_apply_death_tumble(_death_spin(direction), mass)
		return
	var contact := ragdoll.contact_motion(not _corpse_landed and is_instance_valid(_corpse_floor))
	if contact.is_empty():
		_limb_support_age = 0.0
		return
	if not _corpse_landed:
		# On a terrace, limbs can carry the body before the core reaches a surface.
		# Require sustained support so a brief grazing hit keeps its flight response.
		var limbs_supporting: bool = contact.supports >= 2 and contact.linear < DEATH_LIMB_SUPPORT_MAX_SPEED
		# A corner can carry the upper body and one planted foot while a free
		# limb still swings. Measure the brace before blending landing gravity.
		if not limbs_supporting and sabre_finisher and source_rig and is_instance_valid(_corpse_floor) \
				and not _corpse_floor.disabled and _corpse_age >= WALL_BRACE_MIN_AGE \
				and contact.supports == 1 and contact.leg_supported:
			limbs_supporting = ragdoll.has_flat_corner_brace(SABRE_CORNER_LANDING_MAX_SPEED, CORPSE_SETTLE_SPIN)
			if not limbs_supporting and not is_baby and not ragdoll.use_tuned_wall_sweep:
				limbs_supporting = ragdoll.has_stacked_wall_brace(SABRE_CORNER_LANDING_MAX_SPEED, CORPSE_SETTLE_SPIN)
			_absorb_late_foot_rebounds(contact)
		if not limbs_supporting and contact.linear < DEATH_LIMB_SUPPORT_MAX_SPEED:
			limbs_supporting = _has_tuned_wall_brace(contact)
		if limbs_supporting:
			_wall_landing_age = 0.0
		elif sabre_finisher and source_rig and is_instance_valid(_corpse_floor) and not is_baby:
			limbs_supporting = _has_sustained_wall_landing(delta, contact)
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
		if sabre_finisher and not _corpse_parked:
			_assist_flat_wall_descent(delta, contact)
			_assist_suspended_sabre_descent(contact)

func _has_sustained_wall_landing(delta: float, motion: Dictionary) -> bool:
	if _corpse_floor.disabled or _corpse_age < WALL_BRACE_MIN_AGE or ragdoll.use_tuned_wall_sweep \
			or not is_equal_approx(ragdoll_gravity_multiplier, 1.0) \
			or motion.supports != 1 or not motion.leg_supported or motion.core_supports != 0:
		_wall_landing_age = 0.0
		return false
	# A free torso can hang between a planted foot and a head against the wall.
	# Let the usual brace rules handle direct support through the chest.
	var chest: PhysicalBone3D = ragdoll.bodies.Chest
	var chest_state := PhysicsServer3D.body_get_direct_state(chest.get_rid())
	if chest_state == null or chest_state.get_contact_count() > 0:
		_wall_landing_age = 0.0
		return false
	var floor_body := _corpse_floor.get_parent()
	if not (Ragdoll._body_supported_by(ragdoll.bodies["Leg.L"], floor_body) \
			or Ragdoll._body_supported_by(ragdoll.bodies["Leg.R"], floor_body)) \
			or not ragdoll.has_flat_wall_rest_support(true) \
			or ragdoll.max_anchor_error() > Ragdoll.SOURCE_ANCHOR_TOLERANCE:
		_wall_landing_age = 0.0
		return false
	var chest_pose := chest.global_transform
	var head_pose: Transform3D = ragdoll.bodies.Head.global_transform
	# Require the head and chest to stay in a small pose envelope before
	# transitioning to landing gravity. Momentary wall contacts can still roll off.
	if _wall_landing_age <= 0.0 or _wall_landing_pose_moved(_wall_landing_chest, chest_pose) \
			or _wall_landing_pose_moved(_wall_landing_head, head_pose):
		_wall_landing_chest = chest_pose
		_wall_landing_head = head_pose
		_wall_landing_age = delta
		return false
	_wall_landing_age += delta
	return _wall_landing_age >= CORPSE_WALL_REST_TIME - 0.00001


static func _wall_landing_pose_moved(start: Transform3D, pose: Transform3D) -> bool:
	return start.origin.distance_squared_to(pose.origin) > CORPSE_FLAT_WALL_REST_SHIFT ** 2 \
		or start.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion()) > CORPSE_FLAT_WALL_REST_TURN


func _absorb_late_foot_rebounds(contact: Dictionary) -> void:
	var left: PhysicalBone3D = ragdoll.bodies["Leg.L"]
	if is_baby or ragdoll.use_tuned_wall_sweep or left.bounce <= 0.0 \
			or contact.linear > SABRE_CORNER_LANDING_MAX_SPEED or contact.angular > CORPSE_SETTLE_SPIN:
		return
	var axis_y := absf(_corpse_axis().normalized().y)
	if axis_y <= SABRE_LOW_ROLL_MAX_AXIS_Y or axis_y > CORPSE_UPRIGHT_AXIS_Y \
			or not ragdoll.has_flat_wall_rest_support(true):
		return
	var floor_body := _corpse_floor.get_parent()
	var right: PhysicalBone3D = ragdoll.bodies["Leg.R"]
	if Ragdoll._body_supported_by(left, floor_body) or Ragdoll._body_supported_by(right, floor_body):
		# A foot can keep bouncing against the floor while the upper body
		# slides down a wall. Absorb that rebound as the body tips over.
		left.bounce = 0.0
		right.bounce = 0.0

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
	# Ease into supported-roll damping when the wall carries the upper body.
	if contact_age >= gravity_blend_end - 0.00001 and _corpse_age >= WALL_BRACE_MIN_AGE:
		var planted_wall_brace: bool = flat_floor and not ragdoll.use_tuned_wall_sweep and not ragdoll.source_joints.is_empty() \
			and motion.supports == 2 and motion.core_supports == 0 and motion.leg_supported \
			and motion.linear <= CORPSE_SETTLE_SPEED and motion.angular <= CORPSE_SETTLE_SPIN \
			and ragdoll.has_flat_wall_rest_support(false)
		if planted_wall_brace or (motion.linear < DEATH_LIMB_SUPPORT_MAX_SPEED and _has_tuned_wall_brace(motion)):
			roll_weight = maxf(roll_weight, move_toward(_roll_damping_weight, 1.0, delta / DEATH_LANDING_BLEND_TIME))
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
	var brace_target := 0.0
	if braced:
		# Free limbs can still swing while the floor carries the upper body.
		var head: PhysicalBone3D = ragdoll.bodies.Head
		var chest: PhysicalBone3D = ragdoll.bodies.Chest
		var core_speed := maxf(head.linear_velocity.length(), chest.linear_velocity.length())
		var brace_speed := maxf(core_speed, motion.linear * SABRE_BRACE_LIMB_SPEED_SHARE)
		brace_target = 1.0 - smoothstep(0.6, 1.6, brace_speed)
	var flat_brace_weight := move_toward(_flat_brace_weight, brace_target, delta / SABRE_BRACE_BLEND_TIME)
	var late_roll_damping := 0.0
	if flat_sabre_finisher and contact_age >= DEATH_LANDING_BLEND_TIME and motion.leg_supported and motion.core_supports > 0:
		# Fade in more resistance during the slow final roll on the lab floor.
		var slow_roll := (1.0 - smoothstep(0.4, 1.5, motion.linear)) * smoothstep(0.60, 0.90, _corpse_age)
		var target := SABRE_LATE_ROLL_ANGULAR_DAMP * roll_weight * slow_roll
		if _had_upper_body_brace and damp_supported_roll and motion.supports >= 4 and motion.core_supports == 1:
			target *= 1.0 - _suspended_chest_weight()
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

func _assist_flat_wall_descent(delta: float, motion: Dictionary) -> void:
	if not is_instance_valid(_corpse_floor) or _corpse_floor.disabled or is_baby \
			or ragdoll.source_joints.is_empty() or ragdoll.use_tuned_wall_sweep \
			or not is_equal_approx(ragdoll_gravity_multiplier, 1.0):
		return
	var target := float(_should_restore_wall_gravity(delta, motion))
	_wall_descent_weight = move_toward(_wall_descent_weight, target, delta / SABRE_BRACE_BLEND_TIME)
	if _wall_descent_weight <= 0.0:
		return
	# The floor roll keeps its normal contact state while the torso slides down the wall.
	var acceleration := Vector3.DOWN * (ZOMBIE_GRAVITY - get_gravity().length()) * _wall_descent_weight
	for body: PhysicalBone3D in ragdoll.bodies.values():
		PhysicsServer3D.body_apply_central_force(body.get_rid(), acceleration * body.mass)


func _should_restore_wall_gravity(delta: float, motion: Dictionary) -> bool:
	if not ragdoll.floor_landing_blended or _corpse_age < WALL_BRACE_MIN_AGE or motion.core_supports > 0:
		_wall_brace_age = 0.0
		_wall_descent_unsupported_age = 0.0
		return false
	var axis := absf(_corpse_axis().normalized().y)
	if _wall_descent_weight > 0.0 and axis > SABRE_LOW_ROLL_MAX_AXIS_Y:
		# As the body tips, a foot may briefly leave the floor.
		_wall_descent_unsupported_age = 0.0 if motion.leg_supported else _wall_descent_unsupported_age + delta
		if _wall_descent_unsupported_age < CORPSE_SETTLE_TIME:
			return true
	var braced: bool = axis > CORPSE_UPRIGHT_AXIS_Y and motion.supports == 2 and motion.leg_supported \
		and motion.linear <= CORPSE_SETTLE_SPEED and motion.angular <= CORPSE_SETTLE_SPIN \
		and ragdoll.has_unbalanced_single_wall_support(DEATH_FLOOR_CONTACT_MARGIN * 2.0)
	_wall_brace_age = _wall_brace_age + delta if braced else 0.0
	_wall_descent_unsupported_age = 0.0
	return _wall_brace_age >= CORPSE_SETTLE_TIME


func _assist_suspended_sabre_descent(motion: Dictionary) -> void:
	if _settled_seconds > 0.0 or _corpse_age < SABRE_SUSPENDED_DESCENT_MIN_AGE or not is_instance_valid(_corpse_floor) \
			or _corpse_floor.disabled or is_baby or ragdoll.source_joints.is_empty() \
			or not is_equal_approx(ragdoll_gravity_multiplier, 1.0) or ragdoll.use_tuned_wall_sweep \
			or not ragdoll.floor_landing_blended or _wall_gravity \
			or motion.supports < 4 or motion.core_supports != 1 or not motion.leg_supported \
			or motion.linear > SABRE_SUSPENDED_DESCENT_MAX_SPEED \
			or absf(_corpse_axis().normalized().y) > SABRE_LOW_ROLL_MAX_AXIS_Y:
		return
	var chest: PhysicalBone3D = ragdoll.bodies.Chest
	var floor_body := _corpse_floor.get_parent()
	if chest.linear_velocity.y > -SABRE_SUSPENDED_DESCENT_MIN_FALL_SPEED \
			or not Ragdoll._body_supported_by(ragdoll.bodies.Head, floor_body):
		return
	var height_weight := _suspended_chest_weight()
	if height_weight <= 0.00001:
		return
	# When the planted head and legs carry a descending chest, briefly restore
	# part of the Overworld gravity. Apply it evenly so it adds no launch torque.
	var acceleration := Vector3.DOWN * (ZOMBIE_GRAVITY - get_gravity().length()) * ragdoll_gravity_multiplier
	acceleration *= height_weight * SABRE_SUSPENDED_DESCENT_GRAVITY_SHARE
	for body: PhysicalBone3D in ragdoll.bodies.values():
		PhysicsServer3D.body_apply_central_force(body.get_rid(), acceleration * body.mass)

func _suspended_chest_weight() -> float:
	var floor_box := _corpse_floor.shape as BoxShape3D
	if floor_box == null or not _corpse_floor.global_basis.y.is_equal_approx(Vector3.UP):
		return 0.0
	var floor_body := _corpse_floor.get_parent()
	if not Ragdoll._body_supported_by(ragdoll.bodies["Leg.L"], floor_body) \
			or not Ragdoll._body_supported_by(ragdoll.bodies["Leg.R"], floor_body):
		return 0.0
	# Require both feet on the actual flat floor, and fade out as the chest descends.
	var collider := ragdoll.bodies.Chest.get_child(0) as CollisionShape3D
	var half_size := (collider.shape as BoxShape3D).size * 0.5
	var chest_bottom := collider.global_position.y - collider.global_basis.transposed().y.abs().dot(half_size)
	var floor_top := _corpse_floor.global_position.y + floor_box.size.y * 0.5
	return smoothstep(DEATH_FLOOR_CONTACT_MARGIN, 0.10, chest_bottom - floor_top)

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
		var low := 1.0 - smoothstep(0.20, SABRE_LOW_ROLL_MAX_AXIS_Y, absf(_corpse_axis().normalized().y))
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

func _has_tuned_wall_brace(motion: Dictionary) -> bool:
	if not ragdoll.use_tuned_wall_sweep or ragdoll.use_tuned_floor_support or ragdoll.source_joints.is_empty() \
			or _corpse_age < WALL_BRACE_MIN_AGE or motion.core_supports > 0 \
			or not motion.leg_supported or not is_instance_valid(_corpse_floor) or _corpse_floor.disabled:
		return false
	var floor_body := _corpse_floor.get_parent()
	return (Ragdoll._body_supported_by(ragdoll.bodies["Leg.L"], floor_body) \
		or Ragdoll._body_supported_by(ragdoll.bodies["Leg.R"], floor_body)) \
		and ragdoll.has_flat_wall_rest_support(true)

func _check_terrain_rest(delta: float, motion: Dictionary, normally_supported: bool) -> bool:
	var two_parts: bool = motion.supports == 2
	var flat_floor := is_instance_valid(_corpse_floor)
	var speed_scale := 1.0 if flat_floor else 0.5
	var intermittent_foot: bool = flat_floor and _death_strike == DeathStrike.SABRE_FINISHER \
		and motion.supports == 1 and motion.leg_supported
	# A braced pose under raised gravity can have intermittent solver speed
	# spikes. With the torso and legs supported, test the sustained pose drift.
	var measure_supported_pose: bool = flat_floor and ragdoll.use_tuned_floor_support \
		and ragdoll.floor_landing_blended and not _corpse_floor.disabled \
		and motion.supports >= 3 and motion.core_supports > 0
	var slow_motion: bool = motion.linear <= CORPSE_SETTLE_SPEED * speed_scale \
		and motion.angular <= CORPSE_SETTLE_SPIN * speed_scale
	# Keep tracking a fully supported pose across transient solver speed spikes.
	var grounded_baby: bool = is_baby and measure_supported_pose and motion.supports >= 4 \
		and absf(_corpse_axis().normalized().y) <= CORPSE_SETTLE_MAX_AXIS_Y \
		and ragdoll.has_flat_limb_support() \
		and Ragdoll._body_supported_by(ragdoll.bodies.Chest, _corpse_floor.get_parent())
	var slow_support: bool = (not normally_supported or grounded_baby) and not ragdoll.source_joints.is_empty() \
		and (motion.supports >= 2 or intermittent_foot) \
		and (slow_motion or measure_supported_pose)
	var strict_wall_rest := false
	# A second foot can lose contact for a tick while the pose stays braced.
	if slow_motion and ragdoll.floor_landing_blended and _has_tuned_wall_brace(motion):
		slow_support = ragdoll.max_anchor_error() <= Ragdoll.SOURCE_ANCHOR_TOLERANCE
	elif slow_support:
		if flat_floor:
			# A wall can carry the upper body while the floor carries the
			# chest and legs, or both feet. Verify the pose stays put.
			slow_support = motion.leg_supported and (not two_parts or motion.core_supports == 0)
			if slow_support and intermittent_foot:
				slow_support = ragdoll.has_wall_rest_with_near_foot()
				# Two wall faces can carry the torso even with the second leg
				# off the floor. Require the tighter terrain pose envelope.
				strict_wall_rest = not slow_support and not _corpse_floor.disabled \
					and _corpse_age >= WALL_BRACE_MIN_AGE \
					and ragdoll.floor_landing_blended and ragdoll.has_flat_corner_brace()
				slow_support = slow_support or strict_wall_rest
			elif slow_support:
				slow_support = grounded_baby or ragdoll.has_flat_wall_rest_support(motion.core_supports > 0)
				if not slow_support and two_parts and not is_baby and not _corpse_floor.disabled \
						and _death_strike == DeathStrike.SABRE_FINISHER and _corpse_age >= WALL_BRACE_MIN_AGE \
						and ragdoll.floor_landing_blended and not ragdoll.use_tuned_wall_sweep:
					# A limb can brace the wall while both feet carry the weight.
					var floor_body := _corpse_floor.get_parent()
					strict_wall_rest = Ragdoll._body_supported_by(ragdoll.bodies["Leg.L"], floor_body) \
						and Ragdoll._body_supported_by(ragdoll.bodies["Leg.R"], floor_body) \
						and ragdoll.terrain_support_margin(true) > CORPSE_TERRAIN_SUPPORT_MARGIN
					slow_support = strict_wall_rest
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
	var flat_wall_support := flat_floor and not strict_wall_rest
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
	if moved or _terrain_rest_poses.is_empty() or duration != _terrain_rest_duration or strict_wall_rest != _terrain_rest_strict:
		for name: String in ragdoll.bodies:
			_terrain_rest_poses[name] = ragdoll.bodies[name].global_transform
		_terrain_rest_duration = duration
		_terrain_rest_strict = strict_wall_rest
		_terrain_rest_age = 0.0
		return false
	_terrain_rest_age += delta
	return _terrain_rest_age >= _terrain_rest_duration - 0.00001

func _queue_corpse_pose_capture() -> void:
	var skeleton := ragdoll.skeleton
	if not skeleton.skeleton_updated.is_connected(_capture_corpse_pose):
		skeleton.skeleton_updated.connect(_capture_corpse_pose, CONNECT_ONE_SHOT)
		if is_instance_valid(_corpse_floor):
			# Queue the final Lab pose from this physics tick, even when the
			# renderer processes several physics ticks in one frame.
			skeleton.advance(0.0)

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
