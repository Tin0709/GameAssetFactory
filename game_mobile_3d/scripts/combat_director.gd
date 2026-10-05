extends Node
## Scene-local registry/services; no recurring scene-tree scans or global singleton.

@export var combat_enabled: bool = true
var active: bool = true
var player: CharacterBody3D
var living_zombies: Array[Node3D] = []
var kill_count: int = 0
@onready var projectiles: Node3D = $Projectiles
@onready var pickups: Node3D = $Pickups
@onready var effects: Node3D = $Effects
@onready var audio: Node = $Audio
const PROJECTILE = preload("res://scenes/combat/PistolProjectile.tscn")
const PICKUP = preload("res://scenes/combat/ExpPickup.tscn")
const MUZZLE = preload("res://scenes/combat/MuzzleFlash.tscn")
const IMPACT = preload("res://scenes/combat/ImpactBurst.tscn")

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	assert(player != null)
	player.combat = self
	player.get_node("Pistol").combat = self
	player.defeated.connect(_on_player_defeated)
	for zombie in get_tree().get_nodes_in_group("zombies"):
		register_zombie(zombie)

func register_zombie(zombie: Node3D) -> void:
	if not living_zombies.has(zombie) and not zombie.is_dead:
		living_zombies.append(zombie)
		zombie.tree_exiting.connect(_unregister_zombie.bind(zombie), CONNECT_ONE_SHOT)
	zombie.combat = self
	zombie.target = player

func _unregister_zombie(zombie: Node3D) -> void:
	living_zombies.erase(zombie)

func can_fight() -> bool:
	return active and combat_enabled and not get_tree().paused

func fire(origin: Vector3, direction: Vector3, damage: int, speed: float, lifetime: float, travel_range: float = -1.0) -> void:
	if not can_fight() or direction.length_squared() < 0.0001: return
	var bullet := PROJECTILE.instantiate()
	bullet.combat = self
	bullet.direction = direction
	bullet.damage = damage
	bullet.speed = speed
	bullet.lifetime = lifetime
	bullet.travel_range = travel_range if travel_range > 0 else speed * lifetime
	projectiles.add_child(bullet)
	bullet.global_position = origin
	bullet.look_at(origin + direction, Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP)
	var muzzle := MUZZLE.instantiate()
	effects.add_child(muzzle)
	muzzle.global_position = origin + direction * 0.42
	player.visual.shot_recoil(direction)
	play_sound(&"pistol_shot")

func play_sound(event: StringName) -> void:
	audio.play_event(event)

func spawn_impact(position: Vector3) -> void:
	var effect := IMPACT.instantiate()
	effects.add_child(effect)
	effect.global_position = position

func enemy_death_started(zombie: Node3D) -> void:
	if not living_zombies.has(zombie): return
	living_zombies.erase(zombie)
	kill_count += 1
	play_sound(&"zombie_death")

func spawn_exp(position: Vector3) -> void:
	var pickup := PICKUP.instantiate()
	pickup.combat = self
	pickup.player = player
	pickups.add_child(pickup)
	pickup.global_position = Vector3(position.x, 0.24, position.z)

func award_exp(value: int) -> void:
	if not active or player.is_dead: return
	player.collect_exp(value)
	play_sound(&"exp_pickup")

func _on_player_defeated() -> void:
	active = false
	player.get_node("Pistol").set_physics_process(false)
	for zombie in living_zombies:
		if is_instance_valid(zombie):
			zombie.set_physics_process(false)
			zombie.visual.freeze_animation()
	for bullet in projectiles.get_children(): bullet.queue_free()
	play_sound(&"player_death")
	get_parent().get_node("HUD/Defeated").show()
	get_parent().update_status()
