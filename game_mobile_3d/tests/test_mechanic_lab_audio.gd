
extends SceneTree

const COMBAT_AUDIO = preload("res://scripts/mechanic_lab_combat_audio.gd")
const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")
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
	var grass_rows: Array = movement.reader.data.audio.grass
	var moved_row: Dictionary = grass_rows[0].duplicate()
	var normalized := String(moved_row.path).replace("\\", "/")
	var extraction := normalized.rfind("/extracted/")
	check(extraction >= 0, "The verified grass sample belongs to the Research extraction")
	if extraction >= 0:
		moved_row.path = "Z:\\Old MD2 Research\\" + normalized.substr(extraction + 1).replace("/", "\\")
		var moved := movement.reader.audio_stream(moved_row) as AudioStreamOggVorbis
		check(moved != null and is_equal_approx(moved.get_length(), movement.groups.grass[0].stream.get_length()),
			"MechanicLab resolves an old absolute path to the same verified grass sample")
		moved_row.sha256 = "0".repeat(64)
		check(movement.reader.audio_stream(moved_row) == null, "A relocated grass sample still requires its original checksum")
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
	Input.action_release("move_forward")
	Input.action_press("jump")
	for i in 10:
		await physics_frame
		if not lab.player._grounded:
			break
	Input.action_release("jump")
	var before_landing: int = movement.event_count.grass
	var stayed_quiet := true
	for i in 75:
		capture.clear_buffer()
		await physics_frame
		if lab.player._grounded:
			break
		stayed_quiet = stayed_quiet and movement.event_count.grass == before_landing
	check(lab.player._grounded and stayed_quiet and movement.event_count.landing == 1
		and movement.event_count.grass == before_landing
		and movement.last_sources.get("land_grass", "").begins_with("sfx_player_land_grassPath_"),
		"A normal jump plays the pinned MD2 landing family without adding a grass footstep")
	for i in 12:
		await physics_frame
	var landing_peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		landing_peak = maxf(landing_peak, maxf(absf(sample.x), absf(sample.y)))
	check(landing_peak > 0.001 and landing_peak < 0.9, "The ordinary landing produces audible PCM with headroom")
	toggle.button_pressed = false
	check(not movement.footsteps_enabled and not movement.step_voices.any(func(voice): return voice.playing),
		"Turning off lab audio stops movement voices immediately")
	await check_movement_support(lab, movement, toggle)
	print("MECHANIC_LAB_MOVEMENT_AUDIO steps=", steps, " landing=", movement.event_count.landing,
		" step_peak=", peak, " landing_peak=", landing_peak)
	lab.free()

func check_movement_support(lab, movement, toggle: CheckButton) -> void:
	lab.reset_player()
	toggle.button_pressed = true
	var dust := lab.get_node("MovementDust") as Node3D
	var floor_body := lab.get_node("Ground") as StaticBody3D
	floor_body.position.y += 0.25
	lab.player.global_position += Vector3.UP * 0.75
	for i in 45:
		await physics_frame
	check(lab.player.is_on_floor(), "The raised grass floor physically supports the player")
	var landing_count: int = movement.event_count.landing
	check(lab.player.drop_for_lab(0.25), "The grass floor fixture starts a real ordinary drop")
	for i in 45:
		await physics_frame
		if movement.event_count.landing > landing_count:
			break
	var landed_at: Vector3 = lab.player.global_position
	var last_event: Dictionary = movement.events.back()
	check(movement.event_count.landing == landing_count + 1 and last_event.key == "land_grass"
		and is_equal_approx(float(last_event.at[1]), 0.25),
		"Ordinary landing audio uses the raised floor height instead of the posed soles")
	check(dust.get_children().any(func(particle): return particle.visible),
		"The supported ordinary landing still emits dust")
	dust.clear()
	var before: int = movement.events.size()
	lab.player.surface_contact.emit(landed_at + Vector3.UP * 2.0, false)
	lab.player.surface_contact.emit(Vector3(51.0, 0.25, 0.0), false)
	check(movement.events.size() == before and not dust.get_children().any(func(particle): return particle.visible),
		"Feet in the air or past the grass edge start neither steps nor grass dust")
	toggle.button_pressed = false
	await create_timer(0.08).timeout

