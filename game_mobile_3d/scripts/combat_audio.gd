extends Node
## Fixed voice counts; scene-owned players let death tails finish after enemy removal.

const STREAMS = {
	&"pistol_shot": preload("res://assets/audio/pistol_shot.mp3"),
	&"bullet_impact": preload("res://assets/audio/bullet_impact.wav"),
	&"zombie_hit": preload("res://assets/audio/zombie_hit.mp3"),
	&"zombie_death": preload("res://assets/audio/zombie_death.mp3"),
	&"player_hurt": preload("res://assets/audio/player_hurt.mp3"),
	&"exp_pickup": preload("res://assets/audio/exp_pickup.mp3"),
	&"zombie_attack": preload("res://assets/audio/zombie_attack.mp3"),
	&"player_death": preload("res://assets/audio/player_death.mp3"),
	&"level_up": preload("res://assets/audio/level_up.mp3"),
	&"upgrade_selected": preload("res://assets/audio/upgrade_selected.mp3")
}
@export var minimum_event_interval: float = 0.045
var players: Dictionary = {}
var last_played: Dictionary = {}

func _ready() -> void:
	for event in STREAMS:
		var voice := AudioStreamPlayer.new()
		voice.stream = STREAMS[event]
		if event in [&"level_up", &"upgrade_selected"]:
			voice.process_mode = Node.PROCESS_MODE_ALWAYS
		voice.max_polyphony = 3
		if event in [&"level_up", &"upgrade_selected"]: voice.max_polyphony = 1
		voice.volume_db = -16.0 if event in [&"pistol_shot", &"bullet_impact"] else -12.0
		add_child(voice)
		players[event] = voice
		last_played[event] = -1000

func play_event(event: StringName) -> void:
	# Dummy audio cannot reliably drain compressed sounds during headless shutdown.
	if DisplayServer.get_name() == "headless": return
	var voice: AudioStreamPlayer = players.get(event)
	if voice == null: return
	var now := Time.get_ticks_msec()
	# Coalesce simultaneous enemy impacts/pickups without changing combat timing.
	if now - int(last_played[event]) < int(minimum_event_interval * 1000.0): return
	last_played[event] = now
	voice.play()

func _exit_tree() -> void:
	for voice in players.values():
		voice.stop()
		voice.stream = null
	players.clear()
	last_played.clear()
