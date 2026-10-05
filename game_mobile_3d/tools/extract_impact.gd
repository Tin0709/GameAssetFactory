extends SceneTree

func _initialize() -> void:
	call_deferred("_extract")

func _extract() -> void:
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes("C:/Users/ADMIN/Desktop/GameAssetFactory/audio/game/Bullet impact.mp3")
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "ImpactExtraction")
	AudioServer.set_bus_volume_db(bus, -80.0)
	var recording := AudioEffectRecord.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, recording)
	var player := AudioStreamPlayer.new()
	player.bus = "ImpactExtraction"
	player.stream = stream
	root.add_child(player)
	recording.set_recording_active(true)
	player.play()
	await create_timer(stream.get_length() + 0.3).timeout
	recording.set_recording_active(false)
	player.stop()
	var wav := recording.get_recording()
	print("IMPACT DECODE: length=", stream.get_length(), " recorded bytes=", wav.data.size())
	if wav.data.is_empty():
		quit(1)
		return
	wav.save_to_wav("res://.godot/impact_recording.wav")
	player.stream = null
	player.queue_free()
	quit()

