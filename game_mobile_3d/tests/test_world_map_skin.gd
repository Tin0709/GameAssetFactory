extends SceneTree

var failures: Array[String]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func draw(count: int) -> void:
	for index in count:
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw

func run() -> void:
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await draw(5)
	var actor: CharacterBody3D = world.player
	var rig: Skeleton3D = actor.skeleton
	var body := actor.model.find_child("SabrePrototypeBody", true, false) as MeshInstance3D
	var weapon := actor.model.find_child("SabrePrototypeSabre", true, false) as MeshInstance3D
	var original_lamp: Node3D = actor.lantern
	var picker = world.showcase._settings._widgets.get("player-skin") as OptionButton
	check(picker != null, "WorldMap character settings expose the live skin dropdown")
	if picker == null:
		finish(world)
		return
	check(picker.item_count == 2 and picker.selected == 0 and not picker.is_item_disabled(1),
		"Both private skins are selectable and MD2 starts as the current look")
	var spawn := actor.global_position
	world.showcase.set_hour(22.)
	await draw(24)
	var old_position := actor.global_position
	var source_lamp_visual: Node3D = original_lamp.lantern_center
	var source_lit: bool = original_lamp.lit
	var source_toggle_time: float = original_lamp.toggle_time
	var point: OmniLight3D = world.showcase._player_light
	var point_origin := point.global_position if point != null else Vector3.INF
	var point_energy := point.light_energy if point != null else 0.
	var point_color := point.light_color if point != null else Color.BLACK
	picker.get_popup().about_to_popup.emit()
	picker.select(1)
	picker.item_selected.emit(1)
	var kai := actor.get_node_or_null("KaiAppearance") as Node3D
	check(kai != null and kai.is_visible_in_tree() and not body.is_visible_in_tree(),
		"Kai replaces the visible MD2 skin")
	if kai == null:
		finish(world)
		return
	check(actor == world.player and rig == actor.skeleton and weapon.is_visible_in_tree() and actor.global_position == old_position,
		"Appearance swap keeps the actor, same controller rig, weapon and position")
	var lamp := kai.find_child("Kai Run | MD2 metal lantern", true, false) as MeshInstance3D
	var leather := kai.find_child("Kai Run | Body", true, false) as MeshInstance3D
	var clasp := kai.find_child("Kai Run | MD2 lantern clasp", true, false) as MeshInstance3D
	check(lamp != null and clasp != null and lamp.is_visible_in_tree() and clasp.is_visible_in_tree(),
		"Kai uses its own authored lamp and clasp")
	check(actor.lantern == original_lamp and not original_lamp.is_visible_in_tree()
		and original_lamp.lantern_center == source_lamp_visual and original_lamp.lit == source_lit
		and original_lamp.toggle_time == source_toggle_time,
		"The shared lamp's state continues with only Kai's fixture showing")
	var mobile := RenderingServer.get_rendering_device() != null and RenderingServer.get_current_rendering_method() == &"mobile"
	if mobile:
		check(world.showcase._player_light == point and point.light_energy == point_energy and point.light_color == point_color
			and point.global_position == point_origin,
			"Skin change keeps the same light, color, intensity and overhead position")
		if world.canopy_player_cue.available(world):
			var cue := leather.get_node_or_null("CanopyCue") as MeshInstance3D
			check(cue != null and cue.is_visible_in_tree() and cue.mesh == leather.mesh and cue.skin == leather.skin
				and cue.get_node_or_null(cue.skeleton) == leather.get_node(leather.skeleton),
				"Kai body inherits the canopy cue and follows the same skin pose")
			check(not body.get_node("CanopyCue").is_visible_in_tree()
				and lamp.get_node_or_null("CanopyCue") == null, "The cue draws only the active skin and excludes the lantern")
			var face := kai.find_child("Kai Run | Face and expressions", true, false) as MeshInstance3D
			var face_cue := face.get_node_or_null("CanopyCue") as MeshInstance3D
			var blink := face.find_blend_shape_by_name(&"Blink")
			face.set_blend_shape_value(blink, .6)
			world.sync_canopy_player_cue()
			check(face_cue != null and is_equal_approx(face_cue.get_blend_shape_value(blink), .6),
				"The canopy cue follows the visible face morph")
		await draw(5)
		var material := leather.get_active_material(0) as ShaderMaterial
		check(material != null and material in world.look._direct_actor_materials
			and not material.get_meta("verified_valorie", false) and not material.get_shader_parameter("recovered_self_light"),
			"Kai responds to world light through its own material")
		if material != null:
			world.showcase.set_hour(16.5)
			await draw(4)
			var shoulder: float = world.showcase.player_sun_shoulder_weight()
			check(shoulder > 0. and material.get_shader_parameter("gaf_matte_opening") == true
				and is_equal_approx(float(material.get_shader_parameter("player_sun_shoulder")), shoulder),
				"Kai cloth and skin share Forest's daylight controls")
			check(not material.get_shader_parameter("recovered_roughness")
				and is_zero_approx(float(material.get_shader_parameter("player_sun_specular_normalization"))),
				"Kai skips the calibration specific to Valorie's textures")
			world.showcase.set_hour(22.)
			await draw(18)
		var glass := lamp.get_active_material(0) as ShaderMaterial
		var native_glass := lamp.mesh.surface_get_material(0) as BaseMaterial3D
		check(glass != null and native_glass != null
			and glass.get_shader_parameter("atlas") == native_glass.albedo_texture
			and glass.get_shader_parameter("glow_map") == native_glass.emission_texture
			and float(glass.get_shader_parameter("glow_energy")) > 0.,
			"The shared glow control uses Kai's original material textures")
		if glass != null:
			check(glass.get_shader_parameter("gaf_matte_opening") != true,
				"The material response leaves the authored lantern outside the daylight receiver group")
		world.showcase.set_lantern_overhead(false)
		await draw(4)
		check(point.global_position.distance_to(kai.lantern_position()) < .03
			and point.light_energy == point_energy and point.light_color == point_color,
			"The same light follows the selected fixture in hip mode")
		world.showcase.set_hour(12.)
		var until_hidden := Time.get_ticks_msec() + 1500
		while source_lamp_visual.visible and Time.get_ticks_msec() < until_hidden:
			await draw(1)
		check(not point.visible and not source_lamp_visual.visible and lamp.is_visible_in_tree()
			and is_zero_approx(float(glass.get_shader_parameter("glow_energy"))),
			"The shared daytime curve dims Kai glass while retaining the authored fixture")
		for proxy: MeshInstance3D in world.canopy_player_cue.meshes:
			check(not proxy.is_visible_in_tree(), "The canopy cue keeps the approved Noon bypass")
		world.set_reference_look(false)
		check(leather.get_active_material(0) is BaseMaterial3D, "Baseline still uses the native Kai materials")
		world.set_reference_look(true)
		check(leather.get_active_material(0) is ShaderMaterial, "Combined restores Kai world lighting")
	else:
		check(leather.get_active_material(0) is BaseMaterial3D, "Fallback keeps native lit Kai materials")
	var enabled_before: bool = actor.is_physics_processing()
	actor.scripted_input = true
	actor.requested_direction = Vector2(1., 0.)
	actor.requested_run = true
	for i in 27:
		await physics_frame
	await draw(3)
	check(enabled_before and actor.global_position.distance_to(spawn) > .4 and kai.visible,
		"Selected Kai runs on the same controller")
	actor.requested_run = false
	actor.requested_direction = Vector2.ZERO
	world.showcase._settings._undo_button.pressed.emit()
	check(picker.selected == 0 and body.is_visible_in_tree() and original_lamp.visible and not kai.visible,
		"Settings Undo restores MD2 and its original lantern")
	if mobile:
		for proxy: MeshInstance3D in world.canopy_player_cue.meshes:
			check(not proxy.is_visible_in_tree(), "Restoring MD2 at Noon cannot re-enable the canopy cue")
	picker.select(1)
	picker.item_selected.emit(1)
	check(actor.get_node_or_null("KaiAppearance") == kai and kai.visible and weapon.is_visible_in_tree(),
		"Repeat selection uses the same rig")
	finish(world)

func finish(world: Node) -> void:
	world.free()
	print("WORLD_MAP_SKIN failures=", failures)
	quit(int(not failures.is_empty()))
