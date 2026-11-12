extends CharacterBody3D

signal melee_hit(amount: int)

enum DeathStrike { GROUND, AIR, SABRE_FINISHER, CURVED_GREATSWORD }
signal melee_audio(point: Vector3, contact: bool)

const Feedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const Ragdoll := preload("res://scenes/dev/zombie_death_physics/ragdoll.gd")
const DeathProfile := preload("res://scenes/dev/zombie_death_physics/death_profile.gd")
const CORPSE_SHADER := preload("res://materials/mechanic_lab_zombie_corpse.gdshader")
const HIT_FLASH_SHADER := preload("res://materials/mechanic_lab_zombie_hit_flash.gdshader")
const IDLE := &"Zombie_Idle"
const WALK_CLIPS := [&"Zombie_Walk", &"Zombie_Walk_Variant1", &"Zombie_Walk_Variant2"]
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
const CURVED_GREATSWORD_FLIGHT_GRAVITY := 32.0
const SABRE_FINISHER_GRAVITY_HOLD := 0.30
const SABRE_FINISHER_HEAD_FRICTION := 0.70
const SABRE_FINISHER_HEAD_BOUNCE := 0.30
const DEATH_LANDING_BLEND_TIME := 0.20
const DEATH_AIR_LINEAR_DAMP := 0.01 # SK_Zombie_PhysicsAsset body defaults.
const DEATH_FLOOR_CONTACT_MARGIN := 0.02
const DEATH_LIMB_SUPPORT_DURATION := 0.10
const DEATH_LIMB_SUPPORT_MAX_SPEED := 2.0
const DEATH_LANDING_LINEAR_DAMP := 3.0
const DEATH_LANDING_ANGULAR_DAMP := 4.0
const DEATH_LANDING_ANGULAR_SPEED_LIMIT := 16.0
const HEIGHT := 1.95
const CHASE_SPEED := 3.1
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
# Honeycomb Farm footage: the silhouette breaks up quickly, then a few
# remnants linger. The thresholds map that timing onto this shader's noise.
const CORPSE_LIFETIME := 5.0
const CORPSE_DISSOLVE_DURATION := 0.48
const CORPSE_DISSOLVE_KEYS := [
	Vector2(0.0, 0.0), Vector2(0.067, 0.25), Vector2(0.117, 0.45),
	Vector2(0.183, 0.60), Vector2(0.25, 0.81), Vector2(0.383, 0.853),
	Vector2(0.433, 0.90), Vector2(CORPSE_DISSOLVE_DURATION, 1.0),
]
const CORPSE_DESATURATION_START := 2.3
const CORPSE_DESATURATION_END := 3.6
const CORPSE_SETTLE_TIME := 0.10
const CORPSE_SETTLE_SPEED := 0.34
const CORPSE_SETTLE_SPIN := 1.6
const CORPSE_SETTLE_MAX_AXIS_Y := 0.32
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
var _feedback: Feedback
var _mesh: MeshInstance3D
var _walk_clip: StringName
var _knockback := Vector3.ZERO
var _knockback_control_left := 0.0
var _death_direction := Vector3.ZERO
var _death_strength := 500.0
var _death_strike := DeathStrike.GROUND
var _death_rng := RandomNumberGenerator.new()
var _poise := MAX_POISE
var _poise_recovery_wait := 0.0
var _attack_cooldown := 0.0
var _flash_left := 0.0
var _corpse_age := 0.0
var _corpse_landed := false
var _limb_support_age := 0.0
var _corpse_parked := false
var _settled_seconds := 0.0
var _landing_age := INF
var _physics_profile: Dictionary
var _corpse_floor: CollisionShape3D
static var _flash_material: ShaderMaterial
static var _death_profile: DeathProfile
static var _corpse_material: ShaderMaterial

func configure(model: Node, player: CharacterBody3D, effects: Node3D, digits: Array[Texture2D],
		serial: int, physics_profile: Dictionary = {}, corpse_floor: CollisionShape3D = null) -> void:
	target = player
	_physics_profile = physics_profile
	_corpse_floor = corpse_floor
	_death_rng.seed = hash(Vector2i(serial, 1709))
	_walk_clip = WALK_CLIPS[serial % WALK_CLIPS.size()]
	add_child(model)
	animation = model.get_node("AnimationPlayer")
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_mesh = model.find_child("SK_Zombie", true, false)
	_feedback = Feedback.new()
	_feedback.digits = digits
	_feedback.effects = effects
	add_child(_feedback)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = HEIGHT
	var collision := CollisionShape3D.new()
	collision.position.y = HEIGHT * 0.5
	collision.shape = capsule
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
	var source := _source_physics_setup(skeleton)
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

