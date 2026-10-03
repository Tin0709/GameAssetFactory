extends Node
## Persistent audio players let death sounds finish after their zombie is freed.

const EVENTS = [&"pistol_shot", &"bullet_impact", &"zombie_hit", &"zombie_death", &"exp_pickup", &"level_up"]
var players: Dictionary = {}

func _ready() -> void:
	for event in EVENTS:
		var player := AudioStreamPlayer.new()
		player.name = String(event)
		player.max_polyphony = 8
		player.volume_db = -10.0
		add_child(player)
		players[event] = player
		for extension in ["ogg", "wav", "mp3"]:
			var path := "res://assets/audio/%s.%s" % [event, extension]
			if ResourceLoader.exists(path):
				player.stream = load(path) as AudioStream
				break

func play(event: StringName) -> void:
	# The headless dummy audio driver cannot drain MP3 playback at shutdown.
	if DisplayServer.get_name() == "headless":
		return
	var player: AudioStreamPlayer = players.get(event)
	if player != null and player.stream != null:
		player.play()

func _exit_tree() -> void:
	for player in players.values():
		player.stop()
		player.stream = null
	players.clear()
