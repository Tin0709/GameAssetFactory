extends Node3D

var status_elapsed: float = 0.0
@onready var player: CharacterBody3D = $Actors/Player
@onready var combat: Node = $Combat
@onready var progression: Node = $Progression
@onready var spawner: Node = $SpawnDirector

func _ready() -> void:
	$HUD/AnimationDebug.visible = OS.is_debug_build()
	if not OS.is_debug_build() or not progression.debug_exp_shortcut:
		$HUD/Help/Text.text = $HUD/Help/Text.text.replace("\nDebug: L level-up  |  K spawn 1  |  J spawn 10", "")
	player.health_changed.connect(_health_updated)
	player.exp_changed.connect(_exp_updated)
	update_status()

func _health_updated(_hp: int, _max_hp: int) -> void:
	update_status()

func _exp_updated(_exp: int) -> void:
	update_status()

func update_status() -> void:
	var seconds := int(spawner.elapsed_survival)
	$HUD/Status.text = "Survived %02d:%02d  |  Alive %d / %d  |  Kills %d\nHP %d/%d  |  Level %d  |  %.2f m/s  |  %d FPS\n%s" % [
		seconds / 60, seconds % 60, combat.living_zombies.size(), spawner.max_active_zombies, combat.kill_count,
		player.current_hp, player.max_hp, player.level, player.current_speed, Engine.get_frames_per_second(),
		"Defeated — R to reset" if player.is_dead else ("Choose an upgrade" if progression.selection_open else
		("Next perimeter spawn incoming" if combat.living_zombies.is_empty() else "Auto-fire active  |  Shift to run"))]

	$HUD/ExpBar.max_value = progression.required_exp()
	$HUD/ExpBar.value = player.experience
	$HUD/ExpText.text = "EXP %d / %d" % [player.experience, progression.required_exp()]
	if OS.is_debug_build():
		$HUD/AnimationDebug.text = player.visual.debug_text() + "\n1 Pistol  |  2 M4A1  |  3 Shotgun"

func _process(delta: float) -> void:
	status_elapsed += delta
	if status_elapsed >= 0.25:
		status_elapsed = 0.0
		update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_test"):
		get_tree().reload_current_scene()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_K: spawner.debug_spawn(1)
		elif event.physical_keycode == KEY_J: spawner.debug_spawn(10)
