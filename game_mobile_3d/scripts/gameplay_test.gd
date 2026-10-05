extends Node3D

var status_elapsed: float = 0.0
@onready var player: CharacterBody3D = $Actors/Player
@onready var combat: Node = $Combat
@onready var progression: Node = $Progression

func _ready() -> void:
	if not OS.is_debug_build() or not progression.debug_exp_shortcut:
		$HUD/Help/Text.text = $HUD/Help/Text.text.replace("\nDebug build: L grants a level-up.", "")
	player.health_changed.connect(_health_updated)
	player.exp_changed.connect(_exp_updated)
	update_status()

func _health_updated(_hp: int, _max_hp: int) -> void:
	update_status()

func _exp_updated(_exp: int) -> void:
	update_status()

func update_status() -> void:
	$HUD/Status.text = "HP %d/%d  |  Level %d  |  Living zombies %d  |  %.2f m/s  |  %d FPS\n%s" % [
		player.current_hp, player.max_hp, player.level, combat.living_zombies.size(),
		player.current_speed, Engine.get_frames_per_second(), "Defeated — R to reset" if player.is_dead else
		("Choose an upgrade" if progression.selection_open else
		("Arena cleared — collect EXP or R to reset" if combat.living_zombies.is_empty() else "Auto-fire active  |  Shift to run"))]

	$HUD/ExpBar.max_value = progression.required_exp()
	$HUD/ExpBar.value = player.experience
	$HUD/ExpText.text = "EXP %d / %d" % [player.experience, progression.required_exp()]

func _process(delta: float) -> void:
	status_elapsed += delta
	if status_elapsed >= 0.25:
		status_elapsed = 0.0
		update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"):
		get_tree().reload_current_scene()
