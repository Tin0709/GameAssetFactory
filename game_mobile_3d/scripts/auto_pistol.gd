extends Node3D

@export var damage: int = 20
@export var attack_range: float = 8.0
@export var fire_interval: float = 0.5
@export var projectile_speed: float = 14.0
@export var projectile_range: float = 12.6
@export var projectile_lifetime: float = 0.9
@export var enabled: bool = true
var combat: Node
var cooldown: float = 0.15
const Profiles = preload("res://scripts/weapon_fire_profiles.gd")
var weapon_type := 0
var shot_count := 0
var weapon_behavior: Node
var awareness_range_multiplier: float = 1.20
var target_scan_count: int = 0
var cached_frame: int = -1
var cached_origin := Vector3.INF
var cached_range: float = -1.0
var cached_registry_size: int = -1
var cached_target: Node3D
var cached_threat: Node3D
## Keep the original inspector stats as the upgrade contract. Profiles derive
## effective shot values, so the existing pistol interval floor never slows M4.
var damage_per_shot: int:
	get: return int(Profiles.PROFILES[weapon_type].damage) + damage - 20
var shot_interval: float:
	get: return float(Profiles.PROFILES[weapon_type].interval) * fire_interval / 0.5
var target_range: float:
	get: return float(Profiles.PROFILES[weapon_type].target_range) * attack_range / 8.0
var shot_speed: float:
	get: return float(Profiles.PROFILES[weapon_type].speed) * projectile_speed / 14.0
var shot_range: float:
	get: return float(Profiles.PROFILES[weapon_type].range) * projectile_range / 12.6

func _ready() -> void:
	# Read movement after the player's move_and_slide, never from stale input.
	process_physics_priority = 1

func select_weapon(index: int) -> void:
	if index == weapon_type: return
	weapon_type = index
	cooldown = 0.15

func can_fire() -> bool:
	return enabled and is_instance_valid(combat) and combat.can_fight() and combat.player.can_fire_moving() and (weapon_behavior == null or weapon_behavior.is_ready())

func debug_text() -> String:
	return "Interval %.2fs | Speed %.2f / %.1f m/s | Can Fire: %s | Pellets %d" % [shot_interval, combat.player.current_speed, combat.player.firing_speed_threshold, "YES" if can_fire() else "NO", Profiles.PROFILES[weapon_type].pellets]

func nearest_target() -> Node3D:
	if not is_instance_valid(combat) or not combat.can_fight(): return null
	_refresh_targets()
	return cached_target

func awareness_target(retain: bool) -> Node3D:
	if not is_instance_valid(combat) or not combat.can_fight(): return null
	_refresh_targets()
	return cached_threat if retain else cached_target

func _refresh_targets() -> void:
	var frame := Engine.get_physics_frames()
	var origin: Vector3 = combat.player.global_position
	# Reuse the registry query across behavior, movement and firing.
	if weapon_behavior != null and cached_frame == frame and cached_origin == origin and cached_range == target_range and cached_registry_size == combat.living_zombies.size():
		if (cached_target == null or (is_instance_valid(cached_target) and not cached_target.is_dead)) and (cached_threat == null or (is_instance_valid(cached_threat) and not cached_threat.is_dead)): return
	cached_frame = frame; cached_origin = origin; cached_range = target_range
	cached_registry_size = combat.living_zombies.size()
	cached_target = null; cached_threat = null; target_scan_count += 1
	var best_distance := target_range * target_range
	var safe_distance := pow(target_range * awareness_range_multiplier, 2)
	for zombie in combat.living_zombies:
		if not is_instance_valid(zombie) or zombie.is_dead: continue
		var offset: Vector3 = zombie.global_position - combat.player.global_position
		offset.y = 0.0
		var distance := offset.length_squared()
		if distance <= best_distance:
			best_distance = distance
			cached_target = zombie
		if distance <= safe_distance:
			safe_distance = distance
			cached_threat = zombie

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(combat) or not combat.can_fight(): return
	cooldown -= delta
	if not can_fire():
		cooldown = maxf(0.0, cooldown)
		return
	if cooldown > 0.000001: return
	var target := nearest_target()
	if target == null:
		cooldown = maxf(0.0, cooldown)
		return
	var origin: Vector3 = combat.player.visual.socket.muzzle_position()
	var aim: Vector3 = target.global_position + Vector3(0, 1.02, 0)
	var lifetime := shot_range / shot_speed * projectile_lifetime / 0.9 + 0.02
	combat.fire(origin, (aim - origin).normalized(), damage_per_shot, shot_speed, lifetime, shot_range, weapon_type, shot_count)
	shot_count += 1
	# Carry the sub-tick remainder for an accurate automatic rate; blocked
	# movement/absent targets above discard debt, so resuming never bursts.
	cooldown = maxf(0.0, cooldown + shot_interval)
