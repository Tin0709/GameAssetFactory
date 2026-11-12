extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func attack(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var lab = preload("res://scenes/dev/MechanicLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var effects = lab.player.effects
	var material := effects.ribbon.material_override as ShaderMaterial
	var source := material.get_shader_parameter(&"source_slash") as Texture2D
	check(source != null and source.get_size() == Vector2(128, 128)
		and material.get_shader_parameter(&"use_source_slash") == true,
		"MechanicLab loads the verified native slash texture into the ribbon material")
	var selector := lab.get_node("HUD/Weapon") as OptionButton
	var weapons := [&"Sabre", &"Sword", &"Curved Greatsword"]
	for slot in weapons.size():
		lab.reset_player()
		selector.select(slot)
		selector.item_selected.emit(slot)
		for i in 20:
			await physics_frame
		attack(true)
		var found := false
		var age_span := 0.0
		for i in 75:
			await process_frame
			if effects.ribbon.mesh.get_surface_count() == 0:
				continue
			found = true
			var arrays: Array = effects.ribbon.mesh.surface_get_arrays(0)
			if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
				for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
					age_span = maxf(age_span, uv.y)
			if age_span > 0.03:
				break
		attack(false)
		check(found and age_span > 0.03, "A real %s swing carries temporal UVs in its ribbon" % weapons[slot])
		check(not lab.get_node("CombatImpactLight").visible, "A missed %s swing has no hit light" % weapons[slot])
		var sparks := lab.get_node_or_null("ContactSparks/Streaks") as MultiMeshInstance3D
		check(sparks != null and sparks.multimesh.visible_instance_count == 0,
			"A missed %s swing has no contact streaks" % weapons[slot])
	lab.reset_player()
	await physics_frame
	check(effects.ribbon.mesh.get_surface_count() == 0, "Reset clears the textured slash geometry")
	print("MECHANIC_LAB_SLASH_VFX failures=", failures)
	lab.free()
	quit(0 if failures.is_empty() else 1)
