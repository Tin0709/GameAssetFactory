
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
		for i in 18:
			await physics_frame
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
			var grass_voices: Array = audio._voices.filter(func(voice): return voice.stream in audio._groups[&"slam_grass"])
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
	var later_death := ear + Vector3.RIGHT * 10.0
	audio.contact(later_death, 1103, true)
	audio.flush_zombie_combat_cues()
	check(reactions.any(func(voice): return voice.global_position == later_death),
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
	await physics_frame
	group.player_hit.emit(ZOMBIE.MELEE_DAMAGE)
	check(audio._next_choice.get(&"player_hurt", 0) == 2, "A later hit can play a new local hurt cue")
	await create_timer(0.30).timeout
	var peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > 0.005 and peak < 0.9, "The contact pool produces PCM with headroom")
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
	await check_sabre_debris_audio(bus, capture)
	await check_sabre_crowd_audio(bus, capture)
	await check_zombie_steps(bus, capture)
	await check_zombie_attack_overflow(bus, capture)
	print("MECHANIC_LAB_AUDIO ", JSON.stringify({"checks": checks, "failures": failures,
		"old_high_low_power_ratio": previous, "new_high_low_power_ratio": revised, "source_mix_peak": peak}))
	AudioServer.remove_bus_effect(bus, 0)
	audio.queue_free()
	camera.queue_free()
	await process_frame
	AudioServer.remove_bus(bus)
	quit(0 if failures.is_empty() else 1)

