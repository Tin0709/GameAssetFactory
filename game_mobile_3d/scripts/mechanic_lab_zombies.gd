extends Node3D
## Spawn and hit routing for private MD2 zombies in MechanicLab.

signal sabre_contact(point: Vector3, direction: Vector3, clip: String, index: int, serial: int, lethal: bool)
signal sabre_landing(point: Vector3, serial: int)
signal player_hit(amount: int)
signal zombie_attack_audio(point: Vector3, contact: bool)

const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
const Feedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const SOURCE_DIR := "extracted/2026-10-25 19-26-25/Game/Spicewood"
const ZOMBIE_DIR := "Art/Characters/Enemies/Zombie"
const PHYSICS_PROFILE_PATH := "reports/combat/observations/zombie_physics_asset_20261112.private.json"
const PHYSICS_PROFILE_HASH := "e0d671c88b3763828679b45ebc0cd084ba0a8ce13060beb757a33b4c329832b2"
const CLIP_HASHES := {
	&"Zombie_Idle": "e55529262e3f6f93e07e5a89f50c0e6dcf8375984285d48d5064475132659f0f",
	&"Zombie_Spawn": "c21a5172d02ec26d6b834902fe546f2f461fcb167d6d60d65d07b22c7e592c74",
	&"Zombie_Walk": "ccd26d9c5dedc86432f442ebf1cead14b2d3efac030b6ab0363a8dd1bcf6e7b6",
	&"Zombie_Walk_Variant1": "001ea35703d08b6eb41ca9fafbab91245453b31a927bfe9a8fb7497b9020d059",
	&"Zombie_Walk_Variant2": "7785f1bd55e988cbedad72203c41f8efe9235d6820724b795b6add229578824e",
	&"Zombie_BasicAttack": "722337a57294a4551a0ef0df5cd014784baf94298401a685dbc467a72875feb6",
	&"Zombie_Staggered": "e25142f7993371ecb37c1e5bf5705cf90429ef616dfad89dccb36270fd0e5582",
	&"Zombie_Novelty": "a0fe0925857a2a481105d5e933ffc45575011056612ad60f98dfa439d7d0cf3d",
}
const SKIN_HASH := "1569dd314999fa126dbea34a3ea44112e79c2737f519b87ab8f20be29ad949ce"
const DIGIT_HASH := "7fa2e2801d368ee8f1a61c81bf736c60a250f42bd343ed97b71ceb9000e9beef"
const FLOOR_LIMIT := 49.0
const SPACING := 1.25
# DT_MeleePropertyDefinition: Sabre_1 through Sabre_3.
const SABRE_STRIKES := [
	{
		"damage": 12, "range_m": 2.5, "strength": 500.0, "angle": 15.0, "stagger": 23.0,
		"cone_degrees": 85.0, "cone_offset": -1.2, "cone_cutoff": 1.2,
	},
	{
		"damage": 14, "range_m": 2.5, "strength": 500.0, "angle": 15.0, "stagger": 23.0,
		"cone_degrees": 90.0, "cone_offset": -1.2, "cone_cutoff": 1.2,
	},
	{
		"damage": 22, "range_m": 3.5, "strength": 800.0, "angle": 25.0, "stagger": 45.0,
		"cone_degrees": 180.0, "cone_offset": 0.0, "cone_cutoff": 0.0,
	},
]
const AIR_STRIKE := {"damage": 20, "range_m": 2.5, "strength": 1150.0, "angle": 25.0, "stagger": 37.0}
# DT_MeleePropertyDefinition: Sword_1 through Sword_3.
const SWORD_STRIKES := [
	{
		"damage": 14, "range_m": 2.75, "strength": 500.0, "angle": 15.0, "stagger": 25.0,
		"cone_degrees": 70.0, "cone_offset": -1.2, "cone_cutoff": 1.2,
	},
	{
		"damage": 16, "range_m": 2.75, "strength": 500.0, "angle": 15.0, "stagger": 25.0,
		"cone_degrees": 70.0, "cone_offset": -1.2, "cone_cutoff": 1.2,
	},
	{
		"damage": 22, "range_m": 3.85, "strength": 800.0, "angle": 25.0, "stagger": 40.0,
		"cone_degrees": 14.0, "cone_offset": -4.0, "cone_cutoff": 4.0,
	},
]
const SWORD_AIR_STRIKE := {"damage": 24, "range_m": 2.5, "strength": 1150.0, "angle": 25.0, "stagger": 37.5}
# DT_MeleePropertyDefinition: CurvedGreatsword_1 through CurvedGreatsword_3.
const CURVED_STRIKES := [
	{
		"damage": 20, "range_m": 2.0, "strength": 650.0, "angle": 25.0, "stagger": 25.0,
		"cone_degrees": 60.0, "cone_offset": -1.8, "cone_cutoff": 1.0,
	},
	{
		"damage": 20, "range_m": 2.5, "strength": 650.0, "angle": 25.0, "stagger": 25.0,
		"cone_degrees": 60.0, "cone_offset": -1.0, "cone_cutoff": 1.0,
	},
	{
		"damage": 30, "range_m": 5.0, "strength": 800.0, "angle": 25.0, "stagger": 45.0,
		"cone_degrees": 180.0, "cone_offset": 0.0, "cone_cutoff": 0.25,
	},
]
const GROUND_HEIGHT_LIMIT := 2.1
const AIR_CENTRE_OFFSET := 1.5
const AIR_PRIMARY_RANGE := 1.5
# GA_HeavyJumpAttackInstanceData. Use apex-to-contact displacement in this lab.
const MEDIUM_FALL_HEIGHT := 4.0
const HIGH_FALL_HEIGHT := 6.5
const LEVEL_COLLISION_MASK := 1
const SPLASH_MULTIPLIER := 0.3
# Lab impulse scale anchors the 800-strength finisher to the existing ragdoll.
const IMPULSE_PER_STRENGTH := 0.43
const MELEE_CONTACT_HEIGHT := Vector3.UP * (Zombie.HEIGHT * 0.5)

