extends Node
## Continuous pressure using the combat registry; bounded perimeter sampling only.
const ZOMBIE = preload("res://scenes/characters/CuboidZombie.tscn")
@export var enabled: bool = true
@export var random_seed: int = 1337
@export var initial_active_target: int = 5
@export var max_active_zombies: int = 40
@export var ramp_seconds: float = 300.0
@export var initial_interval: float = 1.6
@export var final_interval: float = 0.5
@export var timing_variance: float = 0.14
@export var pair_chance: float = 0.18
@export var calm_gap_chance: float = 0.10
@export var calm_gap_multiplier: float = 1.7
@export var base_hp: int = 60
@export var hp_growth_per_minute: float = 0.08
@export var base_damage: int = 10
@export var damage_growth_per_minute: float = 0.05
@export var base_speed: float = 2.05
@export var speed_growth_per_minute: float = 0.03
@export var max_normal_speed: float = 2.75
@export var perimeter_half_size := Vector2(7.15, 5.35)
@export var player_clearance: float = 3.25
@export var enemy_clearance: float = 0.85
@export var candidate_attempts: int = 32
@export var debug_spawn_shortcuts: bool = true
var elapsed_survival: float = 0.0
var spawn_remaining: float = 0.0
var total_spawned: int = 0
var failed_spawn_attempts: int = 0
var rng := RandomNumberGenerator.new()
@onready var combat: Node = get_parent().get_node("Combat")
@onready var actors: Node3D = get_parent().get_node("Actors")

func _ready() -> void:
	if random_seed == 0: rng.randomize()
	else: rng.seed = random_seed
	if not enabled: return
	for i in range(mini(initial_active_target, max_active_zombies)): spawn_one()
	spawn_remaining = next_interval()

func ramp_fraction() -> float:
	return clampf(elapsed_survival / maxf(1.0, ramp_seconds), 0.0, 1.0)

func current_interval() -> float:
	return lerpf(initial_interval, final_interval, ramp_fraction())

func difficulty_stats() -> Dictionary:
	var minutes := elapsed_survival / 60.0
	return {"hp": maxi(1, roundi(base_hp * (1.0 + hp_growth_per_minute * minutes))),
		"damage": maxi(1, roundi(base_damage * (1.0 + damage_growth_per_minute * minutes))),
		"speed": minf(max_normal_speed, base_speed * (1.0 + speed_growth_per_minute * minutes))}

func next_interval() -> float:
	var interval := current_interval() * rng.randf_range(1.0 - timing_variance, 1.0 + timing_variance)
	if rng.randf() < calm_gap_chance: interval *= calm_gap_multiplier
	return maxf(0.10, interval)

func can_spawn() -> bool:
	return enabled and combat.can_fight() and not combat.player.is_dead

func find_spawn_position(near_point: Vector3 = Vector3(NAN, NAN, NAN)) -> Vector3:
	# NaN sentinel avoids treating a failed candidate as a valid origin spawn.
	for i in range(candidate_attempts):
		var point: Vector3
		if near_point.is_finite() and i < candidate_attempts / 2:
			point = near_point
			var offset := rng.randf_range(enemy_clearance + 0.1, 1.8) * (-1 if rng.randi_range(0, 1) == 0 else 1)
			if is_equal_approx(absf(point.x), perimeter_half_size.x):
				point.z = clampf(point.z + offset, -perimeter_half_size.y, perimeter_half_size.y)
			else:
				point.x = clampf(point.x + offset, -perimeter_half_size.x, perimeter_half_size.x)
		elif rng.randi_range(0, 1) == 0:
			point = Vector3(perimeter_half_size.x * (-1 if rng.randi_range(0, 1) == 0 else 1), 0.02, rng.randf_range(-perimeter_half_size.y, perimeter_half_size.y))
		else:
			point = Vector3(rng.randf_range(-perimeter_half_size.x, perimeter_half_size.x), 0.02, perimeter_half_size.y * (-1 if rng.randi_range(0, 1) == 0 else 1))
		var offset: Vector3 = point - combat.player.global_position
		offset.y = 0.0
		if offset.length_squared() < player_clearance * player_clearance: continue
		var clear := true
		for enemy in combat.living_zombies:
			if point.distance_squared_to(enemy.global_position) < enemy_clearance * enemy_clearance:
				clear = false
				break
		if clear: return point
	return Vector3(NAN, NAN, NAN)

func spawn_one(near_point: Vector3 = Vector3(NAN, NAN, NAN)) -> Node3D:
	if not can_spawn() or combat.living_zombies.size() >= max_active_zombies: return null
	var point := find_spawn_position(near_point)
	if not point.is_finite():
		failed_spawn_attempts += 1
		return null
	var stats := difficulty_stats()
	var enemy := ZOMBIE.instantiate() as CharacterBody3D
	# Single acquisition point for future pooling. Configure before entering the tree.
	enemy.position = actors.to_local(point)
	enemy.max_hp = stats.hp
	enemy.attack_damage = stats.damage
	enemy.move_speed = stats.speed
	enemy.speed_limit = max_normal_speed
	enemy.target = combat.player
	enemy.persistent_chase = true
	enemy.chasing = true
	actors.add_child(enemy)
	combat.register_zombie(enemy)
	total_spawned += 1
	return enemy

func debug_spawn(count: int) -> int:
	if not OS.is_debug_build() or not debug_spawn_shortcuts or not can_spawn(): return 0
	var spawned := 0
	for i in range(mini(count, max_active_zombies - combat.living_zombies.size())):
		if spawn_one() != null: spawned += 1
	return spawned

func _physics_process(delta: float) -> void:
	if not can_spawn(): return
	elapsed_survival += delta
	spawn_remaining -= delta
	if spawn_remaining > 0.0: return
	var batch := 2 if rng.randf() < pair_chance else 1
	var anchor := Vector3(NAN, NAN, NAN)
	for i in range(maxi(0, mini(batch, max_active_zombies - combat.living_zombies.size()))):
		var enemy := spawn_one(anchor)
		if enemy != null: anchor = enemy.global_position
	# No accumulated spawn debt at the cap or after a pause.
	spawn_remaining = next_interval()
