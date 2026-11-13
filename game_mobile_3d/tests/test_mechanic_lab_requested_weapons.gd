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

	equip(menu, 4)
	check(menu.selected == 4 and not ammo.visible, "Gauntlets equip and hide the ranged ammo")
	target.position.z = 1.65
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
	target.position = Vector3(0.0, 0.0, 1.6)
	target.health = 100
	lab.get_node("HUD/DropMedium").pressed.emit()
	await ticks(5)
	attack(true)
	await ticks(2)
	attack(false)
	await ticks(95)
	check(target.health < 100 and contacts.has("AirAttack"), "Gauntlets can hit with their jump slam")
	check(lab.player.clips.AirAttack.source_name == "Player_Jump_Gauntlet-Attack_Heavy", "The slam uses the source gauntlet pose")
	equip(menu, 0)
	check(menu.selected == 0 and lab.player.clips.AirAttack == original_air,
		"Switching back restores the original Sabre")
	print("MECHANIC_LAB_REQUESTED_WEAPONS failures=", failures)
	quit(1 if failures else 0)