var _visual: PackedScene
var sword_equipped := false
var curved_equipped := false
var _physics_profile: Dictionary
var _digits: Array[Texture2D]
var _spawn_serial := 0
var _attack_serial := -1
var _landing_serial := -1
var _aim_serial := -1
var _aim_target: Zombie
var _attacker: CharacterBody3D
var _attacker_visual: Node3D

func setup_combat(attacker: CharacterBody3D) -> void:
	_attacker = attacker
	_attacker_visual = attacker.get("visual") as Node3D

func spawn(player: CharacterBody3D, facing: Basis, effects: Node3D, base_zombie: bool = false) -> bool:
	if _visual == null:
		_load_assets()
	if _visual == null:
		return false
	var floor_position := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var point := _find_spawn_point(floor_position, facing)
	if not point.is_finite():
		return false

	var zombie := Zombie.new()
	zombie.name = "Zombie"
	zombie.position = point
	zombie.max_health = Zombie.BASE_HEALTH if base_zombie else Zombie.TRAINING_HEALTH
	var corpse_floor := get_node_or_null("../Ground/Collision") as CollisionShape3D
	zombie.configure(_visual.instantiate(), player, effects, _digits, _spawn_serial, _physics_profile, corpse_floor)
	zombie.melee_hit.connect(player_hit.emit)
	zombie.melee_audio.connect(zombie_attack_audio.emit)
	_spawn_serial += 1
	add_child(zombie, true)
	zombie.look_at(floor_position, Vector3.UP, true)
	return true

func _find_spawn_point(player_position: Vector3, facing: Basis) -> Vector3:
	var preferred := player_position + facing * Vector3(0.42, 0.0, 1.78)
	preferred.x = clampf(preferred.x, -FLOOR_LIMIT, FLOOR_LIMIT)
	preferred.z = clampf(preferred.z, -FLOOR_LIMIT, FLOOR_LIMIT)
	if _spawn_point_clear(preferred, player_position):
		return preferred
	for ring in range(1, 80):
		for slot in 8 * ring:
			var angle := TAU * slot / (8 * ring)
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * SPACING * ring
			var point := preferred + facing * offset
			if absf(point.x) <= FLOOR_LIMIT and absf(point.z) <= FLOOR_LIMIT and _spawn_point_clear(point, player_position):
				return point
	return Vector3.INF

func _spawn_point_clear(point: Vector3, player_position: Vector3) -> bool:
	if point.distance_squared_to(player_position) < SPACING * SPACING:
		return false
	for zombie in get_children():
		if zombie.health > 0 and point.distance_squared_to(zombie.position) < SPACING * SPACING:
			return false
	return true

