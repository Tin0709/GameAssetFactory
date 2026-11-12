extends SceneTree

const ZOMBIE = preload("res://scripts/mechanic_lab_zombie.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)

func mouse(button: MouseButton, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var weapon := lab.get_node("HUD/Weapon") as OptionButton
	var spawn := lab.get_node("HUD/SpawnZombie") as Button
	var group := lab.get_node("Zombies") as Node3D
	check(not weapon.disabled and not spawn.disabled, "Private Sword and Zombie are available")
	if weapon.disabled or spawn.disabled:
		quit(1)
		return
	weapon.select(1)
	weapon.item_selected.emit(1)
	spawn.pressed.emit()
	spawn.pressed.emit()
	check(group.get_child_count() == 2, "Two zombies are present")
	if group.get_child_count() != 2:
		quit(1)
		return
	var attacker = group.get_child(0)
	attacker.position = Vector3(0.0, 0.0, -1.8)
	attacker.rotation.y = 0.0
	var practice_target = group.get_child(1)
	practice_target.set_physics_process(false)
	practice_target.position = Vector3(0.0, 0.0, 1.35)
	lab._on_player_hit(94)
	for i in 60:
		await physics_frame
		if attacker.animation.current_animation == ZOMBIE.ATTACK and attacker.animation.current_animation_position >= 0.33:
			break
	check(attacker.animation.current_animation == ZOMBIE.ATTACK, "Zombie starts a real attack")
	var had_ribbon := false
	key(KEY_E, true)
	for i in 30:
		await physics_frame
		if lab.player_health == 0:
			break
		had_ribbon = had_ribbon or lab.player.effects.samples.size() > 1
	check(had_ribbon and lab.player_health == 0, "A real zombie hit interrupts a visible Sword swing")
	await ticks(18)
	check(lab.player.is_dead and not lab.player.combo.active() and not lab.player.combo.held,
		"Defeat cancels the current strike and held input")
	check(lab.player.active_clip == "Idle" and lab.player.effects.samples.is_empty()
		and lab.player.effects.ribbon.mesh.get_surface_count() == 0,
		"Defeat releases the sword pose and removes the lingering trail")
	var respawn := lab.get_node_or_null("HUD/Defeat/Card/Content/Respawn") as Button
	check(respawn != null and respawn.is_visible_in_tree(), "Defeat shows a visible retry button")
	var size: float = lab.camera.size
	mouse(MOUSE_BUTTON_WHEEL_UP, Vector2(330, 220), true)
	await ticks(3)
	check(lab.camera.size < size, "Zoom still works at zero HP")
	key(KEY_E, false)
	key(KEY_R, true)
	key(KEY_R, false)
	await ticks(4)
	check(lab.player_health == 100 and not lab.player.is_dead and not lab.player.combo.active(),
		"R respawns at full HP with a clean input state")
	if respawn != null:
		check(not respawn.is_visible_in_tree(), "Retry prompt hides after R")
		check(lab.player.drop_for_lab(5.0), "Airborne defeat fixture starts a five-metre drop")
		await ticks(3)
		lab._on_player_hit(100)
		var height: float = lab.player.global_position.y
		key(KEY_E, true)
		await ticks(60)
		key(KEY_E, false)
		check(height > 3.0 and lab.player.is_on_floor() and not lab.player.combo.active(),
			"Airborne defeat settles to the floor while combat input stays disabled")
		var point := respawn.get_global_rect().get_center()
		mouse(MOUSE_BUTTON_LEFT, point, true)
		mouse(MOUSE_BUTTON_LEFT, point, false)
		await ticks(4)
		check(lab.player_health == 100 and not lab.player.is_dead and not respawn.is_visible_in_tree(),
			"Clicking Retry respawns without starting an attack")
		check(not lab.player.combo.active() and weapon.selected == 1,
			"Retry leaves no queued attack and preserves the selected weapon")
	var popup := weapon.get_popup()
	weapon.show_popup()
	await ticks(2)
	check(popup.visible, "Weapon menu opens during play")
	lab._on_player_hit(100)
	await ticks(2)
	check(not popup.visible and weapon.disabled, "Defeat dismisses and locks the weapon menu")
	key(KEY_R, true)
	key(KEY_R, false)
	await ticks(4)
	check(lab.player_health == 100 and not weapon.disabled and weapon.selected == 1,
		"R retries after defeat with the weapon menu open and restores the selection")
	lab.free()
	print("MECHANIC_LAB_DEFEAT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
