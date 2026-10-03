extends Node2D

const ZOMBIE = preload("res://scenes/zombie.tscn")
const PICKUP = preload("res://scenes/exp_pickup.tscn")
@export var spawn_interval: float = 2.0
@export var max_zombies: int = 45
var kills: int = 0
var elapsed: float = 0.0
@onready var player: SurvivorPlayer = $Actors/Player
@onready var actors: Node2D = $Actors
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	player.stats_changed.connect(_update_hud)
	player.died.connect(_on_player_died)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_zombie)
	spawn_timer.start()
	_spawn_zombie()
	_update_hud()

func _process(delta: float) -> void:
	if not player.dead:
		elapsed += delta
		hud.set_status(remaining_zombies(), kills, elapsed)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if player.dead and event.is_action_pressed("restart"):
		get_tree().reload_current_scene.call_deferred()

func remaining_zombies() -> int:
	return get_tree().get_nodes_in_group("zombies").size()

func _spawn_zombie() -> void:
	if player.dead or remaining_zombies() >= max_zombies:
		return
	var zombie := ZOMBIE.instantiate() as SurvivorZombie
	zombie.target = player
	zombie.position = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(430.0, 520.0)
	zombie.died.connect(_on_zombie_died)
	actors.add_child(zombie)

func _on_zombie_died(at: Vector2) -> void:
	kills += 1
	_spawn_pickup.call_deferred(at)

func _spawn_pickup(at: Vector2) -> void:
	var pickup := PICKUP.instantiate() as Area2D
	pickup.position = at
	actors.add_child(pickup)

func _update_hud() -> void:
	hud.update_player(player)

func _on_player_died() -> void:
	spawn_timer.stop()
	hud.show_death()

func _draw() -> void:
	# A world-space grid keeps movement readable in an otherwise open arena.
	var center := player.global_position.snapped(Vector2(64, 64))
	for index in range(-13, 14):
		var offset := float(index * 64)
		draw_line(center + Vector2(offset, -832), center + Vector2(offset, 832), Color("18282f"))
		draw_line(center + Vector2(-832, offset), center + Vector2(832, offset), Color("18282f"))