func aim_sabre(index: int, serial: int, movement: Vector3) -> Vector3:
	if serial != _aim_serial:
		_aim_serial = serial
		_aim_target = null
	if not is_instance_valid(_aim_target) or _aim_target.health <= 0 or _aim_target.is_queued_for_deletion():
		_aim_target = _find_melee_target(float(_strikes()[index].range_m), movement)
		if _aim_target == null:
			return Vector3.ZERO
	var direction := _aim_target.global_position - _attacker.global_position
	direction.y = 0.0
	return direction

func _find_melee_target(reach: float, movement: Vector3) -> Zombie:
	var origin := _attacker.global_position
	var space := get_world_3d().direct_space_state
	var ray := _melee_ray(origin)
	var nearest: Zombie
	var nearest_squared := INF
	for zombie: Zombie in get_children():
		if zombie.health <= 0 or zombie.is_queued_for_deletion():
			continue
		var offset := zombie.global_position - origin
		if absf(offset.y) > GROUND_HEIGHT_LIMIT:
			continue
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared > reach * reach or distance_squared >= nearest_squared or offset.dot(movement) < 0.0:
			continue
		ray.to = zombie.global_position + MELEE_CONTACT_HEIGHT
		if space.intersect_ray(ray).is_empty():
			nearest = zombie
			nearest_squared = distance_squared
	return nearest

func _melee_ray(origin: Vector3) -> PhysicsRayQueryParameters3D:
	var ray := PhysicsRayQueryParameters3D.create(origin + MELEE_CONTACT_HEIGHT, origin, LEVEL_COLLISION_MASK)
	ray.hit_from_inside = true
	return ray

func _strikes() -> Array:
	if curved_equipped:
		return CURVED_STRIKES
	return SWORD_STRIKES if sword_equipped else SABRE_STRIKES

func strike_sabre(index: int, clip: String, serial: int) -> void:
	if serial == _attack_serial:
		return
	_attack_serial = serial
	var strike: Dictionary = _strikes()[index]
	var forward := _attacker_visual.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin := _attacker.global_position
	var range_squared := float(strike.range_m) * float(strike.range_m)
	# Treat the source angle as the full opening. Set back the apex and clip
	# along its axis. Measure total reach from the player.
	var cone_offset := forward * float(strike.cone_offset)
	var cone_cutoff := float(strike.cone_cutoff)
	var half_angle_cos := cos(deg_to_rad(float(strike.cone_degrees) * 0.5))
	var space := get_world_3d().direct_space_state
	var ray := _melee_ray(origin)
	var candidates: Array[Zombie] = []
	var primary: Zombie
	var nearest_squared := INF
	for zombie: Zombie in get_children():
		if zombie.health <= 0 or zombie.is_queued_for_deletion():
			continue
		var offset := zombie.global_position - origin
		if absf(offset.y) > GROUND_HEIGHT_LIMIT:
			continue
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared > range_squared:
			continue
		var from_apex := offset - cone_offset
		var along_axis := from_apex.dot(forward)
		if along_axis + 0.00001 < maxf(cone_cutoff, from_apex.length() * half_angle_cos):
			continue
		ray.to = zombie.global_position + MELEE_CONTACT_HEIGHT
		if not space.intersect_ray(ray).is_empty():
			continue
		candidates.append(zombie)
		if distance_squared < nearest_squared:
			nearest_squared = distance_squared
			primary = zombie
	if primary == null:
		return
	if _aim_serial == serial and is_instance_valid(_aim_target) and candidates.has(_aim_target):
		primary = _aim_target
	_apply_contact(primary, primary.global_position + MELEE_CONTACT_HEIGHT, clip, index, serial, strike, forward, false)
	for zombie in candidates:
		if zombie != primary:
			_apply_contact(zombie, zombie.global_position + MELEE_CONTACT_HEIGHT, clip, index, serial, strike, forward, true)

