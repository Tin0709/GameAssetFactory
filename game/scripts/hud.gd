extends CanvasLayer

@onready var level_label: Label = $Panel/Margin/Rows/Level
@onready var experience_bar: ProgressBar = $Panel/Margin/Rows/Experience
@onready var details: Label = $Panel/Margin/Rows/Details
@onready var status: Label = $Panel/Margin/Rows/Status

func update_player(player: SurvivorPlayer) -> void:
	level_label.text = "LEVEL %d  ·  EXP %d / %d" % [player.level, player.experience, player.experience_required]
	experience_bar.max_value = player.experience_required
	experience_bar.value = player.experience
	details.text = "HP %d / %d   |   Pistol: 1 damage · 2 shots/s" % [player.health, player.max_health]

func set_status(zombies: int, kills: int, elapsed: float) -> void:
	status.text = "Zombies %d   ·   Kills %d   ·   Time %ds" % [zombies, kills, int(elapsed)]

func show_death() -> void:
	$DeathMessage.show()
