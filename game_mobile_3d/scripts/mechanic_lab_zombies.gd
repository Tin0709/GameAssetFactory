extends Node3D
## Spawn and hit routing for private MD2 zombies in MechanicLab.

signal sabre_contact(point: Vector3, direction: Vector3, clip: String, index: int, serial: int, lethal: bool)
signal sabre_landing(point: Vector3, serial: int)
signal player_hit(amount: int)
signal zombie_attack_audio(point: Vector3, contact: bool)
signal baby_attack_audio(point: Vector3, contact: bool)
signal zombie_swing_audio(point: Vector3)
signal zombie_reaction_audio(point: Vector3, lethal: bool, baby: bool)
signal zombie_step_audio(point: Vector3, actor: CharacterBody3D)
signal zombie_idle_audio(point: Vector3)

const Zombie := preload("res://scripts/mechanic_lab_zombie.gd")
const Ragdoll := preload("res://scripts/mechanic_lab_ragdoll.gd")
const Feedback := preload("res://scripts/mechanic_lab_zombie_feedback.gd")
const HealthBars := preload("res://scripts/mechanic_lab_health_bars.gd")
const DamageNumbers := preload("res://scripts/mechanic_lab_damage_numbers.gd")
const CrossPollinator := preload("res://scripts/mechanic_lab_cross_pollinator.gd")
const Gauntlets := preload("res://scripts/mechanic_lab_gauntlets.gd")
const SOURCE_DIR := "extracted/2026-10-25 19-26-25/Game/Spicewood"
const ZOMBIE_DIR := "Art/Characters/Enemies/Zombie"
const BABY_DIR := "Art/Characters/Enemies/BabyZombie"
const BABY_IDLE := &"BabyZombie_Idle"
const BABY_CLIPS := {
	Zombie.IDLE: [BABY_IDLE, "96a09cee86254292510cef892f61236e8f6cccefd2e82ecd7d60012fa54533ab"],
	Zombie.SPAWN: [&"BabyZombie_Spawn", "0a2a10ce0f32990e1e45d70010b22accdd3435bc4c9402cf153bf8a34df89fe0"],
	&"Zombie_Walk": [&"BabyZombie_Walk", "7e26ac62cecb26369533faf482c34777c52f3067afadadeb8a1e040306c22479"],
	Zombie.ATTACK: [&"BabyZombie_BasicAttack", "7102bdedb8f5050d2e35fcc5b07cba1f1a7c890263950d8664a1792d6cb10574"],
	Zombie.STAGGER: [&"BabyZombie_Staggered", "9eb4846636634d9b63ddc050c98cccadfcdfbafeb16ea34d983bb4ceda741f8f"],
}
# Box centres and extents fitted to the weighted bind mesh. Neck and shoulder
# cones allow the animated attack pose to hand off without an abrupt snap.
const BABY_PARTS := [
	["Chest", Vector3(0, 0.563, 0), Vector3(0.235, 0.354, 0.116), 3.0, 0.0, 0.0],
	["Head", Vector3(0, 0.9375, 0), Vector3(0.358, 0.358, 0.358), 5.0, 34.0, 22.0],
	["Arm.L", Vector3(0.1875, 0.563, 0), Vector3(0.116, 0.354, 0.116), 0.9, 75.0, 24.0],
	["Arm.R", Vector3(-0.1875, 0.563, 0), Vector3(0.116, 0.354, 0.116), 0.9, 75.0, 24.0],
	["Leg.L", Vector3(0.0625, 0.1875, 0), Vector3(0.116, 0.354, 0.116), 1.1, 33.0, 14.0],
	["Leg.R", Vector3(-0.0625, 0.1875, 0), Vector3(0.116, 0.354, 0.116), 1.1, 33.0, 14.0],
]
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
		"push_duration": 0.20, # Observed outward phase of a living target in the Sword capture.
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
# AM_Player_Sabre_JumpAttack: AN_HeavyJumpAttack minus LandingStart.
const SABRE_LANDING_NOTIFY_DELAY := 0.054369554
# GA_HeavyJumpAttackInstanceData. Use apex-to-contact displacement in this lab.
const MEDIUM_FALL_HEIGHT := 4.0
const HIGH_FALL_HEIGHT := 6.5
const LEVEL_COLLISION_MASK := 1
const SPLASH_MULTIPLIER := 0.3
# Lab impulse scale anchors the 800-strength finisher to the existing ragdoll.
const IMPULSE_PER_STRENGTH := 0.43
const MELEE_CONTACT_HEIGHT := Vector3.UP * (Zombie.HEIGHT * 0.5)