func land_sabre(position: Vector3, facing: Vector3, serial: int, fall_height: float) -> void:
	if serial == _landing_serial:
		return
	_landing_serial = serial
	var forward := Vector3(facing.x, 0.0, facing.z).normalized()
	var centre := position + forward * AIR_CENTRE_OFFSET
	sabre_landing.emit(centre, serial)
	var strike := (SWORD_AIR_STRIKE if sword_equipped else AIR_STRIKE).duplicate()
	if fall_height >= HIGH_FALL_HEIGHT:
		strike.damage *= 3
		strike.strength *= 1.4
	elif fall_height >= MEDIUM_FALL_HEIGHT:
		strike.damage *= 2
		strike.strength *= 1.2
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.65, position, LEVEL_COLLISION_MASK)
	ray.hit_from_inside = true
	for zombie: Zombie in get_children():
		if zombie.health <= 0 or zombie.is_queued_for_deletion():
			continue
		var offset := zombie.global_position - centre
		var distance := Vector2(offset.x, offset.z).length()
		if distance > float(strike.range_m) or absf(offset.y) > GROUND_HEIGHT_LIMIT:
			continue
		var contact := zombie.global_position + Vector3.UP * 0.65
		ray.to = contact
		if not space.intersect_ray(ray).is_empty():
			continue
		_apply_contact(zombie, contact, "AirAttack", 0, serial, strike, forward, distance > AIR_PRIMARY_RANGE)

func _apply_contact(zombie: Zombie, point: Vector3, clip: String, index: int, serial: int, strike: Dictionary, forward: Vector3, splash: bool) -> void:
	var air_attack := clip == "AirAttack"
	var sabre_finisher := index == 2 and not sword_equipped and not curved_equipped and not air_attack
	var radial := air_attack or sabre_finisher
	var direction := zombie.global_position - _attacker.global_position if radial else forward
	direction.y = 0.0
	direction = direction.normalized()
	var damage := roundi(float(strike.damage) * SPLASH_MULTIPLIER) if splash else int(strike.damage)
	var angle := deg_to_rad(float(strike.angle))
	var impulse := Vector2(cos(angle), sin(angle)) * float(strike.strength) * IMPULSE_PER_STRENGTH
	var death_strike := Zombie.DeathStrike.AIR if air_attack else Zombie.DeathStrike.GROUND
	if sabre_finisher:
		death_strike = Zombie.DeathStrike.SABRE_FINISHER
	zombie.take_hit(damage, direction, impulse, 0.0 if splash else float(strike.stagger),
		float(strike.strength), death_strike)
	sabre_contact.emit(point, direction, clip, index, serial, zombie.health <= 0)

func _load_assets() -> void:
	if not OS.has_feature("editor"):
		return
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return
	var source := root.path_join(SOURCE_DIR)
	var directory := source.path_join(ZOMBIE_DIR)
	var digit_path := source.path_join("Cues/UI/T_DamageNumbers.png")
	if not _verified(directory.path_join("T_Zombie.png"), SKIN_HASH) or not _verified(digit_path, DIGIT_HASH):
		return
	for clip: StringName in CLIP_HASHES:
		if not _verified(_clip_path(directory, clip), CLIP_HASHES[clip]):
			return

	var model := _import_gltf(_clip_path(directory, Zombie.IDLE))
	if model == null:
		return
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null and player.has_animation(Zombie.IDLE) and _add_clips(directory, player):
		_digits = Feedback.load_digits(digit_path)
		var packed := PackedScene.new()
		if _digits.size() == 10 and packed.pack(model) == OK:
			_visual = packed
			var path := root.path_join(PHYSICS_PROFILE_PATH)
			if _verified(path, PHYSICS_PROFILE_HASH):
				var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if decoded is Dictionary and decoded.get("idle_glb_sha256") == CLIP_HASHES[Zombie.IDLE]:
					_physics_profile = decoded
	model.free()

func _add_clips(directory: String, player: AnimationPlayer) -> bool:
	var library := player.get_animation_library(&"")
	player.get_animation(Zombie.IDLE).loop_mode = Animation.LOOP_LINEAR
	for name: StringName in CLIP_HASHES:
		if name == Zombie.IDLE:
			continue
		var imported := _import_gltf(_clip_path(directory, name))
		if imported == null:
			return false
		var clip_player := imported.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var clip := clip_player.get_animation(name) if clip_player != null and clip_player.has_animation(name) else null
		imported.free()
		if clip == null:
			return false
		if name in Zombie.WALK_CLIPS:
			clip.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(name, clip)
	return true

func _clip_path(directory: String, clip: StringName) -> String:
	return directory.path_join("Animations/%s.glb" % clip)

func _verified(path: String, expected_hash: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.get_sha256(path) == expected_hash

func _import_gltf(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D
