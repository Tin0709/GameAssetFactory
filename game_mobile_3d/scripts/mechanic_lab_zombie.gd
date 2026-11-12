extends CharacterBody3D

signal melee_hit(amount: int)

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
const DEATH_SPEED_TO_LAB := 0.0078
const DEATH_TIER_INFLUENCE := 0.22
const DEATH_ANGULAR_TO_LAB := 0.14
const DEATH_GRAVITY := 15.0
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
var _death_direction := Vector3.ZERO
var _death_strength := 500.0
var _death_rng := RandomNumberGenerator.new()
var _poise := MAX_POISE
var _poise_recovery_wait := 0.0
var _attack_cooldown := 0.0
var _flash_left := 0.0
var _corpse_age := 0.0
var _corpse_landed := false
static var _flash_material: ShaderMaterial
static var _death_profile: DeathProfile
static var _corpse_material: ShaderMaterial

func configure(model: Node, player: CharacterBody3D, effects: Node3D, digits: Array[Texture2D], serial: int) -> void:
	target = player
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
	health = max_health
	animation.play(SPAWN)
	animation.advance(0)
	ragdoll = Ragdoll.new()
	add_child(ragdoll)
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	ragdoll.setup(skeleton, RAGDOLL_PARTS, RAGDOLL_BONES)
	for body: PhysicalBone3D in ragdoll.bodies.values():
		body.collision_layer = 0
		body.collision_mask = 0
	if _death_profile == null:
		_death_profile = DeathProfile.new()
		_death_profile.angular_impulse = 0.8
		_death_profile.transport_fraction = 0.96
		_death_profile.linear_damping = 0.30
		_death_profile.angular_damping = 0.9
		_death_profile.joint_resistance = 0.45
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = HIT_FLASH_SHADER

func _physics_process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		var flash := smoothstep(0.0, HIT_FLASH_DURATION * 0.65, _flash_left)
		_mesh.set_instance_shader_parameter("hit_flash", flash)
		if _flash_left == 0.0:
			_mesh.material_overlay = null
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
	var travel := _chase_velocity(delta) + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 10.0)
	velocity.x = travel.x
	velocity.z = travel.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
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
	else:
		_play_loop(IDLE)
	return Vector3.ZERO

func _play_loop(clip: StringName) -> void:
	if animation.current_animation != clip:
		animation.play(clip, 0.13)

func take_hit(amount: int, direction: Vector3, launch_impulse: Vector2 = DEFAULT_DEATH_IMPULSE, stagger: float = MAX_POISE, knockback_strength: float = 500.0) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(0, health - amount)
	direction.y = 0.0
	direction = direction.normalized()
	_feedback.show_hit(amount, health, max_health)
	_mesh.material_overlay = _flash_material
	_mesh.set_instance_shader_parameter("hit_flash", 1.0)
	_flash_left = HIT_FLASH_DURATION
	if health <= 0:
		_death_direction = direction
		_death_strength = knockback_strength
		animation.pause()
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
	elif stagger > 0.0:
		_knockback = direction * launch_impulse.x / 80.0
		_poise -= stagger
		_poise_recovery_wait = POISE_RECOVERY_DELAY
		if _poise <= 0.0:
			_poise = MAX_POISE
			animation.stop(true)
			animation.play(STAGGER, 0.0, 2.7)

func _update_death(delta: float) -> void:
	_corpse_age += delta
	if not ragdoll.running:
		if ragdoll.sample_count < 2:
			ragdoll.sample(delta)
			return
		var mass := 0.0
		for body: PhysicalBone3D in ragdoll.bodies.values():
			body.collision_layer = 2
			body.collision_mask = 1
			mass += body.mass
		var launch := _death_profile.duplicate() as DeathProfile
		var angle := deg_to_rad(DEATH_LAUNCH_ANGLE)
		var launch_impulse := _death_launch_speed(_death_strength) * mass
		launch.linear_impulse = cos(angle) * launch_impulse
		launch.upward_impulse = sin(angle) * launch_impulse
		var direction := Vector3.FORWARD if _death_direction.is_zero_approx() else _death_direction
		if ragdoll.begin(launch, direction, "Chest", 0.0, DEATH_GRAVITY):
			_apply_death_tumble(_death_spin(direction), mass)
		return
	if not _corpse_landed and ragdoll.contact_motion().core_contacts > 0:
		_corpse_landed = true
		ragdoll.set_physics_process(false)
		# Absorb the landing once the torso reaches the floor. Physics still
		# owns the remaining slide and the pose of every joint.
		for body: PhysicalBone3D in ragdoll.bodies.values():
			body.linear_damp = 5.2
			body.angular_damp = 6.8
	var remaining := CORPSE_LIFETIME - _corpse_age
	if remaining <= 0.00001:
		queue_free()
	elif _corpse_age >= CORPSE_DESATURATION_START:
		_update_corpse_material(remaining)

static func _death_launch_speed(strength: float) -> float:
	var extra := 0.0
	for tier in DEATH_STRENGTH_THRESHOLDS.size():
		if strength < DEATH_STRENGTH_THRESHOLDS[tier]:
			break
		extra = DEATH_ADDITIONAL_MULTIPLIERS[tier]
	return DEATH_SOURCE_SPEED * DEATH_SPEED_TO_LAB * (1.0 + extra * DEATH_TIER_INFLUENCE)

func _death_spin(direction: Vector3) -> Vector3:
	var speed := DEATH_SOURCE_ANGULAR_SCALE * DEATH_ANGULAR_TO_LAB
	var spin := Vector3.UP.cross(direction) * speed
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
