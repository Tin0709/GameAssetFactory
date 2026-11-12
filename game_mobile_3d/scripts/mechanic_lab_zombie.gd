extends CharacterBody3D

const Feedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const Ragdoll := preload("res://scenes/dev/zombie_death_physics/ragdoll.gd")
const DeathProfile := preload("res://scenes/dev/zombie_death_physics/death_profile.gd")
const CORPSE_SHADER := preload("res://materials/mechanic_lab_zombie_corpse.gdshader")
const IDLE := &"Zombie_Idle"
const WALK_CLIPS := [&"Zombie_Walk", &"Zombie_Walk_Variant1", &"Zombie_Walk_Variant2"]
const SPAWN := &"Zombie_Spawn"
const ATTACK := &"Zombie_BasicAttack"
const STAGGER := &"Zombie_Staggered"
const MAX_HEALTH := 60
const HEIGHT := 1.95
const HIT_RADIUS := 0.48
const CHASE_SPEED := 3.1
const MELEE_RANGE := 1.36
const MELEE_RANGE_TOLERANCE := 0.025
# Honeycomb Farm footage: visible breakup about 4.4–4.9 seconds after the lethal hit.
const CORPSE_LIFETIME := 4.9
const CORPSE_DISSOLVE_DURATION := 0.50
const CORPSE_DESATURATION_START := 2.3
const CORPSE_DESATURATION_END := 3.6

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
var health := MAX_HEALTH
var _feedback: Feedback
var _mesh: MeshInstance3D
var _walk_clip: StringName
var _knockback := Vector3.ZERO
var _death_direction := Vector3.ZERO
var _attack_cooldown := 0.0
var _flash_left := 0.0
var _corpse_age := 0.0
static var _flash_material: StandardMaterial3D
static var _death_profile: DeathProfile
static var _corpse_material: ShaderMaterial

func configure(model: Node, player: CharacterBody3D, effects: Node3D, digits: Array[Texture2D], serial: int) -> void:
	target = player
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
		# Launch the whole corpse clear of the floor before the joints take up the hit.
		_death_profile.linear_impulse = 285.0
		_death_profile.upward_impulse = 190.0
		_death_profile.angular_impulse = 3.2
		_death_profile.transport_fraction = 0.93
		_death_profile.linear_damping = 0.18
		_death_profile.joint_resistance = 0.45
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.albedo_color = Color(1.0, 0.14, 0.08, 0.48)
		_flash_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

func _physics_process(delta: float) -> void:
	if health <= 0:
		_update_death(delta)
		return
	if global_position.y < -6.0:
		queue_free()
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_mesh.material_overlay = null
	var travel := _chase_velocity(delta) + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 10.0)
	velocity.x = travel.x
	velocity.z = travel.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()
	animation.advance(delta)
	ragdoll.sample(delta)

func _chase_velocity(delta: float) -> Vector3:
	if animation.current_animation in [SPAWN, ATTACK, STAGGER]:
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
		_attack_cooldown = animation.get_animation(ATTACK).length + 0.30
	else:
		_play_loop(IDLE)
	return Vector3.ZERO

func _play_loop(clip: StringName) -> void:
	if animation.current_animation != clip:
		animation.play(clip, 0.13)

func take_hit(amount: int, direction: Vector3) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(0, health - amount)
	direction.y = 0.0
	direction = direction.normalized()
	_feedback.show_hit(amount, health, MAX_HEALTH)
	if health <= 0:
		_death_direction = direction
		_mesh.material_overlay = null
		animation.pause()
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
	else:
		_mesh.material_overlay = _flash_material
		_flash_left = 0.10
		_knockback = direction * 2.6
		animation.stop(true)
		animation.play(STAGGER, 0.0, 2.7)

func _update_death(delta: float) -> void:
	_corpse_age += delta
	if not ragdoll.running:
		if ragdoll.sample_count < 2:
			ragdoll.sample(delta)
			return
		for body: PhysicalBone3D in ragdoll.bodies.values():
			body.collision_layer = 2
			body.collision_mask = 1
		ragdoll.begin(_death_profile, _death_direction, "Chest", 0.0, 13.0)
		return
	var remaining := CORPSE_LIFETIME - _corpse_age
	if remaining <= 0.00001:
		queue_free()
	elif _corpse_age >= CORPSE_DESATURATION_START:
		_update_corpse_material(remaining)

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
	var breakup := 1.0 - clampf(remaining / CORPSE_DISSOLVE_DURATION, 0.0, 1.0)
	_mesh.set_instance_shader_parameter("desaturation", gray)
	_mesh.set_instance_shader_parameter("dissolve", breakup)

func _exit_tree() -> void:
	if is_instance_valid(ragdoll):
		ragdoll.release()
