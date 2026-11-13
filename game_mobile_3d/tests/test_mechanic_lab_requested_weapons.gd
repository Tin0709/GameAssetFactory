extends SceneTree

var failures := 0
var contacts: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func equip(menu: OptionButton, index: int) -> void:
	menu.select(index)
	menu.item_selected.emit(index)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var menu := lab.get_node("HUD/Weapon") as OptionButton
	var original_air: Dictionary = lab.player.clips.AirAttack
	check(not menu.disabled and menu.item_count == 5, "Both requested weapons appear in the live selector")
	if menu.item_count != 5:
		quit(1)
		return
	check(menu.get_item_text(3) == "The Cross Pollinator", "The Cross Pollinator is named correctly")
	check(menu.get_item_text(4) == "Prime Enchanter's Gauntlets", "Prime Enchanter's Gauntlets are named correctly")
	var group := lab.get_node("Zombies")
	group.sabre_contact.connect(func(_p, _d, clip, _i, _s, _k): contacts.append(clip))
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	if group.get_child_count() != 1:
		check(false, "Verified zombie loads")
		quit(1)
		return
	var target = group.get_child(0)
	target.set_physics_process(false)
	target.health = 100
	target.position = Vector3(0.0, 0.0, 5.0)

	equip(menu, 3)
	var ammo := lab.get_node("HUD/CrossbowAmmo") as Label
	check(menu.selected == 3 and ammo.visible and ammo.text.contains("25 / 25"), "Crossbow equips with full ammo")
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(24)
	check(target.health == 92 and contacts.size() == 1, "A tap shoots one 8-damage bolt at a ranged target")
	check(ammo.text.contains("24 / 25"), "One projectile consumes one arrow")
	await ticks(115)
	check(ammo.text.contains("25 / 25"), "Ammo refills")

	var barrier := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 2.6, 0.15)
	collider.shape = box
	barrier.add_child(collider)
	barrier.position = Vector3(0.0, 1.3, 2.5)
	lab.add_child(barrier)
	await ticks(2)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(64)
	check(target.health == 92 and contacts.size() == 1, "A wall blocks the bolt from hitting the zombie")
	barrier.queue_free()

	lab.reset_player()
	await ticks(12)
	target.position = Vector3(2.5, 0.0, 3.0)
	lab.player._q = true
	attack(true)
	await ticks(2)
	attack(false)
	lab.player._q = false
	await ticks(66)
	check(target.health == 92, "Manual facing does not redirect the bolt to an off-axis zombie")

	lab.reset_player()
	await ticks(12)
	target.position = Vector3(0.0, 0.0, 4.0)
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(5)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(4)
	check(ammo.text.contains("24 / 25"), "Crossbow can fire during a fall")
	await ticks(90)
	check(target.health == 84, "A bolt fired above the melee height limit can hit a zombie on the ground")

	lab.reset_player()
	await ticks(12)
	attack(true)
	await ticks(3)
	Input.action_press("jump")
	await ticks(10)
	Input.action_release("jump")
	attack(false)
	check(not lab.player.is_on_floor() and lab._crossbow.ammo < 24,
		"Holding fire continues after an accepted jump")

	lab.reset_player()
	await ticks(12)
	target.position = Vector3(12.0, 0.0, 5.0)
	attack(true)
	await ticks(250)
	check(ammo.text.contains("0 / 25"), "Holding fire consumes the full magazine")
	check(lab._crossbow.get_child_count() <= 25, "An empty magazine cannot emit extra bolts")
	attack(false)
	await ticks(120)
	check(not ammo.text.contains("0 / 25"), "An empty magazine can recharge")

	equip(menu, 4)
	check(menu.selected == 4 and not ammo.visible, "Gauntlets equip and hide the ranged ammo")
	target.position = Vector3(0.0, 0.0, 1.65)
	target.health = 100
	contacts.clear()
	attack(true)
	await ticks(68)
	attack(false)
	await ticks(100)
	check(contacts.size() >= 3 and contacts.slice(0, 3) == [
		"NativeGauntletAttack1", "NativeGauntletAttack2", "NativeGauntletAttack3",
	], "Held input plays all three gauntlet strikes in order")
	check(target.health <= 65, "Gauntlet combo applies its own 10/11/14 damage")
	lab.reset_player()
	await ticks(12)
	var sound := lab.get_node("HUD/CombatAudioToggle") as CheckButton
	sound.button_pressed = true
	var combat_audio = lab.get_node("CombatAudio")
	var mauler_samples: Array = combat_audio._groups.get(&"mauler_dive", [])
	check(mauler_samples.size() == 3, "All three verified MD2 Mauler Dive samples load")
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(65)
	check(not combat_audio._next_choice.has(&"mauler_dive"), "An ordinary landing does not play Mauler Dive")
	lab.reset_player()
	await ticks(12)
	target.position = Vector3(0.0, 0.0, 1.6)
	target.health = 100
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(5)
	attack(true)
	await ticks(2)
	attack(false)
	check(not combat_audio._next_choice.has(&"mauler_dive"), "Mauler Dive audio waits for contact")
	await ticks(95)
	check(target.health < 100 and contacts.has("AirAttack"), "Gauntlets can hit with their jump slam")
	check(combat_audio._next_choice.get(&"mauler_dive", 0) == 1, "The first slam plays one Mauler Dive cue")
	check(lab.player.clips.AirAttack.source_name == "Player_Jump_Gauntlet-Attack_Heavy", "The slam uses the source gauntlet pose")
	equip(menu, 0)
	check(menu.selected == 0 and lab.player.clips.AirAttack == original_air,
		"Switching back restores the original Sabre")
	print("MECHANIC_LAB_REQUESTED_WEAPONS failures=", failures)
	quit(1 if failures else 0)
