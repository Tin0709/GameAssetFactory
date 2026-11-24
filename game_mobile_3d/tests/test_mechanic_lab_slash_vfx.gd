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
	for slot in [0, 1, 2, 5, 8, 9, 10]:
		lab.reset_player()
		for i in 8:
			await physics_frame
		selector.select(slot)
		selector.item_selected.emit(slot)
		var weapon := selector.get_item_text(slot)
		check(selector.selected == slot, "The ground fixture equips %s" % weapon)
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
		check(found and age_span > 0.03, "A real %s swing carries temporal UVs in its ribbon" % weapon)
		check(not lab.get_node("CombatImpactLight").visible, "A missed %s swing has no hit light" % weapon)
		var sparks := lab.get_node_or_null("ContactSparks/Streaks") as MultiMeshInstance3D
		check(sparks != null and sparks.multimesh.visible_instance_count == 0,
			"A missed %s swing has no contact streaks" % weapon)
	for slot in [3, 4, 7]:
		lab.reset_player()
		for i in 12:
			await physics_frame
		selector.select(slot)
		selector.item_selected.emit(slot)
		var weapon := selector.get_item_text(slot)
		check(selector.selected == slot, "The non-blade fixture equips %s" % weapon)
		var accepted: int = lab.player.accepted_count
		var bursts: int = effects.bursts
		attack(true)
		for i in 45:
			await physics_frame
		attack(false)
		check(lab.player.accepted_count > accepted, "%s accepted real attack input" % weapon)
		check(effects.bursts == bursts and effects.samples.is_empty(),
			"%s does not emit legacy blade sparks at the start of an attack" % weapon)
	lab.reset_player()
	await physics_frame
	check(effects.ribbon.mesh.get_surface_count() == 0, "Reset clears the textured slash geometry")
	await check_ground_ribbon_edges(lab, selector)
	await check_sabre_dive(lab, selector)
	lab.free()
	await check_world_map_slash()
	print("SABRE_SLASH_VFX failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check_ground_ribbon_edges(lab, selector: OptionButton) -> void:
	for slot in [0, 1, 2, 5, 8, 9, 10]:
		lab.reset_player()
		for i in 12:
			await physics_frame
		selector.select(slot)
		selector.item_selected.emit(slot)
		var actor = lab.player
		var effects = actor.effects
		var weapon := selector.get_item_text(slot)
		var step := 1.0 / Engine.physics_ticks_per_second
		var seen := false
		var ended := false
		var start_delay := 0.0
		var end_shortfall := 0.0
		attack(true)
		for i in 80:
			await physics_frame
			if actor.combo.phase != &"attack":
				continue
			var window: Array = actor.combo.native_windows[actor.combo.index].trail_window
			var clip_time: float = actor.combo.time
			var rate: float = actor.combo.playback_rate()
			if not seen and effects._was_active:
				seen = true
				attack(false)
				var start: float = effects.clock - (clip_time - float(window[0])) / rate
				start_delay = float(effects.samples[0].time) - start
				check(absf(start_delay) < 0.00001, "%s begins the ribbon at the cue inside the physics tick" % weapon)
				check(effects.samples_at(start - 0.00001).is_empty(), "%s has no ribbon before the cue" % weapon)
				if effects.clock - start > 0.00002:
					effects.present((start + effects.clock) * 0.5)
					check(effects.ribbon.mesh.get_surface_count() == 1,
						"%s already draws a ribbon between the cue and first physics sample" % weapon)
			elif seen and not effects._was_active:
				ended = true
				var end_age := (clip_time - float(window[1])) / rate
				if end_age < step:
					var end: float = effects.clock - end_age
					end_shortfall = end - float(effects.samples[-1].time)
					check(absf(end_shortfall) < 0.00001, "%s stops sampling at the end of the trail window" % weapon)
				break
		attack(false)
		check(seen and ended, "%s passes both edges of its real ground trail" % weapon)
		print("GROUND_RIBBON_EDGES weapon=", weapon, " start_delay_ms=", start_delay * 1000.0,
			" end_shortfall_ms=", end_shortfall * 1000.0)
	lab.reset_player()

func check_sabre_dive(lab, selector: OptionButton) -> void:
	for i in 8:
		await physics_frame
	selector.select(0)
	selector.item_selected.emit(0)
	check(selector.selected == 0, "The aerial fixture equips Sabre")
	var actor: CharacterBody3D = lab.player
	var landings: Array[int] = []
	actor.heavy_jump_landed.connect(func(_point, _facing, _serial, _height):
		landings.append(Engine.get_physics_frames()))
	for height in [5, 7, 16]:
		lab.reset_player()
		for i in 8:
			await physics_frame
		landings.clear()
		if height == 16:
			check(actor.drop_for_lab(height), "The extended drop starts on the flat floor")
		else:
			lab.get_node("HUD/DropMedium" if height == 5 else "HUD/DropHigh").pressed.emit()
		for i in 2:
			await physics_frame
		attack(true)
		await physics_frame
		attack(false)
		var slash_frame := -1
		var last_air_time := 0.0
		var air_loops := 0
		var ribbon_rendered := false
		var landing_pose_time := -1.0
		for i in Engine.physics_ticks_per_second:
			await physics_frame
			if landings.is_empty() and actor.combo.phase == &"air_attack":
				if actor.combo.time < last_air_time:
					air_loops += 1
				last_air_time = actor.combo.time
			if landings.size() == 1 and landing_pose_time < 0.0:
				landing_pose_time = actor.animation_player.current_animation_position
			if not actor.effects.samples.is_empty() and slash_frame < 0:
				slash_frame = Engine.get_physics_frames() - 1
			if slash_frame >= 0 and actor.effects.ribbon.mesh.get_surface_count() > 0:
				ribbon_rendered = true
		check(landings.size() == 1 and air_loops >= 1,
			"%d m drop remains in the authored airborne loop until real floor contact" % height)
		check(landing_pose_time >= 0.233467355 and landing_pose_time <= 0.233467355 + 1.0 / Engine.physics_ticks_per_second + 0.0001,
			"%d m drop enters the landing section on touchdown" % height)
		check(not landings.is_empty() and slash_frame == landings[0] + ceili(0.055629984 * Engine.physics_ticks_per_second),
			"%d m drop creates the first blade ribbon sample at the montage slash cue" % height)
		check(ribbon_rendered, "The samples produce blade ribbon geometry during the landing slash")
		print("SABRE_DIVE_SLASH height=", height, " loops=", air_loops,
			" landing=", landings, " pose=", landing_pose_time, " slash=", slash_frame)

func check_world_map_slash() -> void:
	var world := (load("res://scenes/WorldMap.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	var ribbon: MeshInstance3D = world.player.effects.ribbon
	var material := ribbon.material_override as ShaderMaterial
	var source: Texture2D
	if material != null:
		source = material.get_shader_parameter(&"source_slash") as Texture2D
	check(source != null and source.get_size() == Vector2(128, 128)
		and material.get_shader_parameter(&"use_source_slash") == true,
		"WorldMap equips the verified MD2 mask on the live Sabre ribbon")
	for i in 20:
		await physics_frame
	attack(true)
	var animated_uv := false
	for i in 90:
		await process_frame
		if ribbon.mesh.get_surface_count() > 0:
			var uvs: PackedVector2Array = ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			for uv in uvs:
				animated_uv = animated_uv or uv.y > 0.03
		if animated_uv:
			break
	attack(false)
	check(animated_uv, "WorldMap E input animates the mask on the live blade ribbon")
	world.reset_player()
	await physics_frame
	check(ribbon.mesh.get_surface_count() == 0, "WorldMap reset clears the blade ribbon")
	world.free()
