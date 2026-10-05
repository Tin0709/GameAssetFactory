extends Node
## Processes an entire grant, then resolves one selection per earned level.
const CATALOG = preload("res://scripts/upgrade_catalog.gd")
@export var enabled: bool = true
@export var base_requirement: int = 3
@export var requirement_growth: int = 2
@export var debug_exp_shortcut: bool = true
var player: CharacterBody3D
var pistol: Node
var combat: Node
var overlay: Control
var pending_levels: int = 0
var selection_open: bool = false
var selection_locked: bool = false
var choices: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_parent().get_node("Actors/Player")
	pistol = player.get_node("Pistol")
	combat = get_parent().get_node("Combat")
	overlay = get_parent().get_node("HUD/UpgradeSelection")
	overlay.progression = self
	player.progression = self
	rng.randomize()

func required_exp(for_level: int = -1) -> int:
	var level: int = player.level if for_level < 0 else for_level
	return maxi(1, base_requirement + (level - 1) * requirement_growth)

func gain_exp(amount: int) -> void:
	if amount <= 0 or player.is_dead or selection_open or get_tree().paused: return
	player.total_experience += amount
	player.experience += amount
	if enabled:
		while player.experience >= required_exp():
			player.experience -= required_exp()
			player.level += 1
			pending_levels += 1
	player.exp_changed.emit(player.experience)
	if pending_levels > 0: _open_selection()

func _open_selection() -> void:
	selection_open = true
	selection_locked = false
	choices = CATALOG.available(player, pistol)
	# Partial Fisher-Yates; unique table entries and a scene-local RNG.
	for i in range(3):
		var j := rng.randi_range(i, choices.size() - 1)
		var saved := choices[i]
		choices[i] = choices[j]
		choices[j] = saved
	choices.resize(3)
	get_tree().paused = true
	overlay.show_choices(choices, player.level - pending_levels + 1, pending_levels)
	combat.play_sound(&"level_up")
	get_parent().update_status()

func select_upgrade(index: int) -> bool:
	if not selection_open or selection_locked or index < 0 or index >= choices.size(): return false
	selection_locked = true
	CATALOG.apply(choices[index], player, pistol)
	combat.play_sound(&"upgrade_selected")
	overlay.react_to_selection(index)
	var tween := create_tween()
	tween.tween_interval(0.10)
	tween.tween_callback(_finish_selection)
	return true

func _finish_selection() -> void:
	pending_levels -= 1
	if pending_levels > 0:
		_open_selection()
	else:
		selection_open = false
		selection_locked = false
		choices.clear()
		overlay.hide()
		get_tree().paused = false
		get_parent().update_status()

func debug_grant_level() -> bool:
	if not debug_exp_shortcut or not OS.is_debug_build() or not enabled or selection_open or player.is_dead: return false
	gain_exp(required_exp() - player.experience)
	return true

func reset_run() -> void:
	selection_open = false
	selection_locked = true
	get_tree().paused = false
	get_parent().reset_run()

func _exit_tree() -> void:
	if selection_open: get_tree().paused = false