class SpawnSearch:
	var player_position: Vector3
	var facing: Basis
	var positions: PackedVector3Array
	var occupied: Dictionary[Vector2i, PackedVector3Array] = {}
	var ring := 0
	var slot := 0

var _visual: PackedScene
var health_bars: HealthBars
var damage_numbers: DamageNumbers
var sword_equipped := false
var curved_equipped := false
var crossbow_equipped := false
var gauntlets_equipped := false
var equipped_strikes: Array = []
var equipped_air_strike: Dictionary = {}
var equipped_air_offset := 0.0
var equipped_air_delay := 0.0
var ragdoll_launch_multiplier := 1.0
var ragdoll_gravity_multiplier := 1.0
var _expressive_gait := false
var _ragdoll_layout: Dictionary
var _baby_visual: PackedScene
var _baby_ragdoll_layout: Dictionary
var _baby_prepared_clips: Dictionary[String, Animation]
var _digits: Array[Texture2D]
var _last_spawn_search: SpawnSearch
var _spawn_serial := 0
var _attack_serial := -1
var _landing_serial := -1
var _pending_landings: Array[Dictionary] = []
var _aim_serial := -1
var _aim_target: Zombie
var _attacker: CharacterBody3D
var _attacker_visual: Node3D
var _living_count := 0
var has_living_crowd := false

func _init() -> void:
	child_entered_tree.connect(_track_living_zombie)
	child_exiting_tree.connect(_untrack_living_zombie)

func _track_living_zombie(child: Node) -> void:
	if child is Zombie:
		child.living_changed.connect(_update_living_count)
		if child.health > 0:
			_update_living_count(true)

func _untrack_living_zombie(child: Node) -> void:
	if child is Zombie:
		child.living_changed.disconnect(_update_living_count)
		if child.health > 0:
			_update_living_count(false)

func _update_living_count(alive: bool) -> void:
	_living_count += 1 if alive else -1
	has_living_crowd = _living_count >= Zombie.CROWD_RETRY_MIN_ZOMBIES

func damage_digits() -> Array[Texture2D]:
	return _digits

func set_expressive_gait(enabled: bool) -> void:
	_expressive_gait = enabled
	for child in get_children():
		if child is Zombie and not child.is_baby and child.health > 0:
			child.expressive_gait = enabled

func setup_combat(attacker: CharacterBody3D) -> void:
	_attacker = attacker
	_attacker_visual = attacker.get("visual") as Node3D
	if _visual == null:
		_load_assets()
	_prewarm_baby_assets()

func spawn(player: CharacterBody3D, facing: Basis, effects: Node3D, base_zombie := false, baby := false) -> bool:
	if baby:
		if _baby_visual == null:
			_load_baby_assets()
		if _baby_visual == null:
			return false
	else:
		if _visual == null:
			_load_assets()
		if _visual == null:
			return false
	var floor_position := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var search := _spawn_search_for(floor_position, facing)
	var point := _find_spawn_point(floor_position, facing, search)
	if not point.is_finite():
		return false
	_spawn_at(point, floor_position, player, effects, base_zombie, baby)
	_mark_spawn_position(search, point)
	return true

func spawn_batch(player: CharacterBody3D, facing: Basis, effects: Node3D,
		base_zombie: bool, limit: int, deadline: int) -> Dictionary:
	if _visual == null:
		_load_assets()
	if _visual == null:
		return {"count": 0, "blocked": true}
	var floor_position := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var search := _spawn_search_for(floor_position, facing)
	var count := 0
	for i in limit:
		var point := _find_spawn_point(floor_position, facing, search)
		if not point.is_finite():
			return {"count": count, "blocked": true}
		_spawn_at(point, floor_position, player, effects, base_zombie)
		_mark_spawn_position(search, point)
		count += 1
		if Time.get_ticks_usec() >= deadline:
			break
	return {"count": count, "blocked": false}

