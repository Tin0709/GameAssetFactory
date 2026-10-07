extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level = preload("res://scenes/CuboidGameplayTest.tscn").instantiate()
	root.add_child(level)
	var audio = level.get_node("Combat/Audio")
	assert(audio.silent_review, "Gameplay test must use silent review")
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Master must be muted")
	for event in audio.STREAMS:
		audio.play_event(event)
	for i in 3:
		await process_frame
	for event in audio.players:
		assert(not audio.players[event].playing, "Silent review started an audio voice")
		assert(audio.last_played[event] == -1000, "Silent review consumed an audio event")
	print("PASS: gameplay test Master muted; all 10 sound events suppressed")
	quit()