func check_landing_voice_under_step_burst(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var movement = lab.get_node("MovementAudio")
	var player: CharacterBody3D = lab.player
	for i in 12:
		await physics_frame
	# Deliver the real movement event at grounded positions while the mixer
	# is waiting for its next update. Repeat after playback has started.
	var point := player.global_position
	player.surface_contact.emit(point, true)
	var landing: AudioStreamPlayer3D
	for voice: AudioStreamPlayer3D in movement.step_voices:
		if voice.playing and movement.groups.land_grass.any(func(row): return row.stream == voice.stream):
			landing = voice
			break
	check(landing != null, "A supported landing queues an original grass landing sample")
	if landing == null:
		lab.free()
		return
	var source := landing.stream
	for i in 4:
		player.surface_contact.emit(point + Vector3.RIGHT * (i + 1) * 0.1, false)
	check(landing.playing and landing.stream == source,
		"A burst of supported footsteps keeps the landing onset queued")
	landing.bus = AudioServer.get_bus_name(bus)
	capture.clear_buffer()
	await create_timer(0.12).timeout
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(landing.playing and landing.stream == source and landing.get_playback_position() > 0.0
		and peak > 0.001 and peak < 0.9, "The original landing reaches the isolated mixer through the burst")
	for i in 4:
		player.surface_contact.emit(point + Vector3.LEFT * (i + 1) * 0.1, false)
	check(landing.playing and landing.stream == source, "Further supported steps keep the active landing tail")
	toggle.button_pressed = false
	check(not landing.playing, "Muting stops the protected landing voice")
	print("MECHANIC_LAB_LANDING_VOICE peak=", peak, " preserved=", landing.stream == source)
	await create_timer(0.08).timeout
	lab.free()

func check_run_step_after_landing(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var movement = lab.get_node("MovementAudio")
	var player = lab.player
	var step_ticks: Array[int] = []
	player.surface_contact.connect(func(_point: Vector3, landed: bool):
		if not landed:
			step_ticks.append(Engine.get_physics_frames()))
	lab.reset_player()
	lab.get_node("HUD/CombatAudioToggle").button_pressed = true
	for voice: AudioStreamPlayer3D in movement.step_voices:
		voice.bus = AudioServer.get_bus_name(bus)
	for i in 3:
		await physics_frame
	Input.action_press("move_forward")
	for i in 28:
		await physics_frame
	var landing_before: int = movement.event_count.landing
	Input.action_press("jump")
	for i in 9:
		await physics_frame
		if not player._grounded:
			break
	Input.action_release("jump")
	for i in 75:
		await physics_frame
		if movement.event_count.landing > landing_before:
			break
	var steps_before: int = movement.event_count.grass
	var touchdown: float = player.simulation_clock
	step_ticks.clear()
	var landing: AudioStreamPlayer3D
	for voice: AudioStreamPlayer3D in movement.step_voices:
		if voice.playing and movement.groups.land_grass.any(func(row): return row.stream == voice.stream):
			landing = voice
			break
	check(landing != null and movement.event_count.landing == landing_before + 1,
		"The running jump queues one grass landing")
	if landing == null:
		Input.action_release("move_forward")
		lab.free()
		return
	var landing_source := landing.stream
	await physics_frame
	check(movement.event_count.grass == steps_before, "The touchdown pose does not add an immediate footstep")

	var zombies := lab.get_node("Zombies")
	var ear: Vector3 = lab.get_node("CombatAudio").zombie_listener.global_position
	capture.clear_buffer()
	for tick in 7:
		for i in 100:
			zombies.zombie_attack_audio.emit(ear + Vector3(2.0, 0.0, i * 0.08), true)
		await physics_frame
	var step_voice: AudioStreamPlayer3D
	for voice: AudioStreamPlayer3D in movement.step_voices:
		if voice.playing and movement.groups.grass.any(func(row): return row.stream == voice.stream):
			step_voice = voice
			break
	check(movement.event_count.grass == steps_before + 1 and step_voice != null
		and landing.playing and landing.stream == landing_source,
		"The first new running plant plays alongside the landing during a zombie cue burst")
	var dust := lab.get_node("MovementDust")
	var wind := lab.get_node("MovementWind")
	var contact_tick := step_ticks[0] if not step_ticks.is_empty() else -1
	check(step_ticks.size() == 1
		and dust._particles.any(func(puff): return puff.contact_tick == contact_tick and puff.sprite.visible)
		and wind._wakes.any(func(wake): return wake.contact_tick == contact_tick and wake.mesh.visible),
		"The restored running plant starts dust and wind on the same physics tick")
	check(player.simulation_clock - touchdown < 0.15, "The fixture samples the first tenth-second after touchdown")
	Input.action_release("move_forward")
	await create_timer(0.10).timeout
	if step_voice != null:
		check(step_voice.get_playback_position() > 0.0, "The first new running step reaches the mixer")
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(peak > 0.001 and peak < 0.9, "The post-landing movement mix has headroom")
	print("MECHANIC_LAB_POST_LANDING_STEP count=", movement.event_count.grass - steps_before, " peak=", peak)
	lab.free()

func check_crossbow_fire_under_impact_burst(audio: Node, bus: int, capture: AudioEffectCapture) -> void:
	audio.load_crossbow(audio._research_root())
	audio.reset()
	var point := Vector3.FORWARD * 2.0
	audio.crossbow_fired(point)
	var fire_samples: Array = audio._groups.get(&"crossbow_fire", [])
	var fire: AudioStreamPlayer3D
	for voice: AudioStreamPlayer3D in audio._voices:
		if voice.playing and voice.stream in fire_samples:
			fire = voice
			break
	check(fire != null, "Polaris queues the original firing sample")
	if fire == null:
		return
	var source := fire.stream
	for i in 25:
		audio.crossbow_impact(point + Vector3.RIGHT * i * 0.1)
	check(fire.playing and fire.stream == source
		and audio._next_choice.get(&"crossbow_hit", -1) == 2,
		"A simultaneous volley of impacts keeps the firing onset and two impact cues")
	var bus_name := AudioServer.get_bus_name(bus)
	for voice: AudioStreamPlayer3D in audio._voices:
		voice.bus = &"Master"
	fire.bus = bus_name
	capture.clear_buffer()
	await create_timer(0.11).timeout
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(fire.stream == source and peak > 0.001 and peak < 0.9,
		"The isolated original firing sample reaches the mixer through the impacts")
	print("MECHANIC_LAB_CROSSBOW_FIRE peak=", peak)
	fire.bus = &"Master"
	audio.reset()
	for i in 3:
		audio.crossbow_impact(point)
	audio.crossbow_fired(point)
	check(audio._voices.any(func(voice): return voice.playing and voice.stream in fire_samples),
		"Polaris can still fire when the impacts arrive first on the same tick")
	audio.reset()

func check_bow_fire_during_crossbow_impacts(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	for i in 12:
		await physics_frame
	var menu := lab.get_node("HUD/Weapon") as OptionButton
	for weapon in [3, 6]:
		menu.select(weapon)
		menu.item_selected.emit(weapon)
	var audio = lab.get_node("CombatAudio")
	var samples: Array = audio._groups.get(&"bow_fire", [])
	check(lab._bow != null and samples.size() == 3, "Standard Bow loads its three source firing samples")
	if lab._bow == null or samples.is_empty():
		lab.free()
		return
	var point: Vector3 = lab.player.global_position + Vector3.UP
	audio.set_enabled(true, point)
	audio.reset()
	# Reset selects the first weapon voice. Route it before playback starts
	# so its short firing onset reaches the capture bus from the first mix.
	var firing := audio._voices[0] as AudioStreamPlayer3D
	firing.bus = AudioServer.get_bus_name(bus)
	capture.clear_buffer()
	var impact_before: int = audio._next_choice.get(&"crossbow_hit", 0)
	lab._bow.fire_arrow(point, Vector3.FORWARD, 1, point, true)
	# Bolts can land on the following physics tick after Bow fires.
	await physics_frame
	for i in 25:
		audio.crossbow_impact(point + Vector3.RIGHT * float(i) * 0.1)
	check(firing.playing and firing.stream in samples
		and audio._next_choice.get(&"crossbow_hit", 0) == (impact_before + 2) % 3,
		"A Bow release keeps its pinned sample through next-tick impacts from old crossbow bolts")
	# Wait for the mixer to advance, since the headless audio driver can
	# deliver several physics ticks' worth of audio in one batch.
	for i in 30:
		if firing.get_playback_position() >= 0.1 and capture.get_frames_available() > 0:
			break
		await physics_frame
	var peak := 0.0
	for value in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(value.x), absf(value.y)))
	check(peak > 0.001 and peak < 0.9, "Standard Bow's firing onset reaches the isolated mixer")
	print("MECHANIC_LAB_BOW_FIRE peak=", peak)
	audio.reset()
	for i in 3:
		audio.crossbow_impact(point)
	lab._bow.fire_arrow(point, Vector3.FORWARD, 2, point, false)
	check(audio._voices.any(func(voice): return voice.playing and voice.stream in samples),
		"Bow can fire when old crossbow impacts fill the shared voices first")
	audio.set_enabled(false, point)
	lab.free()

func check_weapon_onsets_under_mixed_impacts(audio: Node, bus: int, capture: AudioEffectCapture) -> void:
	audio.set_enabled(true, Vector3.ZERO)
	audio.reset()
	audio.sword_equipped = true
	var point := Vector3.FORWARD * 2.0
	var weapon_voices: Array[AudioStreamPlayer3D] = audio._voices.slice(0, audio.VOICES_PER_POOL)
	var firing := weapon_voices[0] as AudioStreamPlayer3D
	firing.bus = AudioServer.get_bus_name(bus)
	capture.clear_buffer()
	audio.crossbow_fired(point)
	var fire_stream := firing.stream
	audio.crossbow_impact(point)
	audio.crossbow_impact(point)
	audio.contact(point, 601, false)
	audio.slam_landed(point)
	check(fire_stream in audio._groups[&"crossbow_fire"] and firing.playing and firing.stream == fire_stream,
		"A melee hit and landing preserve a crossbow firing onset queued on the same tick")
	var sword_voice: AudioStreamPlayer3D
	var landing_voice: AudioStreamPlayer3D
	for voice: AudioStreamPlayer3D in weapon_voices:
		if voice.stream in audio._groups[&"sword_hit"]:
			sword_voice = voice
		elif voice.stream in audio._groups[&"slam"]:
			landing_voice = voice
	check(sword_voice != null and landing_voice != null,
		"The confirmed sword hit and heavy landing each claim a bolt impact voice")
	var catch_up_frame := Engine.get_physics_frames() + ceili(0.10 * Engine.physics_ticks_per_second)
	if sword_voice != null and landing_voice != null:
		var hit_stream := sword_voice.stream
		var landing_stream := landing_voice.stream
		var choice: int = audio._next_choice.get(&"crossbow_fire", 0)
		# Advance multiple simulation ticks without yielding to the mixer.
		var next_shot: AudioStreamPlayer3D = audio._play(&"crossbow_fire", point, -9.0, catch_up_frame)
		check(next_shot == null and audio._next_choice.get(&"crossbow_fire", 0) == choice
			and firing.stream == fire_stream and sword_voice.stream == hit_stream
			and landing_voice.stream == landing_stream,
			"Later simulation ticks cannot steal weapon onsets that have yet to mix")
		await physics_frame
		for i in 25:
			audio.crossbow_impact(point + Vector3.RIGHT * i * 0.1)
		check(firing.stream == fire_stream and sword_voice.playing and sword_voice.stream == hit_stream
			and landing_voice.playing and landing_voice.stream == landing_stream,
			"Following-tick bolt impacts cannot steal the three active weapon onsets")
	var peak := 0.0
	for i in 24:
		await physics_frame
		for sample in capture.get_buffer(capture.get_frames_available()):
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		if peak > 0.001:
			break
	check(firing.stream == fire_stream and peak > 0.001 and peak < 0.9,
		"The protected firing stream reaches the Dummy mixer during mixed weapon cues")
	var deadline := Time.get_ticks_msec() + 500
	while firing.playing and firing.get_playback_position() < 0.08 and Time.get_ticks_msec() < deadline:
		await process_frame
	var firing_tail_ready := firing.playing and firing.get_playback_position() >= 0.08
	var all_slots_playing := weapon_voices.all(func(voice): return voice.playing)
	var next_shot: AudioStreamPlayer3D = audio._play(&"crossbow_fire", point, -9.0, catch_up_frame)
	check(firing_tail_ready and all_slots_playing and next_shot != null
		and next_shot.stream in audio._groups[&"crossbow_fire"],
		"A later shot can reclaim a weapon tail once its onset has reached the mixer")
	print("MECHANIC_LAB_MIXED_WEAPON_ONSETS peak=", peak)
	firing.bus = &"Master"
	audio.reset()
	audio.sword_equipped = false
	audio.set_enabled(false, point)

func check_overlapping_heavy_landings(audio: Node, bus: int, capture: AudioEffectCapture) -> void:
	audio.set_enabled(true, Vector3.ZERO)
	audio.reset()
	await create_timer(0.08).timeout
	var point := Vector3.FORWARD * 2.0
	var grass_samples: Array = audio._groups[&"slam_grass"]
	var first_choice: int = audio._next_choice.get(&"slam_grass", 0)
	var weapon_voices: Array[AudioStreamPlayer3D] = audio._voices.slice(0, COMBAT_AUDIO.VOICES_PER_POOL)
	var weapon_buses: Array[StringName] = []
	for voice in weapon_voices:
		weapon_buses.append(voice.bus)
		voice.bus = &"Master"
	for i in COMBAT_AUDIO.VOICES_PER_POOL:
		audio._play(&"hit", point, -9.0, -1, true)
	check(weapon_voices.size() == COMBAT_AUDIO.VOICES_PER_POOL and weapon_voices.all(func(voice): return voice.playing),
		"The weapon pool is filled with three pending hit onsets")
	var mix_bus := AudioServer.get_bus_name(bus)
	var surface_voices: Array[AudioStreamPlayer3D] = audio._surface_landing_voices
	var first_surface_bus := AudioServer.bus_count
	var surface_captures: Array[AudioEffectCapture] = []
	var surface_peaks: Array[float] = []
	for i in surface_voices.size():
		AudioServer.add_bus()
		var layer_bus := first_surface_bus + i
		var bus_name := StringName("HeavyLandingLayer%d" % i)
		AudioServer.set_bus_name(layer_bus, bus_name)
		AudioServer.set_bus_send(layer_bus, mix_bus)
		var layer_capture := AudioEffectCapture.new()
		layer_capture.buffer_length = 2.0
		AudioServer.add_bus_effect(layer_bus, layer_capture)
		surface_voices[i].bus = bus_name
		surface_captures.append(layer_capture)
		surface_peaks.append(0.0)
	capture.clear_buffer()
	var contacts := [point, point + Vector3.RIGHT, point + Vector3.LEFT]
	for contact in contacts:
		audio.slam_landed(contact)
	var layers := audio.get_children().filter(func(child):
		return child is AudioStreamPlayer3D and child.playing and child.stream in grass_samples)
	var samples_at: Dictionary[Vector3, AudioStream] = {}
	for voice: AudioStreamPlayer3D in layers:
		samples_at[voice.global_position] = voice.stream
	var positions_preserved := layers.size() == contacts.size()
	for i in contacts.size():
		var expected: AudioStream = grass_samples[(first_choice + i) % grass_samples.size()]
		positions_preserved = positions_preserved and samples_at.get(contacts[i]) == expected
	check(positions_preserved, "Three recent ground contacts reach separate voices with their original positions")
	check(weapon_voices.all(func(voice): return voice != null and voice.playing and voice.stream in audio._groups[&"hit"]),
		"The ground contacts preserve the three pending weapon onsets")
	# The audio clock can finish a short voice before a slow frame resumes.
	# The isolated buses retain the mixed samples from each landing.
	var peak := 0.0
	for tick in 24:
		await physics_frame
		for sample in capture.get_buffer(capture.get_frames_available()):
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		for i in surface_captures.size():
			var layer_capture := surface_captures[i]
			for sample in layer_capture.get_buffer(layer_capture.get_frames_available()):
				surface_peaks[i] = maxf(surface_peaks[i], maxf(absf(sample.x), absf(sample.y)))
		if peak > 0.001 and surface_peaks.all(func(value): return value > 0.001):
			break
	check(surface_peaks.size() == contacts.size() and surface_peaks.all(func(value): return value > 0.001)
		and peak > 0.001 and peak < 0.9, "Heavy landing debris alone reaches the silent mixer")
	audio.set_enabled(false, point)
	check(layers.all(func(voice): return not voice.playing and voice.stream == null),
		"Mute clears every active heavy ground contact")
	for voice in surface_voices:
		voice.bus = &"Master"
	for i in surface_captures.size():
		AudioServer.remove_bus(first_surface_bus)
	for i in weapon_voices.size():
		weapon_voices[i].bus = weapon_buses[i]
	print("MECHANIC_LAB_HEAVY_SURFACE layers=", layers.size(), " peaks=", surface_peaks, " mix_peak=", peak)

func check_sabre_debris_audio(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var audio = lab.get_node("CombatAudio")
	var movement = lab.get_node("MovementAudio")
	var dust: Node3D = lab.get_node("MovementDust")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var swing = lab.player.reference_audio
	for voice: AudioStreamPlayer in swing.voices:
		voice.bus = AudioServer.get_bus_name(bus)
	var landings: Array[int] = []
	var touchdown_points: Array[Vector3] = []
	lab.player.heavy_jump_landed.connect(func(point, _forward, _serial, _height):
		landings.append(Engine.get_physics_frames())
		touchdown_points.append(point))
	for attempt in 4:
		for i in 20:
			await physics_frame
		if attempt == 0:
			check(lab.player.drop_for_lab(16.0), "The extended drop exercises the airborne loop")
		else:
			lab.get_node("HUD/DropMedium").pressed.emit()
		var before_swing: int = swing.played_count
		for i in 2:
			await physics_frame
		var attack := InputEventKey.new()
		attack.physical_keycode = KEY_E
		attack.pressed = true
		root.push_input(attack, true)
		for i in 2:
			await physics_frame
		attack = InputEventKey.new()
		attack.physical_keycode = KEY_E
		root.push_input(attack, true)
		for i in Engine.physics_ticks_per_second:
			await physics_frame
			if landings.size() > attempt:
				break
		check(landings.size() == attempt + 1, "The audio fixture performs a real Sabre landing")
		if landings.size() != attempt + 1:
			break
		check(swing.played_count == before_swing, "The looping aerial Sabre pose is quiet before touchdown")
		var before := mini(attempt, 1)
		check(audio._next_choice.get(&"slam_grass", 0) == before,
			"Sabre floor contact waits for the montage debris cue")
		capture.clear_buffer()
		if attempt == 1:
			lab.reset_player()
		elif attempt == 2:
			toggle.button_pressed = false
			toggle.button_pressed = true
		elif attempt == 3:
			lab._on_player_hit(100)
		var playback_frame := -1
		var dust_frame := -1
		var swing_frame := -1
		var debris_frame := landings[attempt] + ceili(0.045126423 * Engine.physics_ticks_per_second)
		for i in 18:
			await physics_frame
			if attempt == 0 and Engine.get_physics_frames() == debris_frame:
				for cue in COMBAT_AUDIO.VOICES_PER_POOL:
					audio._play(&"hit", touchdown_points[attempt], -9.0, -1, true)
			if swing_frame < 0 and swing.played_count > before_swing:
				swing_frame = Engine.get_physics_frames() - 1
			if playback_frame < 0 and audio._next_choice.get(&"slam_grass", 0) != before:
				playback_frame = Engine.get_physics_frames() - 1
			if dust_frame < 0 and dust.get_children().any(func(particle): return particle.visible):
				dust_frame = Engine.get_physics_frames() - 1
		if attempt == 0:
			var swing_ticks := ceili(0.033083633 * Engine.physics_ticks_per_second)
			check(swing_frame == landings[attempt] + swing_ticks and swing.played_count == before_swing + 1,
				"Sabre plays one swing at the first authored post-audio key after landing")
			var touchdown := touchdown_points[attempt]
			var grass_voices: Array = audio.get_children().filter(func(voice):
				return voice is AudioStreamPlayer3D and voice.stream in audio._groups[&"slam_grass"])
			check(grass_voices.size() == 1 and grass_voices[0].global_position.is_equal_approx(
				Vector3(touchdown.x, 0.0, touchdown.z)),
				"The Sabre debris sample is positioned at the physical touchdown")
			var delay_ticks := ceili(0.045126423 * Engine.physics_ticks_per_second)
			check(playback_frame == landings[attempt] + delay_ticks and playback_frame == dust_frame
				and audio._next_choice.get(&"slam_grass", 0) == 1 and audio._next_choice.get(&"slam", 0) == 0,
				"Sabre plays exactly one verified grass sample on the same tick as its dust burst")
			var peak := 0.0
			for sample in capture.get_buffer(capture.get_frames_available()):
				peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			check(peak > 0.001 and peak < 0.9, "The timed Sabre swing reaches the isolated mixer bus")
			print("MECHANIC_LAB_SABRE_DEBRIS_AUDIO landing=", landings[attempt], " swing=", swing_frame,
				" playback=", playback_frame, " peak=", peak)
		else:
			check(playback_frame == -1 and swing_frame == -1 and swing.played_count == before_swing,
				"Reset, mute and defeat discard unplayed Sabre swing and grass cues")
	check(movement.event_count.landing == 0, "The heavy attack does not also play ordinary landing audio")
	toggle.button_pressed = false
	lab.free()

func check_sabre_crowd_audio(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var audio = lab.get_node("CombatAudio")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var reactions: Array[AudioStreamPlayer3D] = audio._voices.slice(COMBAT_AUDIO.VOICES_PER_POOL,
		2 * COMBAT_AUDIO.VOICES_PER_POOL)
	for voice in reactions:
		voice.bus = AudioServer.get_bus_name(bus)
	for i in 20:
		await physics_frame
	var hit_choice: int = audio._next_choice[&"hit"]
	var forward: Vector3 = lab.player.visual.global_basis.z
	var centre: Vector3 = lab.player.global_position + forward * 1.5
	var right := Vector3.UP.cross(forward)
	var health := [100, 8, 8, 8, 100, 100, 8]
	var group := lab.get_node("Zombies")
	for i in health.size():
		lab.get_node("HUD/SpawnZombie").pressed.emit()
		var zombie = group.get_child(i)
		zombie.set_physics_process(false)
		zombie.collision_layer = 0
		zombie.global_position = centre + right * (i - 3) * 0.35
		zombie.max_health = 100
		zombie.health = health[i]
	var deaths: Array[Vector3] = []
	var hits: Array[int] = []
	group.sabre_contact.connect(func(point, _direction, clip, _index, _serial, lethal):
		if clip == "AirAttack":
			hits.append(Engine.get_physics_frames())
			if lethal:
				deaths.append(point))
	lab.get_node("HUD/DropMedium").pressed.emit()
	for i in 2:
		await physics_frame
	var attack := InputEventKey.new()
	attack.physical_keycode = KEY_E
	attack.pressed = true
	root.push_input(attack, true)
	for i in 2:
		await physics_frame
	attack = InputEventKey.new()
	attack.physical_keycode = KEY_E
	root.push_input(attack, true)
	capture.clear_buffer()
	for i in Engine.physics_ticks_per_second:
		await physics_frame
		if not hits.is_empty():
			break
	print("MECHANIC_LAB_SABRE_CROWD hits=", hits, " deaths=", deaths.size(),
		" health=", group.get_children().map(func(zombie): return zombie.health))
	check(hits.size() == health.size() and hits.all(func(frame): return frame == hits[0])
		and deaths.size() == 4 and group.get_children().map(func(zombie): return zombie.health)
			== [60, 0, 0, 0, 60, 60, 0],
		"A real Sabre dive applies all seven hits on the same physics frame")
	check(audio._next_choice.get(&"hit", 0) == (hit_choice + 1) % 5,
		"A crowd dive still plays one weapon hit")
	await process_frame
	await process_frame
	var listener := lab.player.get_node("CombatAudioListener") as AudioListener3D
	var ear := listener.global_position
	deaths.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(ear) < b.distance_squared_to(ear))
	var audible_deaths: Array[Vector3] = []
	for voice in reactions:
		if voice.playing and voice.stream in audio._groups[&"death"]:
			audible_deaths.append(voice.global_position)
	check(audible_deaths.size() == 3 and audible_deaths.all(func(point): return point in deaths.slice(0, 3)),
		"The three nearest death cues play through same-frame overflow")
	check(audio._next_choice.get(&"death", -1) == 0 and audio._next_choice.get(&"hurt", 0) == 0,
		"Suppressed zombie reactions do not advance sample rotation")
	await create_timer(0.2).timeout
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(peak > 0.001 and peak < 0.9, "The isolated zombie reaction pool reaches the mixer with headroom")
	audio.reset()
	var points: Array[Vector3] = []
	for i in 100:
		var point := ear + Vector3(2.0, 0.0, (100 - i) * 0.04)
		points.append(point)
		audio.contact(point, 1001, false)
	await process_frame
	await process_frame
	var nearest := points.slice(-3)
	check(reactions.all(func(voice): return voice.stream in audio._groups[&"hurt"] and voice.global_position in nearest),
		"A far-first hurt burst plays the three nearest reactions")
	var hurt_choice: int = audio._next_choice.get(&"hurt", 0)
	for point in points:
		audio.contact(point, 1002, false)
		audio.contact(point, 1002, true)
	await process_frame
	await process_frame
	check(reactions.all(func(voice): return voice.stream in audio._groups[&"death"] and voice.global_position in nearest)
		and audio._next_choice.get(&"hurt", 0) == hurt_choice,
		"The nearest deaths replace active hurts without selecting suppressed hurt samples")
	# Model consecutive physics ticks delivering cues before a rendered frame.
	audio.reset()
	var onset_frame := Engine.get_physics_frames()
	var near_death_points := [ear + Vector3.RIGHT, ear + Vector3.RIGHT * 2.0, ear + Vector3.RIGHT * 3.0]
	for point: Vector3 in near_death_points:
		audio.contact(point, 1100, true)
	audio.flush_zombie_combat_cues()
	var death_variant: int = audio._next_choice[&"death"]
	var future := onset_frame + ceili(0.10 * Engine.physics_ticks_per_second)
	check(audio._play(&"death", ear + Vector3.RIGHT * 20.0, COMBAT_AUDIO.DEATH_GAIN_DB, future) == null
		and audio._next_choice[&"death"] == death_variant,
		"A fresh death onset survives simulation catch-up")
	await physics_frame
	audio.contact(ear + Vector3.RIGHT * 20.0, 1101, true)
	audio.flush_zombie_combat_cues()
	check(Engine.get_physics_frames() > onset_frame
		and reactions.all(func(voice): return voice.global_position in near_death_points)
		and audio._next_choice[&"death"] == death_variant,
		"A distant death on the next physics tick preserves the three nearby death onsets")
	var closest := ear + Vector3.RIGHT * 0.5
	audio.contact(closest, 1102, true)
	audio.flush_zombie_combat_cues()
	check(reactions.all(func(voice): return voice.global_position in [closest, near_death_points[0], near_death_points[1]]),
		"A closer death can replace the farthest recent onset")
	for i in 6:
		await physics_frame
	var onset_mixed := await wait_for_zombie_onset(reactions)
	var later_death := ear + Vector3.RIGHT * 10.0
	audio.contact(later_death, 1103, true)
	audio.flush_zombie_combat_cues()
	check(onset_mixed and reactions.any(func(voice): return voice.global_position == later_death),
		"A later kill can use a reaction voice after the earlier onsets")
	audio.reset()
	var death_choice: int = audio._next_choice.get(&"death", 0)
	audio.contact(ear + Vector3.RIGHT * 40.0, 1003, true)
	await process_frame
	await process_frame
	check(reactions.all(func(voice): return voice.stream == null)
		and audio._next_choice.get(&"death", 0) == death_choice,
		"An out-of-range death does not reserve a reaction voice")
	audio.contact(nearest[0], 1004, true)
	toggle.button_pressed = false
	await create_timer(0.08).timeout
	check(reactions.all(func(voice): return voice.stream == null), "Muting discards queued zombie reactions")
	lab.free()

func check_baby_zombie_reactions(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var group := lab.get_node("Zombies")
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	lab.get_node("HUD/SpawnBabyZombie").pressed.emit()
	check(group.get_child_count() == 2, "The reaction fixture loads both source zombie models")
	if group.get_child_count() != 2:
		lab.free()
		return
	for zombie in group.get_children():
		zombie.set_physics_process(false)
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var audio := lab.get_node("CombatAudio")
	var reactions: Array[AudioStreamPlayer3D] = audio._voices.slice(
		COMBAT_AUDIO.VOICES_PER_POOL, COMBAT_AUDIO.VOICES_PER_POOL * 2)
	for voice in reactions:
		voice.bus = AudioServer.get_bus_name(bus)
	var ear: Vector3 = audio.zombie_listener.global_position
	var strike := {"damage": 1, "stagger": 0.0, "strength": 500.0, "angle": 15.0}
	for case: Array in [[0, false, &"hurt", 3], [1, false, &"baby_hurt", 2],
			[0, true, &"death", 3], [1, true, &"baby_death", 3]]:
		var zombie := group.get_child(case[0]) as ZOMBIE
		var bank: Array = audio._groups.get(case[2], [])
		check(bank.size() == case[3], "%s loads all verified variants" % case[2])
		for variant in case[3]:
			audio.reset()
			capture.clear_buffer()
			zombie.health = 1 if case[1] else 8
			var point := ear + Vector3.FORWARD * 2.0
			group.strike_bolt({"collider": zombie, "position": point}, Vector3.FORWARD, 500 + variant, strike)
			audio.flush_zombie_combat_cues()
			check(reactions[0].playing and reactions[0].global_position == point
				and variant < bank.size() and reactions[0].stream == bank[variant],
				"A real %s strike plays variant %d from the correct reaction bank" % [case[2], variant + 1])
			if variant == 0 and case[0] == 1:
				await create_timer(0.19).timeout
				var peak := 0.0
				for sample in capture.get_buffer(capture.get_frames_available()):
					peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
				check(peak > 0.001 and peak < 0.9, "%s reaches the silent mixer with headroom" % case[2])
				print("MECHANIC_LAB_BABY_REACTION ", case[2], " peak=", peak)
	audio.reset()
	var near_points := [ear + Vector3.FORWARD, ear + Vector3.FORWARD * 2.0, ear + Vector3.FORWARD * 3.0]
	for strike_index in [4, 3, 2, 1, 0]:
		var zombie := group.get_child(strike_index % 2) as ZOMBIE
		zombie.health = 1
		var point := ear + Vector3.FORWARD * (strike_index + 1.0)
		group.strike_bolt({"collider": zombie, "position": point}, Vector3.FORWARD, 509, strike)
	audio.flush_zombie_combat_cues()
	var baby_deaths: Array = audio._groups.get(&"baby_death", [])
	var adult_deaths: Array = audio._groups.get(&"death", [])
	check(reactions.all(func(voice):
		return voice.playing and (voice.stream in baby_deaths if voice.global_position == near_points[1]
			else voice.global_position in [near_points[0], near_points[2]] and voice.stream in adult_deaths)),
		"Adult and Baby Zombie deaths share the three nearest reaction voices")
	var adult := group.get_child(0) as ZOMBIE
	adult.health = 8
	group.strike_bolt({"collider": adult, "position": ear}, Vector3.FORWARD, 510, strike)
	audio.flush_zombie_combat_cues()
	check(reactions.all(func(voice): return voice.global_position in near_points),
		"An adult hurt cannot interrupt a Baby Zombie death")
	toggle.button_pressed = false
	check(reactions.all(func(voice): return not voice.playing), "Muting stops both zombie reaction banks")
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
		# The spatial hit queue drains in the render callback, which can
		# follow more than one physics tick at low render rates.
		await process_frame
		await process_frame
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
		await check_local_hurt_onset(lab, audio, local_voice, capture)
		lab._on_player_hit(lab.player_health)
		check(lab.player_health == 0 and local_voice.playing, "The final hit plays through the defeat transition")
		var defeat_voice := audio.get_node_or_null("PlayerDefeat") as AudioStreamPlayer
		check(defeat_voice != null and audio._groups.get(&"player_defeat", []).size() == 1,
			"The pinned MD2 defeat cue has its own local voice")
		if defeat_voice != null:
			check(defeat_voice.playing and defeat_voice.stream in audio._groups.get(&"player_defeat", []),
				"The lethal hit starts the defeat cue alongside the final hurt")
			defeat_voice.bus = AudioServer.get_bus_name(bus)
			local_voice.stop()
			await create_timer(0.08).timeout
			capture.clear_buffer()
			await create_timer(0.25).timeout
			lab._on_player_hit(6)
			await create_timer(0.12).timeout
			var defeat_peak := 0.0
			for frame in capture.get_buffer(capture.get_frames_available()):
				defeat_peak = maxf(defeat_peak, maxf(absf(frame.x), absf(frame.y)))
			check(defeat_voice.get_playback_position() > 0.30 and defeat_peak > 0.001 and defeat_peak < 0.9,
				"The defeat cue reaches the mixer without restarting (peak %.4f)" % defeat_peak)
			print("MECHANIC_LAB_PLAYER_DEFEAT_PEAK ", defeat_peak)
			lab.reset_player()
			check(not defeat_voice.playing and defeat_voice.stream == null,
				"Retry clears the previous defeat cue")
			await physics_frame
			lab._on_player_hit(lab.player_health)
			check(defeat_voice.playing, "A new defeat plays its cue after retry")
		toggle.button_pressed = false
		if defeat_voice != null:
			check(not defeat_voice.playing and defeat_voice.stream == null,
				"Muting clears the active defeat cue")
		check(not local_voice.playing and local_voice.stream == null and AudioServer.is_bus_mute(0),
			"Turning audio off stops a live player-hurt cue and restores mute")
		await create_timer(0.1).timeout
	lab.free()

func check_local_hurt_onset(lab, audio, voice: AudioStreamPlayer, capture: AudioEffectCapture) -> void:
	await physics_frame
	capture.clear_buffer()
	lab._on_player_hit(6)
	var frame := Engine.get_physics_frames()
	var playback := voice.get_stream_playback()
	var choice: int = audio._next_choice[&"player_hurt"]
	var health: int = lab.player_health
	await physics_frame
	var onset := voice.get_playback_position()
	lab._on_player_hit(5)
	var held: bool = voice.get_stream_playback() == playback and audio._next_choice[&"player_hurt"] == choice
	check(Engine.get_physics_frames() > frame and onset < 0.05 and held and lab.player_health == health - 5,
		"A hit on the next physics tick keeps the pending local hurt onset and still applies damage")
	await create_timer(0.10).timeout
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(peak > 0.005 and peak < 0.5, "The protected local hurt reaches the mixer with headroom")
	for i in 24:
		if not voice.playing or voice.get_playback_position() >= 0.05:
			break
		await process_frame
	var ready_position := voice.get_playback_position()
	lab._on_player_hit(6)
	check(voice.get_stream_playback() != playback and audio._next_choice[&"player_hurt"] != choice,
		"A later hit can play a fresh local hurt cue")
	print("MECHANIC_LAB_PLAYER_HURT_ONSET seconds=", onset, " held=", held, " peak=", peak,
		" next_seconds=", ready_position)

func check_zombie_steps(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var audio = lab.get_node("CombatAudio")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var step_samples: Array = audio._groups.get(&"zombie_step", [])
	check(step_samples.size() == 5, "Five pinned MD2 zombie step samples decode")
	if step_samples.size() != 5:
		lab.free()
		return
	var voices: Array = audio._voices.slice(3 * COMBAT_AUDIO.VOICES_PER_POOL, 4 * COMBAT_AUDIO.VOICES_PER_POOL)
	for voice in voices:
		voice.bus = AudioServer.get_bus_name(bus)
	var group := lab.get_node("Zombies")
	var button := lab.get_node("HUD/SpawnZombie") as Button
	button.pressed.emit()
	var zombie := group.get_child(0) as ZOMBIE
	zombie.global_position = Vector3(0.0, 0.02, 9.0)
	var contacts: Array[Dictionary] = []
	var record_contact := func(point: Vector3):
		contacts.append({"point": point, "phase": zombie.animation.current_animation_position})
	zombie.step_audio.connect(record_contact)
	capture.clear_buffer()
	for i in 180:
		await physics_frame
		if contacts.size() >= 2:
			break
	var phases := contacts.map(func(event): return event.phase)
	check(phases.size() == 2 and absf(phases[0] - 0.427282) < 0.018
		and absf(phases[1] - 1.281282) < 0.018,
		"The real chasing zombie steps on its two source walk contacts")
	await process_frame
	await process_frame
	check(audio._next_choice.get(&"zombie_step", 0) == 2 and voices.any(func(voice):
		return voice.stream in step_samples and absf(voice.global_position.y) < 0.01),
		"Both steps use the grounded grass contact for playback")
	var peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > 0.001 and peak < 0.35, "The step pool produces spatial PCM with headroom")
	var before_death: int = contacts.size()
	zombie.take_hit(100, Vector3.FORWARD)
	for i in 100:
		await physics_frame
	check(contacts.size() == before_death, "Airborne and settled corpses post no walking sounds")
	zombie.free()
	for clip_index in range(1, ZOMBIE.WALK_CLIPS.size()):
		button.pressed.emit()
		zombie = group.get_child(group.get_child_count() - 1) as ZOMBIE
		zombie.global_position = Vector3(0.0, 0.02, 10.0)
		var variant_phases: Array[float] = []
		var sample := func(_point: Vector3): variant_phases.append(zombie.animation.current_animation_position)
		zombie.step_audio.connect(sample)
		for i in 240:
			await physics_frame
			if variant_phases.size() == 3:
				break
		check(zombie._walk_clip == ZOMBIE.WALK_CLIPS[clip_index] and variant_phases.size() == 3
			and absf(variant_phases[0] - 0.427282) < 0.018
			and absf(variant_phases[1] - 1.281282) < 0.018
			and absf(variant_phases[2] - 0.427282) < 0.018,
			"The zombie walk variant keeps both contacts and repeats correctly across the loop")
		zombie.free()
	audio.reset()
	var before_overflow: int = audio._next_choice.get(&"zombie_step", 0)
	var near: Vector3 = lab.player.global_position + Vector3.FORWARD * 2.0
	lab._on_zombie_step(near + Vector3.FORWARD * 30.0)
	lab._on_zombie_step(near + Vector3.UP * 2.0)
	check(audio._next_choice.get(&"zombie_step", 0) == before_overflow,
		"Distant and unsupported contacts produce no cue")
	for i in 100:
		lab._on_zombie_step(near)
	await process_frame
	await process_frame
	check(voices.size() == 3 and voices.all(func(voice): return voice.playing)
		and audio._next_choice.get(&"zombie_step", 0) == (before_overflow + 3) % step_samples.size(),
		"A 100-step burst uses only three voices without restarting them")
	group.zombie_attack_audio.emit(near, false)
	await process_frame
	await process_frame
	check(audio._next_choice.get(&"zombie_windup", 0) == 1, "Step overflow leaves a telegraph voice available")
	toggle.button_pressed = false
	check(voices.all(func(voice): return not voice.playing and voice.stream == null),
		"Muting the lab stops all step voices")
	lab._on_zombie_step(near)
	check(audio._next_choice.get(&"zombie_step", -1) == (before_overflow + 3) % step_samples.size(),
		"A muted foot contact starts no sample")
	toggle.button_pressed = true
	audio.reset()
	var origin: Vector3 = lab.player.global_position
	var selected_distances: Array[float] = [2.0, 4.0, 6.0]
	for distance: float in [10.0, 8.0, 6.0, 4.0, 2.0]:
		lab._on_zombie_step(origin + Vector3.FORWARD * distance)
	# A closer contact on another collider must not crowd out grass steps.
	lab._on_zombie_step(origin + Vector3.UP * 2.0)
	await process_frame
	await process_frame
	var played_distances: Array[float] = []
	for voice in voices:
		if voice.stream in step_samples:
			played_distances.append(absf(voice.global_position.z - origin.z))
	played_distances.sort()
	check(played_distances == selected_distances,
		"Same-tick step overflow selects the nearest supported contacts")
	audio.reset()
	# Hold the normal render flush while several physics ticks post contacts.
	lab.set_process(false)
	var queued_at := Engine.get_physics_frames()
	var catchup_choice: int = audio._next_choice.get(&"zombie_step", 0)
	for distances in [[9.0, 10.0, 11.0], [5.0, 6.0, 7.0], [1.0, 2.0, 3.0]]:
		for distance: float in distances:
			lab._on_zombie_step(origin + Vector3.FORWARD * distance)
		await physics_frame
	check(Engine.get_physics_frames() > queued_at and not voices.any(func(voice): return voice.playing)
		and audio._next_choice.get(&"zombie_step", 0) == catchup_choice,
		"Catch-up steps wait for the render flush before choosing streams")
	capture.clear_buffer()
	audio.flush_zombie_steps()
	lab.set_process(true)
	played_distances.clear()
	for voice in voices:
		if voice.playing and voice.stream in step_samples:
			played_distances.append(absf(voice.global_position.z - origin.z))
	played_distances.sort()
	check(played_distances == [1.0, 2.0, 3.0]
		and audio._next_choice.get(&"zombie_step", 0) == (catchup_choice + 3) % step_samples.size(),
		"A slow render frame plays the nearest grounded steps across its physics ticks")
	await create_timer(0.12).timeout
	var catchup_peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		catchup_peak = maxf(catchup_peak, maxf(absf(sample.x), absf(sample.y)))
	check(catchup_peak > 0.001 and catchup_peak < 0.35, "The selected catch-up steps reach the silent mixer")
	print("MECHANIC_LAB_STEP_CATCHUP distances=", played_distances, " peak=", catchup_peak)
	audio.reset()
	var before_reset: int = audio._next_choice.get(&"zombie_step", 0)
	lab._on_zombie_step(near)
	lab.reset_player()
	await process_frame
	await process_frame
	check(audio._next_choice.get(&"zombie_step", 0) == before_reset,
		"Retry discards a step awaiting playback")
	lab._on_zombie_step(near)
	toggle.button_pressed = false
	await process_frame
	await process_frame
	check(audio._next_choice.get(&"zombie_step", 0) == before_reset,
		"Muting discards a step awaiting playback")
	await create_timer(0.1).timeout
	print("MECHANIC_LAB_ZOMBIE_STEP_AUDIO phases=", phases, " peak=", peak)
	lab.free()

func check_zombie_attack_overflow(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var audio := lab.get_node("CombatAudio") as COMBAT_AUDIO
	var group := lab.get_node("Zombies")
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var voices := audio._voices.slice(2 * COMBAT_AUDIO.VOICES_PER_POOL, 3 * COMBAT_AUDIO.VOICES_PER_POOL)
	for voice in voices:
		voice.bus = AudioServer.get_bus_name(bus)
	await create_timer(0.12).timeout
	var points: Array[Vector3] = []
	for i in 100:
		var point: Vector3 = lab.player.global_position + Vector3(2.0, 1.0, (100 - i) * 0.04)
		points.append(point)
		group.zombie_attack_audio.emit(point, false)
	await process_frame
	await process_frame
	var nearest_points := points.slice(-3)
	check(audio._next_choice.get(&"zombie_windup", 0) == 3
		and voices.all(func(voice): return voice.global_position in nearest_points),
		"A same-tick attack burst plays the three nearest telegraphs")
	# Let the real-time mixer start the telegraphs before the contact burst.
	await create_timer(0.10).timeout
	capture.clear_buffer()
	for point in points:
		group.zombie_attack_audio.emit(point, true)
	await process_frame
	await process_frame
	var hit_voices := voices.filter(func(voice): return voice.stream in audio._groups[&"zombie_hit"])
	check(audio._next_choice.get(&"zombie_hit", 0) == 3 and hit_voices.size() == voices.size()
		and hit_voices.all(func(voice): return voice.global_position in nearest_points),
		"Confirmed contacts replace windups with the three nearest contact cues")
	var hit_streams := voices.map(func(voice): return voice.stream)
	for point in points:
		group.zombie_attack_audio.emit(point, false)
	await process_frame
	await process_frame
	check(audio._next_choice.get(&"zombie_windup", 0) == 3
		and hit_streams == voices.map(func(voice): return voice.stream),
		"Overflow windups cannot cut off confirmed contact cues")
	var initial_hp: int = lab.player_health
	for i in 4:
		group.player_hit.emit(ZOMBIE.MELEE_DAMAGE)
	check(lab.player_health == initial_hp - 24 and audio._next_choice.get(&"player_hurt", 0) == 1,
		"Same-tick damage is applied fully while the local hurt cue starts once")
	var local_voice := audio.get_node("PlayerHurt") as AudioStreamPlayer
	for i in 24:
		await physics_frame
		if not local_voice.playing or local_voice.get_playback_position() >= 0.05:
			break
	group.player_hit.emit(ZOMBIE.MELEE_DAMAGE)
	check(lab.player_health == initial_hp - 30 and audio._next_choice.get(&"player_hurt", 0) == 2,
		"A later hit starts a new local hurt cue after the onset mixes")
	await create_timer(0.30).timeout
	var peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > 0.005 and peak < 0.9, "The contact pool produces PCM with headroom")
	await check_zombie_attack_onsets(audio, group, voices)
	await check_zombie_cue_catchup(lab, audio, group)
	audio.reset()
	var windup_choice: int = audio._next_choice.get(&"zombie_windup", 0)
	group.zombie_attack_audio.emit(lab.player.global_position + Vector3.RIGHT * 40.0, false)
	await process_frame
	await process_frame
	check(audio._next_choice.get(&"zombie_windup", 0) == windup_choice
		and voices.all(func(voice): return voice.stream == null),
		"An out-of-range telegraph does not reserve a voice or advance the sample")
	group.zombie_attack_audio.emit(points[-1], false)
	audio.reset()
	await process_frame
	await process_frame
	check(voices.all(func(voice): return voice.stream == null), "Reset clears queued zombie attacks")
	group.zombie_attack_audio.emit(points[-1], true)
	toggle.button_pressed = false
	await create_timer(0.08).timeout
	check(voices.all(func(voice): return voice.stream == null),
		"Muting clears queued contact cues")
	print("MECHANIC_LAB_ZOMBIE_ATTACK_OVERFLOW peak=", peak)
	lab.free()

func check_zombie_cue_catchup(lab: Node, audio: COMBAT_AUDIO, group: Node) -> void:
	var ear := audio.zombie_listener.global_position
	var near := [ear + Vector3.RIGHT, ear + Vector3.RIGHT * 2.0, ear + Vector3.RIGHT * 3.0]
	var far := [ear + Vector3.LEFT * 10.0, ear + Vector3.LEFT * 11.0, ear + Vector3.LEFT * 12.0]
	var attacks := audio._voices.slice(COMBAT_AUDIO.ATTACK_POOL * COMBAT_AUDIO.VOICES_PER_POOL,
		(COMBAT_AUDIO.ATTACK_POOL + 1) * COMBAT_AUDIO.VOICES_PER_POOL)
	var reactions := audio._voices.slice(COMBAT_AUDIO.REACTION_POOL * COMBAT_AUDIO.VOICES_PER_POOL,
		(COMBAT_AUDIO.REACTION_POOL + 1) * COMBAT_AUDIO.VOICES_PER_POOL)
	var emit_cues := func(points: Array, confirmed: bool):
		for point: Vector3 in points:
			group.zombie_attack_audio.emit(point, confirmed)
			audio.contact(point, 1, confirmed, "NativeBowAction")

	# Hold the normal render flush while the events cross physics ticks.
	lab.set_process(false)
	for confirmed in [false, true]:
		audio.reset()
		var attack := &"zombie_hit" if confirmed else &"zombie_windup"
		var reaction := &"death" if confirmed else &"hurt"
		var attack_before: int = audio._next_choice.get(attack, 0)
		var reaction_before: int = audio._next_choice.get(reaction, 0)
		emit_cues.call(far, confirmed)
		await physics_frame
		emit_cues.call(near, confirmed)
		check((attacks + reactions).all(func(voice): return voice.stream == null)
			and audio._next_choice.get(attack, 0) == attack_before
			and audio._next_choice.get(reaction, 0) == reaction_before,
			"Older physics ticks reserve no attack or reaction voice before the render flush")
		audio.flush_zombie_combat_cues()
		check(audio._next_choice.get(attack, 0) == (attack_before + 3) % audio._groups[attack].size()
			and attacks.all(func(voice): return voice.global_position in near and voice.stream in audio._groups[attack]),
			"The render flush selects the three nearest %s cues across ticks" % attack)
		check(audio._next_choice.get(reaction, 0) == (reaction_before + 3) % audio._groups[reaction].size()
			and reactions.all(func(voice): return voice.global_position in near and voice.stream in audio._groups[reaction]),
			"The render flush selects the three nearest %s cues across ticks" % reaction)

	audio.reset()
	var windups_before: int = audio._next_choice.get(&"zombie_windup", 0)
	var hurts_before: int = audio._next_choice.get(&"hurt", 0)
	emit_cues.call(near, false)
	await physics_frame
	emit_cues.call(far, true)
	audio.flush_zombie_combat_cues()
	check(audio._next_choice.get(&"zombie_windup", 0) == windups_before
		and attacks.all(func(voice): return voice.stream in audio._groups[&"zombie_hit"]),
		"Confirmed contacts win over queued telegraphs across ticks without starting the telegraphs")
	check(audio._next_choice.get(&"hurt", 0) == hurts_before
		and reactions.all(func(voice): return voice.stream in audio._groups[&"death"]),
		"Lethal reactions win over queued hurt cues across ticks without starting them")

	audio.reset()
	emit_cues.call(near, false)
	audio.flush_zombie_combat_cues()
	hurts_before = audio._next_choice.get(&"hurt", 0)
	var future := Engine.get_physics_frames() + ceili(0.1 * Engine.physics_ticks_per_second)
	check(audio._play(&"hurt", far[0], COMBAT_AUDIO.HURT_GAIN_DB, future) == null
		and reactions.all(func(voice): return voice.global_position in near)
		and audio._next_choice.get(&"hurt", 0) == hurts_before,
		"A distant hurt cue cannot replace a nearby onset the mixer has not played yet")
	print("MECHANIC_LAB_ZOMBIE_CUE_CATCHUP attacks=", attacks.size(), " reactions=", reactions.size())
	audio.reset()
	lab.set_process(true)

func check_zombie_attack_onsets(audio: COMBAT_AUDIO, group: Node,
		voices: Array[AudioStreamPlayer3D]) -> void:
	var ear := audio.zombie_listener.global_position
	var near := [ear + Vector3.RIGHT, ear + Vector3.RIGHT * 2.0, ear + Vector3.RIGHT * 3.0]
	var closest := ear + Vector3.RIGHT * 0.5
	var far := ear + Vector3.RIGHT * 10.0
	var catch_up_ticks := ceili(0.10 * Engine.physics_ticks_per_second)
	for confirmed in [false, true]:
		audio.reset()
		var cue := &"zombie_hit" if confirmed else &"zombie_windup"
		var gain := COMBAT_AUDIO.ZOMBIE_HIT_GAIN_DB if confirmed else COMBAT_AUDIO.ZOMBIE_WINDUP_GAIN_DB
		for point: Vector3 in near:
			group.zombie_attack_audio.emit(point, confirmed)
		audio.flush_zombie_combat_cues()
		var choice: int = audio._next_choice.get(cue, 0)

		# Schedule several physics ticks before yielding to the mixer.
		var future := Engine.get_physics_frames() + catch_up_ticks
		check(audio._play(cue, far, gain, future) == null
			and audio._next_choice.get(cue, 0) == choice,
			"A fresh %s onset survives simulation catch-up" % cue)
		await physics_frame
		for i in 100:
			group.zombie_attack_audio.emit(far + Vector3.BACK * i * 0.12, confirmed)
		audio.flush_zombie_combat_cues()
		check(voices.all(func(voice): return voice.global_position in near)
			and audio._next_choice.get(cue, 0) == choice,
			"Nearby %s onsets survive a distant burst on the next tick" % cue)

		var closer := audio._play(cue, closest, gain)
		var positions := voices.map(func(voice): return voice.global_position)
		check(closer != null and positions.has(closest) and positions.has(near[0]) and positions.has(near[1]),
			"A closer %s replaces the farthest protected voice" % cue)
		var onset_mixed := await wait_for_zombie_onset(voices)
		check(onset_mixed and audio._play(cue, far, gain, future + catch_up_ticks) != null,
			"Later %s cues can use voices once the onset has mixed" % cue)

func wait_for_zombie_onset(voices: Array[AudioStreamPlayer3D]) -> bool:
	var deadline := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < deadline:
		for voice in voices:
			if not voice.playing or voice.get_playback_position() >= COMBAT_AUDIO.ZOMBIE_ONSET_SECONDS:
				return true
		await process_frame
	return false

func check_melee_tool_variants(audio: Node3D, bus: int, capture: AudioEffectCapture) -> void:
	audio.set_enabled(true, Vector3.FORWARD * 2.0)
	var voice: AudioStreamPlayer3D = audio._voices[0]
	var previous_bus := voice.bus
	voice.bus = AudioServer.get_bus_name(bus)
	var counts := {
		&"cleaver": [3, 3, 2, 0, 2, 0],
		&"gauntlet": [4, 3, 3, 3, 3, 3],
		&"pickaxe": [3, 3, 3, 3, 3, 3],
		&"shovel": [1, 3, 3, 1, 1, 3],
		&"axe": [1, 1, 1, 3, 3, 0],
	}
	for tool: StringName in counts:
		audio.reset()
		audio.load_melee_tool(audio._research_root(), tool)
		for slot in counts[tool].size():
			var group := StringName("tool_%s_%d" % [tool, slot])
			check(audio._groups.get(group, []).size() == counts[tool][slot],
				"%s keeps all verified variants in its source audio family" % group)
		var middle := StringName("tool_%s_1" % tool)
		var variants: Array = audio._groups.get(middle, [])
		if variants.size() < 2:
			continue
		var selected: Array[AudioStream] = []
		for i in variants.size():
			audio.reset()
			audio.tool_swung(tool, Vector3.FORWARD * 2.0, 1, false)
			selected.append(audio._voices[0].stream)
		check(selected == variants, "%s rotates through its grounded swing variants" % tool)
		audio.reset()
		await create_timer(0.06).timeout
		capture.clear_buffer()
		audio.tool_swung(tool, Vector3.FORWARD * 2.0, 1, false)
		await create_timer(0.25).timeout
		var peak := 0.0
		for frame in capture.get_buffer(capture.get_frames_available()):
			peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		check(audio._voices[0].stream == variants[0] and peak > 0.001 and peak < 0.9,
			"%s wraps to the first variant and produces PCM without clipping" % tool)
		print("MELEE_TOOL_AUDIO ", tool, " variants=", variants.size(), " peak=", peak)
	audio.reset()
	voice.bus = previous_bus

func check_zombie_idle_audio(bus: int, capture: AudioEffectCapture) -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	toggle.button_pressed = true
	var audio = lab.get_node("CombatAudio")
	var idle := audio.get_node_or_null("ZombieIdle") as AudioStreamPlayer3D
	var samples: Array = audio._groups.get(&"zombie_idle", [])
	check(idle != null and samples.size() == 3, "The Lab decodes three corroborated zombie idle samples")
	if idle == null or samples.size() != 3:
		lab.free()
		return
	var group := lab.get_node("Zombies")
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	var zombie := group.get_child(0) as ZOMBIE
	zombie.set_physics_process(false)
	zombie.global_position = lab.player.global_position + Vector3.FORWARD * 3.0
	var idle_events: Array[float] = []
	var idle_point: Array[Vector3] = []
	zombie.connect(&"idle_audio", func(point: Vector3):
		idle_events.append(zombie.animation.current_animation_position)
		idle_point.append(point))
	zombie.animation.play(ZOMBIE.IDLE, 0.0)
	var early_events := 0
	for i in 64:
		zombie.animation.seek(0.0, true)
		var count := idle_events.size()
		zombie._advance_animation(0.05, Vector3.ZERO)
		early_events += idle_events.size() - count
		zombie._advance_animation(0.02, Vector3.ZERO)
	check(early_events == 0 and idle_events.size() in range(18, 47)
		and idle_events.all(func(t): return absf(t - 0.07) < 0.0001),
		"Idle vocalization rolls its chance only on the authored 0.0669 second contact")
	var idle_index := zombie._idle_audio_index
	var idle_length := zombie.animation.get_animation(ZOMBIE.IDLE).length
	zombie.animation.seek(idle_length - 0.03, true)
	zombie._advance_animation(0.10, Vector3.ZERO)
	check(zombie._idle_audio_index == idle_index + 1, "Loop wrap rechecks the authored idle cue once")
	var cue_count := idle_events.size()
	zombie.animation.play(ZOMBIE.WALK_CLIPS[0], 0.0)
	zombie.animation.seek(0.0, true)
	zombie._advance_animation(0.10, Vector3.ZERO)
	check(idle_events.size() == cue_count, "Walking does not post the idle vocalization")
	idle.bus = AudioServer.get_bus_name(bus)
	capture.clear_buffer()
	audio.flush_zombie_idle()
	check(idle.playing and idle.stream in samples and not idle_point.is_empty()
		and idle.global_position == idle_point[0] and idle.pitch_scale >= pow(2.0, -200.0 / 1200.0) - 0.0001
		and idle.pitch_scale <= pow(2.0, 300.0 / 1200.0) + 0.0001,
		"The nearest idle cue posts a source-family sample inside the inferred pitch envelope")
	await create_timer(0.32).timeout
	var peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > 0.001 and peak < 0.35, "The idle voice reaches the silent mixer with headroom")
	audio.reset()
	var listener: Vector3 = audio.zombie_listener.global_position
	var before: int = audio._next_choice.get(&"zombie_idle", 0)
	audio.queue_zombie_idle(listener + Vector3.FORWARD * (COMBAT_AUDIO.ZOMBIE_IDLE_DISTANCE + 1.0))
	audio.flush_zombie_idle()
	check(not idle.playing and audio._next_choice.get(&"zombie_idle", 0) == before,
		"An idle zombie outside the hearing range uses no voice")
	for i in range(100, 0, -1):
		audio.queue_zombie_idle(listener + Vector3.FORWARD * i * 0.25)
	audio.flush_zombie_idle()
	var closest := listener + Vector3.FORWARD * 0.25
	check(idle.global_position == closest and idle.playing
		and audio._next_choice.get(&"zombie_idle", 0) == (before + 1) % samples.size(),
		"A hundred idle notifies share a single voice and the nearest one wins")
	var idle_stream := idle.stream
	audio.queue_zombie_idle(closest)
	audio.zombie_attack(closest, false)
	audio.flush_zombie_combat_cues()
	audio.flush_zombie_idle()
	check(idle.playing and idle.stream == idle_stream and audio._next_choice.get(&"zombie_windup", 0) == 1,
		"Idle overflow leaves the attack pool available and the idle voice playing")
	audio.reset()
	audio.queue_zombie_idle(closest)
	toggle.button_pressed = false
	audio.flush_zombie_idle()
	check(not idle.playing and idle.stream == null, "Muting clears queued and active zombie idle sounds")
	print("MECHANIC_LAB_ZOMBIE_IDLE events=", cue_count, " peak=", peak)
	# Let the Dummy mixer release playback before freeing the scene.
	await create_timer(0.10).timeout
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
	await check_crossbow_fire_under_impact_burst(audio, bus, capture)
	await check_weapon_onsets_under_mixed_impacts(audio, bus, capture)
	await check_overlapping_heavy_landings(audio, bus, capture)
	await check_melee_tool_variants(audio, bus, capture)
	audio.set_enabled(false, Vector3.ZERO)
	await create_timer(0.08).timeout
	await check_bow_fire_during_crossbow_impacts(bus, capture)
	await check_local_hurt(bus, capture)
	await check_movement_audio(bus, capture)
	await check_landing_voice_under_step_burst(bus, capture)
	await check_run_step_after_landing(bus, capture)
	await check_sabre_debris_audio(bus, capture)
	await check_sabre_crowd_audio(bus, capture)
	await check_zombie_steps(bus, capture)
	await check_zombie_attack_overflow(bus, capture)
	await check_zombie_idle_audio(bus, capture)
	await check_baby_zombie_reactions(bus, capture)
	print("MECHANIC_LAB_AUDIO ", JSON.stringify({"checks": checks, "failures": failures,
		"old_high_low_power_ratio": previous, "new_high_low_power_ratio": revised, "source_mix_peak": peak}))
	AudioServer.remove_bus_effect(bus, 0)
	audio.queue_free()
	camera.queue_free()
	await process_frame
	AudioServer.remove_bus(bus)
	quit(0 if failures.is_empty() else 1)

