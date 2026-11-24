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
	await check_tool_slash_cues(lab, selector)
	await check_axe_sweep_windows(lab, selector)
	await check_aerial_tool_effects(lab, selector)
	await check_curved_finisher_ribbon(lab, selector)
	await check_sabre_dive(lab, selector)
	await check_wall_ribbons(lab, selector)
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

func check_tool_slash_cues(lab, selector: OptionButton) -> void:
	# Sound and melee notifies have separate clocks. Compare the first sample
	# to the resolved slash notify of each montage segment, not the hit frame.
	var cues := {
		lab.Weapon.CLEAVER: [0.099451, 0.143989, 0.268076],
		lab.Weapon.PICKAXE: [0.121726, 0.175193, 0.243789],
		lab.Weapon.SHOVEL: [0.143855, 0.395919, 0.265945],
	}
	for slot: int in cues:
		lab.reset_player()
		for i in 12:
			await physics_frame
		selector.select(slot)
		selector.item_selected.emit(slot)
		var actor = lab.player
		var effects = actor.effects
		var weapon := selector.get_item_text(slot)
		var recorded: Array[float] = []
		attack(true)
		for i in Engine.physics_ticks_per_second * 5:
			await physics_frame
			if actor.combo.phase != &"attack" or effects.serial != actor.combo.serial:
				continue
			var index: int = actor.combo.index
			if index != recorded.size() or effects.samples.is_empty():
				continue
			var first: float = effects.samples[0].time
			var cue: float = actor.combo.time - (effects.clock - first) * actor.combo.playback_rate()
			recorded.append(cue)
			check(absf(cue - float(cues[slot][index])) < 0.00001,
				"%s combo %d emits at the source slash cue (%.6f)" % [weapon, index + 1, cue])
			if recorded.size() == 3:
				break
		attack(false)
		check(recorded.size() == 3, "%s reaches all three slash cues during held attack input" % weapon)
		print("TOOL_SLASH_CUES weapon=", weapon, " source_seconds=", recorded)
	lab.reset_player()

func check_axe_sweep_windows(lab, selector: OptionButton) -> void:
	var actor = lab.player
	var effects = actor.effects
	var expected := [Vector2(0.083333, 0.175), Vector2(0.141667, 0.266667),
		Vector2(0.150, 0.333333), Vector2(0.622641, 0.675)]
	for aerial in [false, true]:
		lab.reset_player()
		for i in 12:
			await physics_frame
		selector.select(lab.Weapon.AXE)
		selector.item_selected.emit(lab.Weapon.AXE)
		if aerial:
			lab._drop_player(5.0)
			for i in 2:
				await physics_frame
		attack(true)
		var recorded := {}
		for i in Engine.physics_ticks_per_second * 4:
			await physics_frame
			if aerial:
				attack(false)
				if actor.combo.phase != &"air_attack" or not actor.combo.air_landing_started:
					continue
			elif actor.combo.phase != &"attack":
				continue
			var index: int = 3 if aerial else actor.combo.index
			if effects.serial == actor.combo.serial:
				var range_seen: Vector2 = recorded.get(index, Vector2(INF, -INF))
				for point: Dictionary in effects.samples:
					var time: float = actor.combo.time - (effects.clock - float(point.time)) * actor.combo.playback_rate()
					range_seen.x = minf(range_seen.x, time)
					range_seen.y = maxf(range_seen.y, time)
				recorded[index] = range_seen
			if index == (3 if aerial else 2) and actor.combo.time > float(expected[index].y) + 0.08:
				break
		attack(false)
		var indices := [3] if aerial else [0, 1, 2]
		for index: int in indices:
			var range_seen: Vector2 = recorded.get(index, Vector2.ZERO)
			check(range_seen.distance_to(expected[index]) < 0.00002,
				"Axe swing %d samples its full measured sweep and stops before recovery" % (index + 1))
		print("AXE_SWEEP_WINDOWS aerial=", aerial, " ranges=", recorded)
	lab.reset_player()