func _source_physics_setup(skeleton: Skeleton3D) -> Dictionary:
	if _physics_profile.get("schema") != "md2-zombie-physics/1":
		return {}
	var roles := {"J_Spine": "Chest", "J_Neck": "Head", "J_L_Arm": "Arm.L", "J_R_Arm": "Arm.R",
		"J_L_Leg": "Leg.L", "J_R_Leg": "Leg.R"}
	var bones := {}
	var offsets := {}
	var parts := []
	var joints := {}
	var volume := 0.0
	for entry: Dictionary in _physics_profile.bodies:
		var name: String = roles.get(entry.bone, "")
		if name.is_empty() or skeleton.find_bone(entry.bone) < 0:
			return {}
		var size := _from_unreal(entry.size_cm) * 0.01
		var box_volume := size.x * size.y * size.z
		volume += box_volume
		bones[name] = entry.bone
		offsets[name] = Transform3D(Basis.IDENTITY, _from_unreal(entry.center_cm) * 0.01)
		parts.append([name, Vector3.ZERO, size, box_volume, 0.0, 0.0])
	for part: Array in parts:
		# Preserve the lab's mass budget. MD2's body setup has no mass override.
		part[3] *= 60.0 / volume
	for entry: Dictionary in _physics_profile.constraints:
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
	var travel := _knockback
	if controlled_time > 0.000001:
		travel += _chase_velocity(controlled_time) * (controlled_time / delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 10.0)
	velocity.x = travel.x
	velocity.z = travel.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * _gravity_scale(ZOMBIE_GRAVITY) * delta
	move_and_slide()
	_advance_animation(delta)
	ragdoll.sample(delta)

func _advance_animation(delta: float) -> void:
	if animation.current_animation != ATTACK:
		animation.advance(delta)
		return
	var before := animation.current_animation_position
	var telegraph_seconds := clampf((TELEGRAPH_END - before) / TELEGRAPH_RATE, 0.0, delta)
	var advance_seconds := delta + telegraph_seconds * (TELEGRAPH_RATE - 1.0)
	animation.advance(advance_seconds)
	if before < MELEE_CONTACT_TIME and before + advance_seconds >= MELEE_CONTACT_TIME:
		_check_melee_contact()

func _check_melee_contact() -> void:
	if target.get("is_dead") == true:
		return
	var offset := target.global_position - global_position
	if absf(offset.y) > MELEE_HEIGHT_LIMIT:
		return
	offset.y = 0.0
	if offset.length_squared() > MELEE_REACH * MELEE_REACH or global_basis.z.dot(offset) < offset.length() * MELEE_HALF_ANGLE_COS:
		return
	var height := Vector3.UP * (HEIGHT * 0.5)
	var ray := PhysicsRayQueryParameters3D.create(global_position + height, target.global_position + height, LEVEL_COLLISION_MASK)
	ray.hit_from_inside = true
	if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		melee_audio.emit(global_position + height, true)
		melee_hit.emit(MELEE_DAMAGE)

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
	if height_delta < 1.15 and _attack_cooldown <= 0.0:
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
		stagger: float = MAX_POISE, knockback_strength: float = 500.0, death_strike := DeathStrike.GROUND) -> void:
	if health <= 0 or amount <= 0:
		return
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
		animation.pause()
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
	elif stagger > 0.0:
		_knockback = direction * launch_impulse.x / 80.0
		if not _knockback.is_zero_approx():
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
	var remaining := CORPSE_LIFETIME - _corpse_age
	if remaining <= 0.00001:
		queue_free()
		return
	if _corpse_age >= CORPSE_DESATURATION_START:
		_update_corpse_material(remaining)
	if _corpse_parked:
		return
	var sabre_finisher := _death_strike == DeathStrike.SABRE_FINISHER
	var curved := _death_strike == DeathStrike.CURVED_GREATSWORD
	var flight_gravity := CURVED_GREATSWORD_FLIGHT_GRAVITY if curved else ZOMBIE_GRAVITY
	if not ragdoll.running:
		if ragdoll.sample_count < 2:
			ragdoll.sample(delta)
			return
		var mass := 0.0
		for body: PhysicalBone3D in ragdoll.bodies.values():
			# The player uses layer 2, which the living controllers can stand on.
			body.collision_layer = CORPSE_COLLISION_LAYER
			body.collision_mask = LEVEL_COLLISION_MASK
			mass += body.mass
		if sabre_finisher:
			# Start with MD2's default material values on the leading contact.
			var head: PhysicalBone3D = ragdoll.bodies.Head
			head.friction = SABRE_FINISHER_HEAD_FRICTION
			head.bounce = SABRE_FINISHER_HEAD_BOUNCE
		var launch := _death_profile.duplicate() as DeathProfile
		var angle := deg_to_rad(DEATH_LAUNCH_ANGLE)
		var launch_impulse := _death_launch_speed(_death_strength) * mass
		launch.linear_impulse = cos(angle) * launch_impulse
		launch.upward_impulse = sin(angle) * launch_impulse
		var direction := Vector3.FORWARD if _death_direction.is_zero_approx() else _death_direction
		if ragdoll.begin(launch, direction, "Chest", 0.0, flight_gravity, null if curved else _corpse_floor):
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
	if _corpse_landed:
		_update_landing_forces(delta, flight_gravity, sabre_finisher, contact.supports > 0)
		_check_corpse_settled(delta, contact)