func _spawn_at(point: Vector3, floor_position: Vector3, player: CharacterBody3D,
		effects: Node3D, base_zombie: bool, baby := false) -> void:
	var zombie := Zombie.new()
	zombie.name = "BabyZombie" if baby else "Zombie"
	zombie.position = point
	zombie.max_health = Zombie.BASE_HEALTH if baby or base_zombie else Zombie.TRAINING_HEALTH
	var corpse_floor := get_node_or_null("../Ground/Collision") as CollisionShape3D
	var scene := _baby_visual if baby else _visual
	var layout := _baby_ragdoll_layout if baby else _ragdoll_layout
	zombie.configure(scene.instantiate(), player, effects, _digits, _spawn_serial, layout,
		corpse_floor, health_bars, damage_numbers, baby)
	zombie.expressive_gait = _expressive_gait and not baby
	zombie.melee_hit.connect(player_hit.emit)
	zombie.melee_audio.connect(baby_attack_audio.emit if baby else zombie_attack_audio.emit)
	if baby and zombie_swing_audio.has_connections():
		zombie.swing_audio.connect(zombie_swing_audio.emit)
	if zombie_step_audio.has_connections():
		zombie.step_audio.connect(zombie_step_audio.emit.bind(zombie))
	if zombie_idle_audio.has_connections():
		zombie.idle_audio.connect(zombie_idle_audio.emit)
	_spawn_serial += 1
	add_child(zombie, true)
	zombie.look_at(floor_position, Vector3.UP, true)

func _spawn_search_for(floor_position: Vector3, facing: Basis) -> SpawnSearch:
	var positions: PackedVector3Array = []
	for zombie: Zombie in get_children():
		if zombie.health > 0:
			positions.append(zombie.position)
	# A move, death, or turn can make an earlier candidate available again,
	# including when those changes happen between calls in the same frame.
	if _last_spawn_search != null and _last_spawn_search.player_position == floor_position \
			and _last_spawn_search.facing == facing and _last_spawn_search.positions == positions:
		return _last_spawn_search
	_last_spawn_search = SpawnSearch.new()
	_last_spawn_search.player_position = floor_position
	_last_spawn_search.facing = facing
	for point: Vector3 in positions:
		_mark_spawn_position(_last_spawn_search, point)
	return _last_spawn_search

static func _mark_spawn_position(search: SpawnSearch, point: Vector3) -> void:
	search.positions.append(point)
	var cell := _spawn_cell(point)
	var positions: PackedVector3Array = search.occupied.get(cell, PackedVector3Array())
	positions.append(point)
	search.occupied[cell] = positions

static func _find_spawn_point(player_position: Vector3, facing: Basis, search: SpawnSearch) -> Vector3:
	var preferred := player_position + facing * Vector3(0.42, 0.0, 1.78)
	preferred.x = clampf(preferred.x, -FLOOR_LIMIT, FLOOR_LIMIT)
	preferred.z = clampf(preferred.z, -FLOOR_LIMIT, FLOOR_LIMIT)
	# Earlier candidates stay occupied while the search only adds zombies.
	# A changed occupancy or facing gets a new search from the first slot.
	if search.ring == 0:
		search.ring = 1
		if _spawn_point_clear(preferred, player_position, search.occupied):
			return preferred
	for ring in range(search.ring, 80):
		for slot in range(search.slot, 8 * ring):
			var angle := TAU * slot / (8 * ring)
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * SPACING * ring
			var point := preferred + facing * offset
			if absf(point.x) <= FLOOR_LIMIT and absf(point.z) <= FLOOR_LIMIT \
					and _spawn_point_clear(point, player_position, search.occupied):
				search.ring = ring
				search.slot = slot + 1
				return point
		search.slot = 0
	return Vector3.INF

static func _spawn_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / SPACING), floori(point.z / SPACING))

static func _spawn_point_clear(point: Vector3, player_position: Vector3, occupied: Dictionary[Vector2i, PackedVector3Array]) -> bool:
	if point.distance_squared_to(player_position) < SPACING * SPACING:
		return false
	var cell := _spawn_cell(point)
	for x in range(cell.x - 1, cell.x + 2):
		for z in range(cell.y - 1, cell.y + 2):
			var neighbor := Vector2i(x, z)
			if not occupied.has(neighbor):
				continue
			for position: Vector3 in occupied[neighbor]:
				if point.distance_squared_to(position) < SPACING * SPACING:
					return false
	return true