func check_aerial_tool_effects(lab, selector: OptionButton) -> void:
	var actor = lab.player
	var effects = actor.effects
	var cue_times: Array[float] = []
	var early_ground_cue: Array[bool] = []
	var record := func(_cue: Dictionary, _serial: int, at: float):
		cue_times.append(actor.combo.time - (effects.clock - at) * actor.combo.playback_rate())
		early_ground_cue.append(not actor.combo.air_landing_started)
	actor.tool_ground_cue.connect(record)
	var expected := {
		lab.Weapon.CLEAVER: [0.258916, 0.262468, 0.262824, 0.264515, 0.271219],
		lab.Weapon.PICKAXE: [0.619433, 0.623386, 0.626369, 0.633079],
		lab.Weapon.SHOVEL: [0.454490, 0.460621, 0.463408, 0.467310],
	}
	for fixture: Vector3i in [Vector3i(lab.Weapon.CLEAVER, 5, 0), Vector3i(lab.Weapon.PICKAXE, 5, 0),
			Vector3i(lab.Weapon.PICKAXE, 70, 0), Vector3i(lab.Weapon.SHOVEL, 5, 0), Vector3i(lab.Weapon.PICKAXE, 5, 1)]:
		lab.reset_player()
		for i in 8:
			await physics_frame
		var slot := fixture.x
		var wall: StaticBody3D
		if fixture.z == 1:
			wall = StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var wall_shape := BoxShape3D.new()
			wall_shape.size = Vector3(2.0, 3.0, 0.2)
			collision.shape = wall_shape
			wall.add_child(collision)
			var facing: Vector3 = actor.visual.global_basis.z.slide(Vector3.UP).normalized()
			wall.transform = Transform3D(Basis.looking_at(facing, Vector3.UP, true), facing + Vector3.UP)
			lab.add_child(wall)
		selector.select(slot)
		selector.item_selected.emit(slot)
		cue_times.clear()
		early_ground_cue.clear()
		lab._drop_player(fixture.y)
		for i in 2:
			await physics_frame
		attack(true)
		await physics_frame
		attack(false)
		var sections := {}
		var flight_count := 0
		var landing_count := 0
		var ring_seen := false
		var mixed_palette_seen := false
		for i in Engine.physics_ticks_per_second * 3:
			await physics_frame
			for point: Dictionary in effects.samples:
				if sections.has(point.section):
					continue
				var start_time: float = actor.combo.time - (effects.clock - float(point.time)) * actor.combo.playback_rate()
				sections[point.section] = start_time
				if actor.combo.air_landing_started:
					landing_count += 1
					var start := 0.257850 if slot == lab.Weapon.CLEAVER else 0.622641
					check(absf(start_time - start) < 0.00001, "The landing trail starts at the montage cue")
					check(is_equal_approx(point.lifetime, 0.15), "The landing trail keeps its own shorter fade")
				else:
					flight_count += 1
					check(slot == lab.Weapon.PICKAXE and absf(start_time - 0.091948) < 0.00001,
						"Only Pickaxe draws a falling trail, at its own montage cue")
					check(is_equal_approx(point.lifetime, 0.30), "The falling trail keeps its longer fade")
			if not mixed_palette_seen and slot == lab.Weapon.PICKAXE and actor.combo.air_landing_started:
				effects.present(effects.clock)
				var mesh: Mesh = effects.ribbon.mesh
				if mesh.get_surface_count() > 0:
					var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
					var blue := false
					var rose := false
					for color in colors:
						blue = blue or color.b > color.r
						rose = rose or color.r > color.b and color.b > color.g
					mixed_palette_seen = blue and rose
			ring_seen = ring_seen or lab._tool_slam_ring.visible
			if actor.combo.air_landing_started and actor.combo.phase != &"air_attack":
				break
		var context := "%s from %.0f m" % [selector.get_item_text(slot), fixture.y]
		if wall != null:
			context += " in front of a wall"
		check(cue_times.size() == expected[slot].size() and not early_ground_cue.has(true),
			"%s plays each ground layer once after landing" % context)
		for index in mini(cue_times.size(), expected[slot].size()):
			check(absf(cue_times[index] - float(expected[slot][index])) < 0.00001,
				"%s layer %d uses the authored source timestamp" % [context, index + 1])
		check(ring_seen == (wall == null), "%s shows the shockwave only on unobstructed ground" % context)
		check(landing_count == (0 if slot == lab.Weapon.SHOVEL else 1),
			"%s has the correct number of landing strips" % context)
		check(flight_count >= (2 if fixture.y > 5 else 1) if slot == lab.Weapon.PICKAXE else flight_count == 0,
			"%s uses the appropriate falling slash on each loop" % context)
		if slot == lab.Weapon.PICKAXE and fixture.y == 5 and wall == null:
			check(mixed_palette_seen, "An overlapping blue falling strip and rose landing strip keep distinct colors")
		print("TOOL_AERIAL_FX ", context, " ground=", cue_times, " flight=", flight_count, " landing=", landing_count)
		if wall != null:
			wall.free()
	actor.tool_ground_cue.disconnect(record)
	lab.reset_player()

