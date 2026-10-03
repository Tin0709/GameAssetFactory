extends Node2D

const BULLET = preload("res://scenes/bullet.tscn")
@export var fire_interval: float = 0.5
@export var targeting_range: float = 650.0
var cooldown: float = 0.0
var muzzle_flash: float = 0.0
@onready var player: SurvivorPlayer = get_parent()

func _physics_process(delta: float) -> void:
	if player.dead:
		return
	cooldown = maxf(0.0, cooldown - delta)
	muzzle_flash = maxf(0.0, muzzle_flash - delta)
	var nearest: SurvivorZombie = null
	var best_distance := targeting_range * targeting_range
	for node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as SurvivorZombie
		if zombie.dead:
			continue
		var distance := global_position.distance_squared_to(zombie.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = zombie
	if nearest != null:
		var aim := nearest.global_position - global_position
		rotation = aim.angle()
		if cooldown <= 0.0:
			var bullet := BULLET.instantiate()
			bullet.direction = aim.normalized()
			get_tree().current_scene.add_child(bullet)
			bullet.global_position = global_position + bullet.direction * 24.0
			cooldown = fire_interval
			muzzle_flash = 0.07
			Sound.play(&"pistol_shot")
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(9, -4, 18, 8), Color("cdd9df"))
	draw_rect(Rect2(11, 2, 6, 7), Color("687987"))
	if muzzle_flash > 0.0:
		draw_circle(Vector2(30, 0), 7, Color("ffe59c"))