func aim_sabre(index: int, serial: int, movement: Vector3) -> Vector3:
	if serial != _aim_serial:
		_aim_serial = serial
		_aim_target = null
	var has_live_target := is_instance_valid(_aim_target) and _aim_target.health > 0 \
		and not _aim_target.is_queued_for_deletion()
	if not crossbow_equipped or not has_live_target:
		var reach := CrossPollinator.AIM_RANGE if crossbow_equipped else float(_strikes()[index].range_m)
		var preferred := _aim_target if has_live_target else null
		_aim_target = _find_attack_target(reach, movement, crossbow_equipped, preferred)
	if _aim_target == null:
		return Vector3.ZERO
	var direction := _aim_target.global_position - _attacker.global_position
	direction.y = 0.0
	return direction

func _find_attack_target(reach: float, movement: Vector3, ranged := false, preferred: Zombie = null) -> Zombie:
	var origin := _attacker.global_position
	var space := get_world_3d().direct_space_state
	var ray := _melee_ray(origin)
	var reach_squared := reach * reach
	# Hold a valid melee lock through the windup to avoid switching when
	# two zombies cross. Reacquire if the locked target can no longer be hit.
	if preferred != null:
		var offset := preferred.global_position - origin
		if absf(offset.y) <= GROUND_HEIGHT_LIMIT and Vector2(offset.x, offset.z).length_squared() <= reach_squared:
			ray.to = preferred.combat_center()
			if space.intersect_ray(ray).is_empty():
				return preferred
	var nearest: Zombie
	var nearest_squared := INF
	for zombie: Zombie in get_children():
		if zombie == preferred or zombie.health <= 0 or zombie.is_queued_for_deletion():
			continue
		var offset := zombie.global_position - origin
		if not ranged and absf(offset.y) > GROUND_HEIGHT_LIMIT:
			continue
		var distance_squared := offset.length_squared() if ranged else Vector2(offset.x, offset.z).length_squared()
		offset.y = 0.0
		if distance_squared > reach_squared or distance_squared >= nearest_squared or offset.dot(movement) < 0.0:
			continue
		ray.to = zombie.combat_center()
		if space.intersect_ray(ray).is_empty():
			nearest = zombie
			nearest_squared = distance_squared
	return nearest

func _melee_ray(origin: Vector3) -> PhysicsRayQueryParameters3D:
	var ray := PhysicsRayQueryParameters3D.create(origin + MELEE_CONTACT_HEIGHT, origin, LEVEL_COLLISION_MASK)
	ray.hit_from_inside = true
	return ray

func _strikes() -> Array:
	if not equipped_strikes.is_empty():
		return equipped_strikes
	if gauntlets_equipped:
		return Gauntlets.STRIKES
	if curved_equipped:
		return CURVED_STRIKES
	return SWORD_STRIKES if sword_equipped else SABRE_STRIKES

func bolt_direction(muzzle: Vector3, forward: Vector3, serial: int) -> Vector3:
	var target: Zombie
	if serial == _aim_serial and is_instance_valid(_aim_target) and _aim_target.health > 0:
		target = _aim_target
	else:
		target = _find_attack_target(CrossPollinator.AIM_RANGE, forward, true)
	if target == null:
		return forward
	return (target.combat_center() - muzzle).normalized()

func bow_aim_point(reach: float, movement: Vector3) -> Variant:
	var target := _find_attack_target(reach, movement, true)
	return target.combat_center() if target != null else null

func strike_bolt(hit: Dictionary, direction: Vector3, serial: int,
		strike := CrossPollinator.STRIKE, clip := CrossPollinator.SHOT) -> void:
	var zombie := hit.get("collider") as Zombie
	if zombie == null or zombie.health <= 0 or zombie.is_queued_for_deletion():
		return
	var horizontal := Vector3(direction.x, 0.0, direction.z).normalized()
	_apply_contact(zombie, hit.position, clip, 0, serial, strike, horizontal, false, hit.position, true)

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
		ray.to = zombie.combat_center()
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
	_apply_contact(primary, primary.combat_center(), clip, index, serial, strike, forward, false, origin)
	for zombie in candidates:
		if zombie != primary:
			_apply_contact(zombie, zombie.combat_center(), clip, index, serial, strike, forward, true, origin)

func cancel_pending_landings() -> void:
	_pending_landings.clear()

