extends SceneTree

var failures: Array[String] = []
var attacks: Array[String] = []
var damage: Array[int] = []

func _initialize() -> void:
	call_deferred("run")

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
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var weapon := lab.get_node("HUD/Weapon") as OptionButton
	if weapon.disabled or weapon.item_count != 3:
		check(false, "MechanicLab offers Curved Greatsword alongside Sabre and Sword")
		finish(lab)
		return
	check(weapon.get_item_text(2) == "Curved Greatsword", "The third option identifies the source weapon")
	var research := OS.get_environment("MD2_RESEARCH_ROOT")
	OS.set_environment("MD2_RESEARCH_ROOT", ProjectSettings.globalize_path("res://"))
	weapon.select(2)
	weapon.item_selected.emit(2)
	check(weapon.selected == 0, "An invalid private asset root leaves the Sabre equipped")
	if research.is_empty():
		OS.unset_environment("MD2_RESEARCH_ROOT")
	else:
		OS.set_environment("MD2_RESEARCH_ROOT", research)
	weapon.select(2)
	weapon.item_selected.emit(2)
	check(weapon.selected == 2, "Curved Greatsword loads from the verified private assets")
	lab.player.attack_accepted.connect(func(_index, clip, _serial): attacks.append(clip))
	var group := lab.get_node("Zombies") as Node3D
	var spawn := lab.get_node("HUD/SpawnZombie") as Button
	spawn.pressed.emit()
	spawn.pressed.emit()
	if group.get_child_count() != 2:
		check(false, "Two zombies are available for the combo and splash")
		finish(lab)
		return
	var target = group.get_child(0)
	target.set_physics_process(false)
	target.position = Vector3(0.0, 0.0, 1.3)
	target.health = 100
	var distant_target = group.get_child(1)
	distant_target.set_physics_process(false)
	distant_target.position = Vector3(0.65, 0.0, 4.5)
	distant_target.health = 100
	var toggle := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	var combat_audio := lab.get_node("CombatAudio")
	var swing_audio = lab.player.reference_audio
	check(not toggle.button_pressed and not swing_audio.enabled, "Combat audio defaults to off")
	toggle.button_pressed = true
	var swing_count: int = swing_audio.played_count
	var hit_count: int = combat_audio._next_choice.get(&"curved_hit", 0)
	var shake_contacts: Array[int] = []
	var hit_choices: Array[int] = []
	group.sabre_contact.connect(func(point, _direction, _clip, index, serial, _lethal):
		if point.distance_to(target.global_position) < 2.0:
			damage.append(target.health)
			hit_choices.append(combat_audio._next_choice.get(&"curved_hit", -1))
			if lab._shake_serial == serial:
				shake_contacts.append(index))
	attack(true)
	for i in 140:
		await physics_frame
		if damage.size() >= 3:
			break
	attack(false)
	var recovered := false
	for i in 75:
		await physics_frame
		recovered = recovered or lab.player.active_clip == "NativeCurvedRecovery3"
	check(attacks == ["NativeCurvedAttack1", "NativeCurvedAttack2", "NativeCurvedAttack3"],
		"Held E plays the three source attacks in order")
	check(damage == [80, 60, 30], "The three contacts deal 20, 20 and 30 damage")
	check(distant_target.health == 91, "Only the finisher reaches the distant target for 30% splash")
	check(shake_contacts == [2], "Only the finisher triggers a nearby camera shake")
	check(swing_audio.played_count == swing_count + 3, "Three source swing samples reach the audio voices")
	check(combat_audio._groups.get(&"curved_hit", []).size() == 3
		and hit_choices == [(hit_count + 1) % 3, (hit_count + 2) % 3, hit_count]
		and combat_audio._next_choice.get(&"curved_hit", -1) == hit_count,
		"Three contacts play the Curved Greatsword hitmarker once per strike")
	toggle.button_pressed = false
	check(recovered and not lab.player.combo.active(), "Release plays the source finisher recovery")
	check(lab.player.drop_for_lab(5.0), "Airborne fixture starts a drop")
	await ticks(3)
	attack(true)
	await ticks(4)
	attack(false)
	check(not lab.player.combo.active(), "Curved Greatsword does not play another weapon's aerial attack")
	await ticks(55)
	weapon.select(1)
	weapon.item_selected.emit(1)
	check(weapon.selected == 1 and group.sword_equipped, "The Sword can be equipped again")
	weapon.select(0)
	weapon.item_selected.emit(0)
	check(weapon.selected == 0 and not group.sword_equipped, "The Sabre can be equipped again")
	finish(lab)

func finish(lab: Node) -> void:
	lab.free()
	print("MECHANIC_LAB_CURVED ", JSON.stringify({"attacks": attacks, "target_hp": damage, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
