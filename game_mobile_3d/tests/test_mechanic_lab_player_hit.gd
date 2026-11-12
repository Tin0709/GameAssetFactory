extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL ", description)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await ticks(12)
	var body := lab.player.model.find_child("SabrePrototypeBody", true, false) as MeshInstance3D
	var face := lab.player.face as MeshInstance3D
	var weapon := lab.player.model.find_child("SabrePrototypeSabre", true, false) as MeshInstance3D
	var original_overlay := body.material_overlay
	var weapon_overlay := weapon.material_overlay
	lab.get_node("HUD/SpawnZombie").pressed.emit()
	for i in 180:
		await physics_frame
		if lab.player_health < 100:
			break
	var numbers := lab.get_node_or_null("CombatEffects/PlayerDamageNumbers")
	check(lab.player_health == 94, "A real zombie attack takes six HP")
	check(body.material_overlay != original_overlay and face.material_overlay == body.material_overlay
		and weapon.material_overlay == weapon_overlay, "The body and face flash while the weapon retains its material")
	check(numbers != null and numbers.get_child_count() == 1, "One number appears on the real hit")
	if numbers != null and numbers.get_child_count() == 1:
		var number := numbers.get_child(0) as Node3D
		var digit := number.get_child(0) as Sprite3D
		check(number.get_meta("amount") == 6 and digit.modulate.r > digit.modulate.g * 2.0,
			"The number shows actual HP lost in red")
		var start := number.global_position
		await ticks(10)
		check(number.global_position.y > start.y and body.material_overlay == original_overlay,
			"The number floats upward while the short flash clears")
	await ticks(45)
	check(numbers != null and numbers.get_child_count() == 0, "The floating number expires")
	var remaining: int = lab.player_health
	lab._on_player_hit(999)
	check(lab.player_health == 0 and lab.player.is_dead and body.material_overlay != original_overlay,
		"A lethal hit still flashes and enters defeat")
	if numbers != null:
		check(numbers.get_child_count() == 1 and numbers.get_child(0).get_meta("amount") == remaining,
			"Overkill displays only the HP actually lost")
		lab._on_player_hit(1)
		check(numbers.get_child_count() == 1, "Damage after defeat adds no number")
	lab.reset_player()
	await ticks(3)
	check(lab.player_health == 100 and body.material_overlay == original_overlay
		and numbers != null and numbers.get_child_count() == 0, "Retry clears player hit effects")
	lab.free()
	print("MECHANIC_LAB_PLAYER_HIT failures=", failures)
	quit(0 if failures.is_empty() else 1)