func _physics_process(_delta: float) -> void:
	var frame := Engine.get_physics_frames()
	while not _pending_landings.is_empty() and _pending_landings[0].frame <= frame:
		var landing: Dictionary = _pending_landings.pop_front()
		if landing.get("emit_contact", false):
			sabre_landing.emit(landing.origin + landing.forward * landing.offset, landing.serial)
		_resolve_landing(landing.origin, landing.forward, landing.serial, landing.strike, landing.offset)

func land_sabre(position: Vector3, facing: Vector3, serial: int, fall_height: float) -> void:
	if serial == _landing_serial:
		return
	_landing_serial = serial
	var forward := Vector3(facing.x, 0.0, facing.z).normalized()
	var offset := _air_offset()
	if equipped_air_delay <= 0.0:
		sabre_landing.emit(position + forward * offset, serial)
	var strike := AIR_STRIKE.duplicate()
	if sword_equipped:
		strike = SWORD_AIR_STRIKE.duplicate()
	elif gauntlets_equipped:
		strike = Gauntlets.AIR_STRIKE.duplicate()
	if not equipped_air_strike.is_empty():
		strike = equipped_air_strike.duplicate()
	if fall_height >= HIGH_FALL_HEIGHT:
		strike.damage *= 3
		strike.strength *= 1.4
	elif fall_height >= MEDIUM_FALL_HEIGHT:
		strike.damage *= 2
		strike.strength *= 1.2
	if equipped_air_delay > 0.0:
		var delay := ceili(equipped_air_delay * Engine.physics_ticks_per_second)
		_pending_landings.append({"frame": Engine.get_physics_frames() + delay, "origin": position,
			"forward": forward, "serial": serial, "strike": strike, "offset": offset, "emit_contact": true})
		return
	if sword_equipped or curved_equipped or gauntlets_equipped or not equipped_air_strike.is_empty():
		_resolve_landing(position, forward, serial, strike, offset)
		return
	var delay_ticks := ceili(SABRE_LANDING_NOTIFY_DELAY * Engine.physics_ticks_per_second)
	_pending_landings.append({"frame": Engine.get_physics_frames() + delay_ticks,
		"origin": position, "forward": forward, "serial": serial, "strike": strike, "offset": offset})

func _air_offset() -> float:
	if not equipped_air_strike.is_empty():
		return equipped_air_offset
	return Gauntlets.AIR_OFFSET if gauntlets_equipped else AIR_CENTRE_OFFSET

func _resolve_landing(position: Vector3, forward: Vector3, serial: int, strike: Dictionary, offset_m: float) -> void:
	var centre := position + forward * offset_m
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
		var contact := zombie.combat_center() if zombie.is_baby else zombie.global_position + Vector3.UP * 0.65
		ray.to = contact
		if not space.intersect_ray(ray).is_empty():
			continue
		_apply_contact(zombie, contact, "AirAttack", 0, serial, strike, forward,
			distance > float(strike.get("primary_range", AIR_PRIMARY_RANGE)), position)

func _apply_contact(zombie: Zombie, point: Vector3, clip: String, index: int, serial: int, strike: Dictionary,
		forward: Vector3, splash: bool, origin: Vector3, projectile := false) -> void:
	var air_attack := clip == "AirAttack"
	var sabre_ground := not projectile and not sword_equipped \
		and not curved_equipped and not gauntlets_equipped and not air_attack \
		and equipped_strikes.is_empty()
	var sabre_finisher := index == 2 and sabre_ground
	var radial := bool(strike.get("radial", air_attack or sabre_finisher))
	var direction := zombie.global_position - origin if radial else forward
	direction.y = 0.0
	# A target on the strike origin has no radial heading. Preserve the
	# attack's facing so the ragdoll does not default to world forward.
	direction = forward if direction.is_zero_approx() else direction.normalized()
	var damage := roundi(float(strike.damage) * SPLASH_MULTIPLIER) if splash else int(strike.damage)
	var angle := deg_to_rad(float(strike.angle))
	var impulse := Vector2(cos(angle), sin(angle)) * float(strike.strength) * IMPULSE_PER_STRENGTH
	var death_strike := Zombie.DeathStrike.AIR if air_attack else Zombie.DeathStrike.GROUND
	if sabre_finisher:
		death_strike = Zombie.DeathStrike.SABRE_FINISHER
	elif sabre_ground:
		death_strike = Zombie.DeathStrike.SABRE_GROUND
	if damage >= zombie.health:
		zombie.ragdoll_launch_multiplier = ragdoll_launch_multiplier
		zombie.ragdoll_gravity_multiplier = ragdoll_gravity_multiplier
	var stagger := float(strike.stagger) * float(strike.get("splash_stagger", 0.0)) if splash else float(strike.stagger)
	zombie.take_hit(damage, direction, impulse, stagger,
		float(strike.strength), death_strike, float(strike.get("push_duration", 0.0)))
	var lethal := zombie.health <= 0
	sabre_contact.emit(point, direction, clip, index, serial, lethal)
	zombie_reaction_audio.emit(point, lethal, zombie.is_baby)

