extends SceneTree

const Lab := preload("res://scenes/dev/MechanicLab.tscn")
const CurvedGreatsword := 2

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var lab = Lab.instantiate()
	root.add_child(lab)
	current_scene = lab
	var slider := lab.get_node_or_null("HUD/Hitstop/Slider") as HSlider
	check(slider != null, "The Lab exposes the hitstop control")
	if slider == null:
		quit(1)
		return
	check(slider.value == 0.0 and slider.max_value == 60.0, "The experiment starts at 0 ms and is bounded")
	var baseline: Dictionary = await replay(lab, slider, 0.0, true)
	var tuned: Dictionary = await replay(lab, slider, 60.0, true)
	check(baseline.hits == [2, 2, 2] and tuned.hits == baseline.hits,
		"The three-strike chain still damages both enemies once per swing")
	check(baseline.clips == tuned.clips and tuned.clips.size() == 3,
		"Held input follows the same three attack links")
	check(tuned.held_ticks >= 9 and tuned.held_ticks <= 12,
		"Two targets trigger one 60 ms pause per strike")
	check(tuned.fx_advanced and tuned.combo_matches_pose and tuned.world_advanced,
		"The pose and montage hold while the simulation and effects continue")
	check(tuned.last_contact - baseline.last_contact >= 6,
		"The contact-to-contact delay includes both earlier pauses")

	var miss: Dictionary = await replay(lab, slider, 60.0, false)
	var normal_miss: Dictionary = await replay(lab, slider, 0.0, false)
	check(miss.held_ticks == 0 and miss.clips == normal_miss.clips
		and miss.end_tick == normal_miss.end_tick, "Whiffs advance at normal speed")
	print("MECHANIC_LAB_HITSTOP ", JSON.stringify({"failures": failures, "baseline": baseline, "tuned": tuned}))
	quit(0 if failures.is_empty() else 1)

func replay(lab: Node3D, slider: HSlider, milliseconds: float, has_targets: bool) -> Dictionary:
	var weapon := lab.get_node("HUD/Weapon") as OptionButton
	var group := lab.get_node("Zombies")
	for actor in group.get_children():
		actor.free()
	lab.reset_player()
	weapon.select(CurvedGreatsword)
	weapon.item_selected.emit(CurvedGreatsword)
	slider.value = milliseconds
	await ticks(12)
	for x in [-0.36, 0.36] if has_targets else []:
		lab.get_node("HUD/SpawnZombie").pressed.emit()
		var zombie = group.get_children().back()
		zombie.set_physics_process(false)
		zombie.health = 200
		zombie.position = Vector3(x, 0.0, 1.25)

	var contacts := {}
	var clips: Array[String] = []
	var start_tick := Engine.get_physics_frames()
	var contact_at := [-1]
	var hit := func(_point, _direction, _clip, _index, serial, _lethal):
		contacts[serial] = contacts.get(serial, 0) + 1
		contact_at[0] = Engine.get_physics_frames() - start_tick
	var accepted := func(_index, clip, _serial): clips.append(clip)
	group.sabre_contact.connect(hit)
	lab.player.attack_accepted.connect(accepted)
	var hold_ticks := 0
	var effects_advanced := true
	var combo_matches_pose := true
	var world_advanced := true
	var end_tick := 0
	attack(true)
	for tick in 245:
		var prior: float = lab.player.combo.time
		var prior_pose: float = lab.player.animation_player.current_animation_position
		var prior_serial: int = lab.player.combo.serial
		var prior_fx: float = lab.player.effects.clock
		var prior_simulation: float = lab.player.simulation_clock
		var was_attacking: bool = lab.player.combo.phase == &"attack"
		await physics_frame
		if (was_attacking and lab.player.combo.serial == prior_serial and
				is_equal_approx(lab.player.combo.time, prior)):
			hold_ticks += 1
			combo_matches_pose = combo_matches_pose and is_equal_approx(
				lab.player.animation_player.current_animation_position, prior_pose)
			effects_advanced = effects_advanced and lab.player.effects.clock > prior_fx
			world_advanced = world_advanced and lab.player.simulation_clock > prior_simulation
		if clips.size() == 3:
			attack(false)
			if not lab.player.combo.active():
				end_tick = tick
				break
	attack(false)
	group.sabre_contact.disconnect(hit)
	lab.player.attack_accepted.disconnect(accepted)
	return {"hits": contacts.values(), "clips": clips, "held_ticks": hold_ticks, "last_contact": contact_at[0],
		"fx_advanced": effects_advanced, "combo_matches_pose": combo_matches_pose,
		"world_advanced": world_advanced, "end_tick": end_tick}
