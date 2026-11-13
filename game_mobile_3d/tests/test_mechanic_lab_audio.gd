
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

func next_zombie_hit(lab, capture: AudioEffectCapture = null) -> int:
	var before: int = lab.player_health
	for i in 180:
		await physics_frame
		if lab.player_health < before:
			return before - lab.player_health
		if capture != null:
			capture.clear_buffer()
	return 0

func check_movement_audio(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var movement = lab.get_node_or_null("MovementAudio")
	check(movement != null, "MechanicLab connects player contacts to a movement audio node")
	if movement == null:
		lab.free()
		return
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	check(not toggle.button_pressed and not movement.footsteps_enabled
		and movement.groups.get("grass", []).size() == 6 and movement.rejected_count == 0,
		"All six private grass samples load while lab audio starts muted")
	for voice: AudioStreamPlayer3D in movement.step_voices:
		voice.bus = AudioServer.get_bus_name(bus)
	Input.action_press("move_forward")
	for i in 35:
		await physics_frame
	check(movement.event_count.grass == 0, "Muted locomotion schedules no sounds")
	Input.action_release("move_forward")
	for i in 25:
		await physics_frame
	toggle.button_pressed = true
	for i in 20:
		await physics_frame
	check(movement.event_count.grass == 0, "Idle on grass schedules no steps")
	capture.clear_buffer()
	Input.action_press("move_forward")
	for i in 65:
		await physics_frame
	var steps: int = movement.event_count.grass
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(steps >= 3 and peak > 0.001 and peak < 0.9,
		"Movement contacts send MD2 grass steps to the mixer with headroom")
	Input.action_press("jump")
	for i in 10:
		await physics_frame
		if not lab.player._grounded:
			break
	Input.action_release("jump")
	var before_landing: int = movement.event_count.grass
	var stayed_quiet := true
	for i in 75:
		await physics_frame
		if lab.player._grounded:
			break
		stayed_quiet = stayed_quiet and movement.event_count.grass == before_landing
	check(lab.player._grounded and stayed_quiet and movement.event_count.landing == 1
		and movement.event_count.grass == before_landing
		and movement.last_sources.get("land_grass", "").begins_with("sfx_player_land_grassPath_"),
		"A normal jump plays the pinned MD2 landing family without adding a grass footstep")
	toggle.button_pressed = false
	check(not movement.footsteps_enabled and not movement.step_voices.any(func(voice): return voice.playing),
		"Turning off lab audio stops movement voices immediately")
	Input.action_release("move_forward")
	print("MECHANIC_LAB_MOVEMENT_AUDIO steps=", steps, " landing=", movement.event_count.landing, " pcm_peak=", peak)
	lab.free()

func check_local_hurt(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var audio = lab.get_node("CombatAudio")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	check(not toggle.button_pressed and not audio.enabled and AudioServer.is_bus_mute(0),
		"The lab starts with the combat mix muted")
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var muted_damage := await next_zombie_hit(lab)
	check(muted_damage == 6 and audio._next_choice.get(&"player_hurt", 0) == 0
		and audio._next_choice.get(&"zombie_windup", 0) == 0 and audio._next_choice.get(&"zombie_hit", 0) == 0,
		"Zombie attacks while muted schedule no combat samples")
	toggle.button_pressed = true
	var before_windup: int = lab.player_health
	for i in 180:
		if audio._next_choice.get(&"zombie_windup", 0) == 1 or lab.player_health < before_windup:
			break
		await physics_frame
	check(audio._next_choice.get(&"zombie_windup", 0) == 1 and lab.player_health == before_windup,
		"The zombie telegraph plays before damage")
	var local_voice := audio.get_node_or_null("PlayerHurt") as AudioStreamPlayer
	check(local_voice != null and audio._groups.get(&"player_hurt", []).size() == 3,
		"Three pinned MD2 player-hurt files decode into a local stereo voice")
	if local_voice != null:
		local_voice.bus = AudioServer.get_bus_name(bus)
		capture.clear_buffer()
		var heard_damage := await next_zombie_hit(lab, capture)
		check(heard_damage == 6 and local_voice.stream in audio._groups[&"player_hurt"]
			and audio._next_choice.get(&"player_hurt", 0) == 1,
			"Confirmed zombie contact starts the player-hurt voice in the same physics tick")
		check(audio._next_choice.get(&"zombie_hit", 0) == 1, "A confirmed strike also plays the zombie's contact cue")
		await create_timer(0.16).timeout
		var peak := 0.0
		for frame in capture.get_buffer(capture.get_frames_available()):
			peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		check(peak > 0.005 and peak < 0.5, "The local hurt cue reaches the mixer with headroom (peak %.4f)" % peak)
		print("MECHANIC_LAB_PLAYER_HURT_PEAK ", peak)
		for i in 180:
			if audio._next_choice.get(&"zombie_windup", 0) == 2:
				break
			await physics_frame
		var before_miss: int = lab.player_health
		lab.player.global_position += Vector3.RIGHT * 8.0
		await create_timer(0.5).timeout
		check(audio._next_choice.get(&"zombie_windup", 0) == 2
			and audio._next_choice.get(&"zombie_hit", 0) == 1 and lab.player_health == before_miss,
			"A windup plays once when the player leaves reach, without a contact cue")
		lab._on_player_hit(lab.player_health)
		check(lab.player_health == 0 and local_voice.playing, "The final hit plays through the defeat transition")
		toggle.button_pressed = false
		check(not local_voice.playing and local_voice.stream == null and AudioServer.is_bus_mute(0),
			"Turning audio off stops a live player-hurt cue and restores mute")
		await create_timer(0.1).timeout
	lab.free()

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var audio := COMBAT_AUDIO.new()
	root.add_child(audio)
	AudioServer.set_bus_mute(0, true)
	audio.set_enabled(true, Vector3.ZERO)
	check(not AudioServer.is_bus_mute(0), "Audio toggle enables playback")
	var expected := {&"hit": 5, &"hurt": 3, &"death": 3, &"slam": 3, &"slam_grass": 6,
		&"zombie_windup": 4, &"zombie_hit": 4}
	for group in expected:
		check(audio._groups.get(group, []).size() == expected[group],
			"All pinned MD2 variants decode for " + str(group))
	audio.reset()
	audio.contact(Vector3.FORWARD * 2.0, 7, false)
	var hit_voice: AudioStreamPlayer3D
	for voice in audio._voices:
		if voice.stream in audio._groups.get(&"hit", []):
			hit_voice = voice
			break
	check(hit_voice != null, "First contact plays the Sabre hit")
	if hit_voice == null:
		quit(1)
		return
	var hit: AudioStream = hit_voice.stream
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
	hit_voice.stream = null
	audio.set_enabled(true, Vector3.FORWARD * 2.0)
	audio.reset()
	for voice in audio._voices:
		voice.bus = &"MechanicLabAudioTest"
	audio.slam_landed(Vector3.FORWARD * 2.0)
	check(audio._next_choice.get(&"slam_grass", 0) == 1 and audio._next_choice.get(&"slam", 0) == 0,
		"Sabre landing selects the grass debris and no Sword-only layer")
	audio.reset()
	audio.sword_equipped = true
	capture.clear_buffer()
	audio.slam_landed(Vector3.FORWARD * 2.0)
	audio.contact(Vector3.FORWARD * 2.0, 8, false)
	audio.contact(Vector3.FORWARD * 2.0, 8, true)
	check(audio._next_choice.get(&"slam_grass", 0) == 2 and audio._next_choice.get(&"slam", 0) == 1,
		"Sword landing layers grass and Sword impact while hitting enemies")
	await create_timer(0.65).timeout
	var peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > 0.01 and peak < 0.9, "Simultaneous MD2 impact, slam and reactions have mix headroom")
	audio.set_enabled(false, Vector3.ZERO)
	await create_timer(0.08).timeout
	await check_local_hurt(bus, capture)
	await check_movement_audio(bus, capture)
	print("MECHANIC_LAB_AUDIO ", JSON.stringify({"checks": checks, "failures": failures,
		"old_high_low_power_ratio": previous, "new_high_low_power_ratio": revised, "source_mix_peak": peak}))
	AudioServer.remove_bus_effect(bus, 0)
	audio.queue_free()
	camera.queue_free()
	await process_frame
	AudioServer.remove_bus(bus)
	quit(0 if failures.is_empty() else 1)