func _private_research_root() -> String:
	if not OS.has_feature("editor"):
		return ""
	var root := OS.get_environment("MD2_RESEARCH_ROOT")
	if root.is_empty():
		root = OS.get_environment("USERPROFILE").path_join("Desktop/MD2 Research")
	root = root.simplify_path().replace("\\", "/").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if not root.is_absolute_path() or root.begins_with("res://") or root.begins_with("user://") \
		or root.to_lower() == project or root.to_lower().begins_with(project + "/"):
		return ""
	return root

func _load_assets() -> void:
	var root := _private_research_root()
	if root.is_empty():
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
		var in_lab := get_node_or_null("../Ground/Collision") is CollisionShape3D
		if in_lab:
			Zombie.prepare_lab_skin(model)
			var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
			Zombie.Gait.build(player.get_animation_library(&""), skeleton, player.get_animation(Zombie.WALK_CLIPS[0]),
				Zombie.LAB_ROAM_SPEED, Zombie.CHASE_SPEED)
			# Keep the first authored pose in the in-memory scene template.
			player.play(Zombie.SPAWN)
			player.advance(0.0)
			player.stop(true)
			model.set_meta(Zombie.PREPARED_SPAWN_POSE, true)
		var packed := PackedScene.new()
		if _digits.size() == 10 and packed.pack(model) == OK:
			_visual = packed
			var path := root.path_join(PHYSICS_PROFILE_PATH)
			if _verified(path, PHYSICS_PROFILE_HASH):
				var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if decoded is Dictionary and decoded.get("idle_glb_sha256") == CLIP_HASHES[Zombie.IDLE]:
					# Every instance uses this packed rig, so verify its source bind pose once.
					var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
					_ragdoll_layout = Zombie.source_ragdoll_layout(skeleton, decoded)
					if not _ragdoll_layout.is_empty() and in_lab:
						var builder := Ragdoll.new()
						_ragdoll_layout.simulator_template = builder.pack_dormant_simulator(skeleton,
							_ragdoll_layout.parts, _ragdoll_layout.bones, _ragdoll_layout.offsets)
						builder.free()
						# The scene is already packed. Capture the authored Idle pose once
						# on the disposable source rig for lethal wall handoffs.
						_ragdoll_layout.wall_handoff_idle_pose = Ragdoll.capture_wall_handoff_idle(skeleton, player, Zombie.IDLE)
	model.free()

func _prewarm_baby_assets() -> void:
	var root := _private_research_root()
	if root.is_empty() or _baby_visual != null:
		return
	var directory := root.path_join(SOURCE_DIR).path_join(BABY_DIR)
	var tree := get_tree()
	# Let the scene draw before beginning to import one clip per frame.
	await tree.process_frame
	for name: StringName in BABY_CLIPS:
		if name == Zombie.IDLE:
			continue
		await tree.process_frame
		if not is_inside_tree() or _baby_visual != null:
			return
		var path := _clip_path(directory, BABY_CLIPS[name][0])
		var clip := _load_baby_clip(path, name)
		if clip == null:
			_baby_prepared_clips.clear()
			return
		_baby_prepared_clips[path] = clip
	await tree.process_frame
	if is_inside_tree() and _baby_visual == null:
		_load_baby_assets()
	_baby_prepared_clips.clear()

