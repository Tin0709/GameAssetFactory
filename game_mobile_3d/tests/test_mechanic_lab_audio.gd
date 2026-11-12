
extends SceneTree

const COMBAT_AUDIO = preload("res://scripts/mechanic_lab_combat_audio.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func tone() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 48000
	var data := PackedByteArray()
	data.resize(48000)
	for i in 24000:
		var t := float(i) / stream.mix_rate
		data.encode_s16(2 * i, roundi(5000.0 * (sin(TAU * 1000.0 * t) + sin(TAU * 8000.0 * t))))
	stream.data = data
	return stream

func band_power(frames: PackedVector2Array, hz: float) -> float:
	var x := 0.0
	var y := 0.0
	var count := mini(4800, frames.size() - 4800)
	for i in count:
		var phase := TAU * hz * i / AudioServer.get_mix_rate()
		var sample := frames[4800 + i].x
		x += sample * cos(phase)
		y += sample * sin(phase)
	return (x * x + y * y) / float(count * count) if count > 0 else 0.0

func capture_ratio(voice: AudioStreamPlayer3D, capture: AudioEffectCapture) -> float:
	voice.stop()
	await create_timer(0.08).timeout
	capture.clear_buffer()
	voice.play()
	await create_timer(0.35).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	voice.stop()
	var low := band_power(frames, 1000.0)
	return band_power(frames, 8000.0) / low if low > 0.00000001 else -1.0

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var audio := COMBAT_AUDIO.new()
	root.add_child(audio)
	AudioServer.set_bus_mute(0, true)
	audio.set_enabled(true, Vector3.ZERO)
	check(not AudioServer.is_bus_mute(0), "Audio toggle enables playback")
	for group in {&"hit": 5, &"hurt": 3, &"death": 3, &"slam": 3}:
		check(audio._groups.get(group, []).size() == {&"hit": 5, &"hurt": 3, &"death": 3, &"slam": 3}[group],
			"All pinned MD2 variants decode for " + str(group))
	audio.reset()
	audio.contact(Vector3.FORWARD * 2.0, 7, false)
	var hit_voice: AudioStreamPlayer3D = audio._voices[0]
	var hit: AudioStream = hit_voice.stream
	check(hit != null, "First contact plays the Sabre hit")
	for i in 12:
		audio.contact(Vector3.FORWARD * 2.0, 7, i % 2 == 0)
	check(hit_voice.stream == hit and hit_voice.playing, "Reaction burst never steals the current Sabre hit")
	audio.set_enabled(false, Vector3.ZERO)
	check(AudioServer.is_bus_mute(0) and not audio._voices.any(func(v): return v.playing or v.stream != null),
		"Audio toggle stops all voices and restores the project mute")

	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, &"MechanicLabAudioTest")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture)
	hit_voice.bus = &"MechanicLabAudioTest"
	hit_voice.global_position = Vector3.FORWARD * 4.0
	hit_voice.stream = tone()
	hit_voice.volume_db = -11.0
	hit_voice.max_db = -11.0
	var configured_db := hit_voice.attenuation_filter_db
	var configured_cutoff := hit_voice.attenuation_filter_cutoff_hz
	hit_voice.attenuation_filter_db = -24.0
	hit_voice.attenuation_filter_cutoff_hz = 5000.0
	var previous := await capture_ratio(hit_voice, capture)
	hit_voice.attenuation_filter_db = configured_db
	hit_voice.attenuation_filter_cutoff_hz = configured_cutoff
	var revised := await capture_ratio(hit_voice, capture)
	check(previous > 0.0 and revised > previous * 2.0 and revised > 0.90,
		"Combat voice preserves the 8 kHz test tone relative to 1 kHz")
	print("MECHANIC_LAB_AUDIO ", JSON.stringify({"checks": checks, "failures": failures,
		"old_high_low_power_ratio": previous, "new_high_low_power_ratio": revised}))
	audio.free()
	camera.free()
	AudioServer.remove_bus(bus)
	quit(0 if failures.is_empty() else 1)