func _update_landing_forces(delta: float, flight_gravity: float, sabre_finisher: bool, supported: bool) -> void:
	if not supported and is_instance_valid(_corpse_floor):
		# The solver can omit contact for a frame while rolling close to the floor.
		var box := _corpse_floor.shape as BoxShape3D
		if box != null and not _corpse_floor.disabled:
			var floor_top := (_corpse_floor.global_transform * (Vector3.UP * box.size.y * 0.5)).y
			supported = absf(ragdoll.minimum_corner_y() - floor_top) <= DEATH_FLOOR_CONTACT_MARGIN
	var gravity_hold := SABRE_FINISHER_GRAVITY_HOLD if sabre_finisher else 0.0
	var gravity_blend_end := gravity_hold + DEATH_LANDING_BLEND_TIME
	var contact_age := minf(_landing_age + delta, gravity_blend_end) if supported else 0.0
	if is_equal_approx(contact_age, _landing_age):
		return
	_landing_age = contact_age
	var blend := smoothstep(0.0, DEATH_LANDING_BLEND_TIME, _landing_age)
	var gravity_blend := smoothstep(gravity_hold, gravity_blend_end, _landing_age)
	var flight_gravity_scale := _gravity_scale(flight_gravity)
	var linear_damp := lerpf(_death_profile.linear_damping, DEATH_LANDING_LINEAR_DAMP, blend)
	var angular_damp := lerpf(_death_profile.angular_damping, DEATH_LANDING_ANGULAR_DAMP, blend)
	for body: PhysicalBone3D in ragdoll.bodies.values():
		body.gravity_scale = lerpf(flight_gravity_scale, 1.0, gravity_blend)
		body.linear_damp = linear_damp
		body.angular_damp = angular_damp

static func _gravity_scale(acceleration: float) -> float:
	return acceleration / float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _check_corpse_settled(delta: float, motion: Dictionary) -> void:
	if motion.core_supports == 0 or not motion.leg_supported or motion.supports < 3 \
		or motion.linear > CORPSE_SETTLE_SPEED or motion.angular > CORPSE_SETTLE_SPIN:
		_settled_seconds = 0.0
		return
	# A head-first hit can briefly stall before the body falls over.
	var bodies := ragdoll.bodies
	var feet: Vector3 = (bodies["Leg.L"].global_position + bodies["Leg.R"].global_position) * 0.5
	var axis: Vector3 = (bodies.Head.global_position - feet).normalized()
	if absf(axis.y) > CORPSE_SETTLE_MAX_AXIS_Y:
		_settled_seconds = 0.0
		return
	_settled_seconds += delta
	var skeleton := ragdoll.skeleton
	if _settled_seconds >= CORPSE_SETTLE_TIME and not skeleton.skeleton_updated.is_connected(_capture_corpse_pose):
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

func _update_corpse_material(remaining: float) -> void:
	if _mesh.material_override == null:
		if _corpse_material == null:
			var skin := _mesh.get_active_material(0) as StandardMaterial3D
			if skin == null:
				return
			_corpse_material = ShaderMaterial.new()
			_corpse_material.shader = CORPSE_SHADER
			_corpse_material.set_shader_parameter("skin", skin.albedo_texture)
		_mesh.material_override = _corpse_material
	var gray := smoothstep(CORPSE_DESATURATION_START, CORPSE_DESATURATION_END, _corpse_age) * 0.80
	_mesh.set_instance_shader_parameter("desaturation", gray)
	_mesh.set_instance_shader_parameter("dissolve", _corpse_breakup_threshold(remaining))

static func _corpse_breakup_threshold(remaining: float) -> float:
	var elapsed := CORPSE_DISSOLVE_DURATION - remaining
	if elapsed <= 0.0:
		return 0.0
	for i in range(1, CORPSE_DISSOLVE_KEYS.size()):
		var next: Vector2 = CORPSE_DISSOLVE_KEYS[i]
		if elapsed <= next.x:
			var prior: Vector2 = CORPSE_DISSOLVE_KEYS[i - 1]
			return remap(elapsed, prior.x, next.x, prior.y, next.y)
	return 1.0

func _exit_tree() -> void:
	if is_instance_valid(ragdoll):
		ragdoll.release()