func check_curved_finisher_ribbon(lab, selector: OptionButton) -> void:
	lab.reset_player()
	for i in 12:
		await physics_frame
	selector.select(lab.Weapon.CURVED_GREATSWORD)
	selector.item_selected.emit(lab.Weapon.CURVED_GREATSWORD)
	var actor = lab.player
	var effects = actor.effects
	var sample_frames: Dictionary = {}
	var bridged := false
	var interpolated_in_gap := false
	var observed_changeover := false
	var burst_count := -1
	attack(true)
	for i in Engine.physics_ticks_per_second * 5:
		await physics_frame
		if actor.combo.phase != &"attack" or actor.combo.index != 2:
			continue
		var frame: float = actor.combo.time * 30.0
		if frame < 4.0:
			burst_count = effects.bursts
		if effects.serial != actor.combo.serial:
			continue
		var rate: float = actor.combo.playback_rate()
		var start: float = effects.clock - actor.combo.time / rate
		for sample in effects.samples:
			var source_frame: float = (float(sample.time) - start) * rate * 30.0
			sample_frames[snappedf(source_frame, 0.0001)] = true
		var shown: Array = effects.samples_at(effects.clock)
		var gap_start := start + 10.001 / (rate * 30.0)
		var gap_end := start + 14.001 / (rate * 30.0)
		if shown.size() > 2 and shown[0].time < gap_start and shown[-1].time > gap_end:
			observed_changeover = true
			var during_gap: Array = effects.samples_at(start + 13.99 / (rate * 30.0))
			interpolated_in_gap = interpolated_in_gap or during_gap.any(func(sample): return sample.time > gap_start)
			var mesh: Mesh = effects.ribbon.mesh
			effects.present(effects.clock)
			var vertex_count := 0
			if mesh.get_surface_count() > 0:
				var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				vertex_count = vertices.size()
			# Two strips (body and bright edge) per span on the clear floor.
			# One adjacent pair straddles the gap and must contribute no vertices.
			bridged = bridged or vertex_count != (shown.size() - 2) * 12
		if frame >= 23.0:
			break
	attack(false)
	var frames := sample_frames.keys()
	frames.sort()
	check(frames.has(5.0) and frames.has(10.0) and frames.has(14.0) and frames.has(21.0),
		"The two Curved Greatsword arcs sample their four authored edges")
	check(not frames.any(func(frame: float): return frame > 10.001 and frame < 13.999),
		"The blade does not paint a ribbon during the rear turn")
	check(observed_changeover and not bridged, "Visible pieces of the two arcs have no connecting triangle strip")
	check(not interpolated_in_gap, "Interpolation cannot draw a bridge before the second arc")
	check(burst_count >= 0 and effects.bursts - burst_count == 1,
		"The dual arc keeps one legacy blade burst per swing")
	print("CURVED_FINISHER_TRAIL gap_samples=", frames.filter(func(frame: float): return frame > 10.001 and frame < 13.999).size(),
		" overlap=", observed_changeover, " bridge=", bridged)
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

func check_wall_ribbons(lab, selector: OptionButton) -> void:
	for slot in [0, 10]:
		for airborne in [false, true]:
			var wall_faces := [INF, 0.52, 0.9, 1.35] if airborne and slot == 10 else [INF, 0.9]
			for wall_face: float in wall_faces:
				lab.reset_player()
				for i in 8:
					await physics_frame
				selector.select(slot)
				selector.item_selected.emit(slot)
				var actor: CharacterBody3D = lab.player
				var forward: Vector3 = actor.visual.global_basis.z.slide(Vector3.UP).normalized()
				var wall: StaticBody3D
				if is_finite(wall_face):
					wall = StaticBody3D.new()
					wall.transform = Transform3D(Basis.looking_at(forward, Vector3.UP, true),
						forward * (wall_face + 0.1) + Vector3.UP * 2.5)
					var shape := BoxShape3D.new()
					shape.size = Vector3(4.0, 5.0, 0.2)
					var collider := CollisionShape3D.new()
					collider.shape = shape
					wall.add_child(collider)
					lab.add_child(wall)
					await physics_frame
				if airborne:
					check(actor.drop_for_lab(5.0), "The wall ribbon fixture starts a drop")
					for i in 2:
						await physics_frame
				attack(true)
				await physics_frame
				attack(false)
				var mesh: Mesh = actor.effects.ribbon.mesh
				var frames := 0
				var furthest := -INF
				var nearest := INF
				var until := Engine.get_physics_frames() + Engine.physics_ticks_per_second
				while Engine.get_physics_frames() < until:
					await process_frame
					if mesh.get_surface_count() == 0:
						continue
					frames += 1
					for point: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
						furthest = maxf(furthest, point.dot(forward))
						nearest = minf(nearest, point.dot(forward))
				var context := "%s air=%s wall=%s" % [selector.get_item_text(slot), airborne, wall_face]
				if slot == 10 and airborne and wall_face == 0.52:
					check(frames == 0, "A wall entirely in front of the Axe dive's ribbon hides it")
				else:
					check(frames > 0, "The unobstructed portion of the ribbon still draws for %s" % context)
				if wall != null:
					check(furthest <= wall_face + 0.0001, "The ribbon ends on the player's side of the wall for %s" % context)
					wall.free()
				elif airborne and slot == 10:
					check(nearest > 0.52 and nearest < 0.9 and furthest > 1.35,
						"The Axe dive is beyond the closest wall and straddles the middle and distant walls")
				print("RIBBON_WALL ", context, " frames=", frames, " nearest=", nearest, " furthest=", furthest)

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
