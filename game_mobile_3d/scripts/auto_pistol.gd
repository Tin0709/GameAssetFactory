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

func nearest_target() -> Node3D:
	if not is_instance_valid(combat) or not combat.can_fight(): return null
	var nearest: Node3D
	var best_distance := attack_range * attack_range
	for zombie in combat.living_zombies:
		if not is_instance_valid(zombie) or zombie.is_dead: continue
		var offset: Vector3 = zombie.global_position - combat.player.global_position
		offset.y = 0.0
		var distance := offset.length_squared()
		if distance <= best_distance:
			best_distance = distance
			nearest = zombie
	return nearest

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(combat) or not combat.can_fight(): return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0: return
	var target := nearest_target()
	if target == null: return
	var origin: Vector3 = combat.player.visual.socket.muzzle_position()
	var aim: Vector3 = target.global_position + Vector3(0, 1.02, 0)
	combat.fire(origin, (aim - origin).normalized(), damage, projectile_speed, projectile_lifetime, projectile_range)
	cooldown = fire_interval