func _load_baby_assets() -> void:
	var root := _private_research_root()
	if root.is_empty():
		return
	var source := root.path_join(SOURCE_DIR)
	var directory := source.path_join(BABY_DIR)
	var digit_path := source.path_join("Cues/UI/T_DamageNumbers.png")
	if not _verified(source.path_join(ZOMBIE_DIR).path_join("T_Zombie.png"), SKIN_HASH) \
			or not _verified(digit_path, DIGIT_HASH):
		return
	var idle_path := _clip_path(directory, BABY_IDLE)
	if not _verified(idle_path, BABY_CLIPS[Zombie.IDLE][1]):
		return
	var model := _import_gltf(idle_path, 0, false)
	if model == null:
		return
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if player != null and skeleton != null and _add_baby_clips(directory, player):
		var layout := _fit_baby_ragdoll(skeleton)
		Zombie.prepare_lab_skin(model, "SK_BabyZombie")
		player.play(Zombie.SPAWN)
		player.advance(0.0)
		player.stop(true)
		model.set_meta(Zombie.PREPARED_SPAWN_POSE, true)
		var packed := PackedScene.new()
		if _digits.is_empty():
			_digits = Feedback.load_digits(digit_path)
		if not layout.is_empty() and _digits.size() == 10 and packed.pack(model) == OK:
			layout.wall_handoff_idle_pose = Ragdoll.capture_wall_handoff_idle(skeleton, player, Zombie.IDLE)
			_baby_ragdoll_layout = layout
			_baby_visual = packed
	model.free()
	_baby_prepared_clips.clear()

func _add_baby_clips(directory: String, player: AnimationPlayer) -> bool:
	if not player.has_animation(BABY_IDLE):
		return false
	var library := player.get_animation_library(&"")
	library.rename_animation(BABY_IDLE, Zombie.IDLE)
	player.get_animation(Zombie.IDLE).loop_mode = Animation.LOOP_LINEAR
	for name: StringName in BABY_CLIPS:
		if name == Zombie.IDLE:
			continue
		var path := _clip_path(directory, BABY_CLIPS[name][0])
		var clip: Animation = _baby_prepared_clips.get(path)
		if clip == null:
			clip = _load_baby_clip(path, name)
		if clip == null:
			return false
		if name in Zombie.WALK_CLIPS:
			clip.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(name, clip)
	return true

func _load_baby_clip(path: String, name: StringName) -> Animation:
	var source: Array = BABY_CLIPS[name]
	if not _verified(path, source[1]):
		return null
	# Keep constant hip keys so clips can restore the full-size pose after spawn.
	var imported := _import_gltf(path, GLTFDocument.IMPORT_FLAG_DISCARD_MESHES_AND_MATERIALS, false)
	if imported == null:
		return null
	var source_player := imported.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var clip := source_player.get_animation(source[0]) if source_player != null and source_player.has_animation(source[0]) else null
	imported.free()
	return clip

func _fit_baby_ragdoll(skeleton: Skeleton3D) -> Dictionary:
	var offsets := {}
	var joints := {}
	var chest := Transform3D(Basis.IDENTITY, BABY_PARTS[0][1])
	for part: Array in BABY_PARTS:
		var name: String = part[0]
		var bone := skeleton.find_bone(Zombie.RAGDOLL_BONES[name])
		if bone < 0:
			return {}
		var rest := skeleton.get_bone_global_rest(bone)
		var centre := Transform3D(Basis.IDENTITY, part[1])
		offsets[name] = rest.affine_inverse() * centre
		if name == "Chest":
			continue
		var along := (centre.origin - rest.origin).normalized()
		var cross := Vector3.RIGHT.slide(along).normalized()
		var anchor := Transform3D(Basis(along, cross, along.cross(cross)), rest.origin)
		joints[name] = {"parent": "Chest", "child_frame": centre.affine_inverse() * anchor,
			"parent_frame": chest.affine_inverse() * anchor, "swing": part[4], "twist": part[5]}
	return {"parts": BABY_PARTS, "bones": Zombie.RAGDOLL_BONES, "offsets": offsets, "joints": joints}

func _add_clips(directory: String, player: AnimationPlayer) -> bool:
	var library := player.get_animation_library(&"")
	player.get_animation(Zombie.IDLE).loop_mode = Animation.LOOP_LINEAR
	for name: StringName in CLIP_HASHES:
		if name == Zombie.IDLE:
			continue
		var imported := _import_gltf(_clip_path(directory, name), GLTFDocument.IMPORT_FLAG_DISCARD_MESHES_AND_MATERIALS)
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

func _import_gltf(path: String, flags := 0, remove_immutable_tracks := true) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state, flags) != OK:
		return null
	return document.generate_scene(state, 30.0, false, remove_immutable_tracks) as Node3D
