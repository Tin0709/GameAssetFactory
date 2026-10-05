extends Node3D

var status_elapsed: float = 0.0
@onready var player: CharacterBody3D = $Actors/Player
@onready var combat: Node = $Combat

func _ready() -> void:
	player.health_changed.connect(_health_updated)
	player.exp_changed.connect(_exp_updated)
	update_status()

func _health_updated(_hp: int, _max_hp: int) -> void:
	update_status()

func _exp_updated(_exp: int) -> void:
	update_status()

func update_status() -> void:
	$HUD/Status.text = "HP %d/%d  |  EXP %d  |  Living zombies %d  |  %d FPS\n%s" % [
		player.current_hp, player.max_hp, player.experience, combat.living_zombies.size(),
		Engine.get_frames_per_second(), "Defeated — R to reset" if player.is_dead else
		("Arena cleared — collect EXP or R to reset" if combat.living_zombies.is_empty() else "Auto-fire active  |  Shift to run")]

func _process(delta: float) -> void:
	status_elapsed += delta
	if status_elapsed >= 0.25:
		status_elapsed = 0.0
		update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"):
		get_tree().reload_current_scene()
