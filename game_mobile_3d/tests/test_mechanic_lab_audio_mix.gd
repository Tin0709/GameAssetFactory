extends SceneTree

const LAB := preload("res://scenes/dev/MechanicLab.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func cue_peak(lab: Node3D, capture: AudioEffectCapture, cue: Callable) -> float:
	lab.get_node("CombatAudio").reset()
	lab.get_node("MovementAudio").reset_contacts()
	await create_timer(0.08).timeout
	capture.clear_buffer()
	cue.call()
	await create_timer(0.42).timeout
	var peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak

func run() -> void:
	if AudioServer.get_driver_name() != "Dummy":
		printerr("The mix test requires the silent Dummy driver")
		quit(2)
		return
	var bus_count := AudioServer.get_bus_count()
	var master_muted := AudioServer.is_bus_mute(0)
	var lab := LAB.instantiate()
	root.add_child(lab)
	var button := lab.get_node_or_null("HUD/AudioMixButton") as Button
	if button == null:
		printerr("The Lab has no audio mix controls")
		quit(1)
		return
	var panel := lab.get_node("HUD/AudioMixPanel") as PanelContainer
	button.button_pressed = true
	check(panel.visible and not lab.get_node("HUD/CombatAudioToggle").button_pressed,
		"Opening the audio mix does not turn on combat audio")
	var sliders := {}
	for name: String in ["Master", "Weapon", "Zombie", "Surface"]:
		sliders[name] = panel.get_node("Rows/" + name + "/Slider") as HSlider
		check(sliders[name].value == 100.0, "The default mix is unchanged for " + name)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	lab.get_node("HUD/CombatAudioToggle").button_pressed = true
	var audio = lab.get_node("CombatAudio")
	var movement = lab.get_node("MovementAudio")
	await physics_frame
	await physics_frame
	var feet: Vector3 = lab.get("player").global_position
	var point := feet + Vector3.UP
	var cues := {
		"Weapon": func():
			audio._next_choice[&"hit"] = 0
			audio.weapon_contact(point, 1),
		"Zombie": func():
			audio._next_choice[&"zombie_hit"] = 0
			audio.zombie_attack(point, true)
			audio.flush_zombie_combat_cues(),
		"Surface": func():
			movement._random.seed = 281027
			movement._last_choice.clear()
			movement._on_surface_contact(feet, false),
	}
	for layer: String in cues:
		var baseline := await cue_peak(lab, capture, cues[layer])
		sliders[layer].value = 50.0
		var softened := await cue_peak(lab, capture, cues[layer])
		check(baseline > 0.001 and absf(softened - baseline * 0.5) < baseline * 0.06,
			"The %s slider halves its actual cue level (%.4f → %.4f)" % [layer, baseline, softened])
		sliders[layer].value = 0.0
		var muted := await cue_peak(lab, capture, cues[layer])
		check(muted < 0.0001, "The %s slider silences its own audio layer" % layer)
		sliders[layer].value = 100.0
		print("LAB_AUDIO_MIX ", layer, " baseline=", baseline, " half=", softened, " muted=", muted)
	sliders.Zombie.value = 0.0
	sliders.Surface.value = 0.0
	check(await cue_peak(lab, capture, cues.Weapon) > 0.001, "Muting zombie and surface cues leaves weapon audio audible")
	sliders.Master.value = 0.0
	check(await cue_peak(lab, capture, cues.Weapon) < 0.0001, "The Lab master slider can silence its whole mix")
	AudioServer.remove_bus_effect(0, effect_index)
	lab.free()
	check(AudioServer.get_bus_count() == bus_count and AudioServer.is_bus_mute(0) == master_muted,
		"Closing the Lab releases its mix buses and restores the prior master state")
	print("MECHANIC_LAB_AUDIO_MIX ", JSON.stringify({"failures": failures}))
	quit(int(not failures.is_empty()))
