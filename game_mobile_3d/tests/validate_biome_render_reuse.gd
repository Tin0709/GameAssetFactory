extends SceneTree

const FOREST_SCENE := preload("res://scenes/WorldMap.tscn")
const PORTABLE_SCENE := preload("res://scenes/maps/m2_v1/MeadowBiomeReview.tscn")
const MEADOW := preload("res://assets/graphics/biomes/meadow.tres")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, reason: String) -> void:
	checks += 1
	if not condition:
		failures.append(reason)

func run() -> void:
	if not OS.has_feature("editor") or OS.get_environment("GAF_SHOWCASE_PLAYER") == "original":
		push_error("Biome reuse check needs the normal private Forest editor launch.")
		quit(1)
		return
	var forest = FOREST_SCENE.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame
	var showcase = forest.showcase
	var forest_settings = forest.biome_graphics
	check(forest.map_ready and forest_settings.use_forest_reference, "F5 uses Forest preset")
	var boulder = forest.get_node_or_null("PlayableBoulder")
	if RenderingServer.get_rendering_device() != null and RenderingServer.get_current_rendering_method() == "mobile":
		check(boulder != null and boulder.active, "F5 places the authored stone and enables its support")
		if boulder != null:
			check(boulder.roots.size() > 0, "The stone has verified grass roots beneath its surface")
			check(showcase._mist_materials().has(boulder.material), "The stone takes the same spatial mist as terrain")
			var toggle := showcase.panel.find_child("PlayableBoulder", true, false) as CheckButton
			check(toggle != null and toggle.button_pressed, "The settings menu exposes the active stone comparison")
			if toggle != null:
				toggle.button_pressed = false
			check(not boulder.visual.visible and boulder.collider.collision_layer == 0,
				"Stone comparison restores the walkable meadow")
			var before := (forest.player as CharacterBody3D).position
			forest.player.position = Vector3(-19., 3.02, 24.)
			boulder.set_requested(true)
			check(not boulder.active, "Stone waits while the player overlaps its placement")
			forest.player.position = before
			await process_frame
			check(boulder.active, "Stone restores visual and collision once the player moves away")
			showcase.compare_baseline()
			await process_frame
			check(not boulder.active and boulder.requested, "Baseline hides the stone while retaining its setting")
			showcase.compare_baseline()
			await process_frame
			check(boulder.active and showcase._mist_materials().has(boulder.material),
				"Returning from baseline restores the terrain and fog receiver")
	else:
		check(boulder == null, "Compatibility does not load the private stone")
	forest.set_review_view("overview")
	var forest_camera := forest.get_node("Camera3D") as Camera3D
	check(forest_camera.position == Vector3(-8.5, 140., -1.) and forest_camera.size == 150.,
		"The reference overview keeps its approved framing")
	forest.set_review_view("gameplay")
	check(forest_settings.overcast != null, "Forest needs its own overcast resource")
	if RenderingServer.get_rendering_device() != null and RenderingServer.get_current_rendering_method() == "mobile":
		var leaf_material: ShaderMaterial = forest.grove._canopy_appearance
		var leaf_control := showcase._lighting_sliders.get(&"night_leaf_lamp_shoulder") as HSlider
		showcase.set_hour(22.)
		check(leaf_control != null and leaf_control.editable
			and is_equal_approx(float(leaf_material.get_shader_parameter("twilight_leaf_lamp_shoulder")), .30),
			"Fresh Forest Night uses the adjustable leaf response to the player lamp")
		showcase.set_lighting_scale(&"night_leaf_lamp_shoulder", 0.)
		check(is_zero_approx(float(leaf_material.get_shader_parameter("twilight_leaf_lamp_shoulder"))),
			"Zero restores the earlier night leaf response")
		showcase.set_lighting_scale(&"night_leaf_lamp_shoulder", 1.)
		showcase.set_hour(19.5)
		check(is_equal_approx(float(leaf_material.get_shader_parameter("twilight_leaf_lamp_shoulder")), .40),
			"The night adjustment preserves the existing twilight leaf shoulder")
		showcase.set_hour(12.)
		check(is_zero_approx(float(leaf_material.get_shader_parameter("twilight_leaf_lamp_shoulder"))),
			"The leaf shoulder is absent at approved Noon")
		var diffuse_slider := showcase._lighting_sliders.get(&"shadow_diffuse_return") as HSlider
		check(diffuse_slider != null and is_equal_approx(diffuse_slider.value, 1.),
			"The default diffuse shadow return is adjustable")
		var sun_for_shade := forest.get_node("Sun") as DirectionalLight3D
		for time: float in [7., 16.5, 12., 19.5, 22.]:
			showcase.set_hour(time)
			await process_frame
			await RenderingServer.frame_post_draw
			var state: Variant = showcase.get("_shadow_diffuse_state")
			var expected := .06 if time in [7., 16.5] else 0.
			check(state is Vector4 and is_equal_approx(state.w, expected),
				"Diffuse return follows the biome curve at %.1f" % time)
		showcase.set_hour(7.)
		showcase.set_lighting_scale(&"shadow_diffuse_return", 0.)
		await process_frame
		await RenderingServer.frame_post_draw
		var disabled: Variant = showcase.get("_shadow_diffuse_state")
		check(disabled is Vector4 and disabled.is_zero_approx(), "Zero slider removes the added diffuse return")
		showcase.set_lighting_scale(&"shadow_diffuse_return", 1.)
		sun_for_shade.shadow_enabled = false
		await process_frame
		await RenderingServer.frame_post_draw
		disabled = showcase.get("_shadow_diffuse_state")
		check(disabled is Vector4 and disabled.is_zero_approx(), "Disabling sun shadows clears the diffuse return")
		sun_for_shade.shadow_enabled = true
		showcase.set_hour(12.)
		var bark_slider := showcase._lighting_sliders.get(&"bark_irradiance") as HSlider
		check(bark_slider != null and is_equal_approx(bark_slider.value, 1.), "Bark skylight has a live comparison slider")
		for time: float in [12., 16.5, 19.5]:
			showcase.set_hour(time)
			await process_frame
			await RenderingServer.frame_post_draw
			var bark: Variant = forest.grove._spruce_appearance.get_shader_parameter("bark_irradiance")
			check(bark is Vector4 and is_equal_approx(bark.w, .60 if time == 16.5 else 0.),
				"Bark skylight follows the biome phase at %.1f" % time)
		showcase.set_hour(12.)
	check(forest_settings.get("bark_diffuse_return_by_hour") is Curve, "Bark diffuse return uses the biome schedule")
	if showcase.mist != null:
		var bark_return := showcase._lighting_sliders.get(&"bark_diffuse_return") as HSlider
		check(bark_return != null and is_equal_approx(bark_return.value, 1.), "F5 exposes the default bark diffuse return")
		for time: float in [7., 12., 16.5, 22.]:
			showcase.set_hour(time)
			await process_frame
			await RenderingServer.frame_post_draw
			var value: Variant = forest.grove._spruce_appearance.get_shader_parameter("bark_diffuse_return")
			check(value is Vector3 and ((value.length() > .001) == (time in [7., 16.5])),
				"Bark diffuse return reaches the active tree material at %.1f" % time)
		showcase.set_hour(16.5)
		showcase.set_lighting_scale(&"bark_diffuse_return", 0.)
		await process_frame
		await RenderingServer.frame_post_draw
		check(forest.grove._spruce_appearance.get_shader_parameter("bark_diffuse_return") == Vector3.ZERO,
			"Live comparison clears bark light")
		showcase.set_lighting_scale(&"bark_diffuse_return", 1.)
		showcase.set_hour(12.)
	check(forest_settings.get("actor_side_sky_by_hour") is Curve,
		"Valorie side sky gain comes from the biome schedule")
	if showcase.mist != null:
		var side_slider := showcase._lighting_sliders.get(&"actor_side_sky") as HSlider
		check(side_slider != null and is_equal_approx(side_slider.value, 1.), "F5 enables lateral sky on Valorie")
		var side_material: ShaderMaterial
		for m: ShaderMaterial in forest.look._direct_actor_materials:
			if m != null and m.get_meta("verified_valorie", false):
				side_material = m
				break
		check(side_material != null, "Verified Valorie material")
		if side_material != null:
			for time: float in [7., 12., 16.5, 22.]:
				showcase.set_hour(time)
				await process_frame
				await RenderingServer.frame_post_draw
				var side: Variant = side_material.get_shader_parameter("actor_side_sky")
				check(side is float and is_equal_approx(side, 1. if time in [7., 16.5] else 0.),
					"Valorie side sky respects the default phase at %.1f" % time)
			showcase.set_hour(16.5)
			await process_frame
			showcase.set_lighting_scale(&"actor_side_sky", .37)
			check(is_equal_approx(side_material.get_shader_parameter("actor_side_sky"), .37),
				"The live side-light slider reaches Valorie")
			showcase.set_lighting_scale(&"actor_side_sky", 1.)
			showcase.set_hour(12.)
	check(forest_settings.get("projected_opening_recovery_by_hour") is Curve,
		"Forest sunlight opening response comes from the biome preset")
	check(forest_settings.get("alternate_mist_by_hour") is Curve,
		"Forest's low mist has a biome-authored schedule")
	check(forest_settings.get("mist_sky_scatter_by_hour") is Curve,
		"Forest sky in mist is scheduled by the biome")
	if showcase.mist != null:
		var sky_control: HSlider = showcase._lighting_sliders.get(&"mist_sky_scatter")
		check(sky_control != null and sky_control.editable and is_equal_approx(sky_control.value, 1.),
			"F5 exposes and enables sky scattering by default")
		var dusk_control: HSlider = showcase._lighting_sliders.get(&"mist_dusk_sky_scatter")
		check(dusk_control != null and dusk_control.editable and is_equal_approx(dusk_control.value, 1.),
			"F5 exposes an independent twilight sky scattering control")
		for time: float in [7., 12., 16.5, 19.5, 22.]:
			showcase.set_hour(time)
			await process_frame
			await RenderingServer.frame_post_draw
			var gain: float = showcase.mist.effect.snapshot().get("sky_air_gain", -1.)
			var expected: float = {7.: 1.25, 16.5: 1.25, 19.5: 1.8}.get(time, 0.)
			check(is_equal_approx(gain, expected),
				"Shared volume receives the biome sky gain at %.1f" % time)
		showcase.set_hour(16.5)
		showcase.set_lighting_scale(&"mist_sky_scatter", 0.)
		await process_frame
		await RenderingServer.frame_post_draw
		check(is_zero_approx(showcase.mist.effect.snapshot().get("sky_air_gain", -1.)),
			"Live comparison clears the sky source")
		showcase.set_lighting_scale(&"mist_sky_scatter", 1.)
		showcase.set_hour(12.)
	if showcase.mist != null:
		var entry_control: HSlider = showcase._lighting_sliders.get(&"mist_entry_scatter")
		check(entry_control != null and is_equal_approx(entry_control.value, 1.),
			"The main Forest settings expose the default near-entry scatter comparison")
		showcase.set_hour(7.)
		await process_frame
		await RenderingServer.frame_post_draw
		var entry_payload: PackedByteArray = showcase.mist.effect._ground_haze_parameters
		check(is_equal_approx(entry_payload.decode_float(28), 3.8), "Forest sends the dawn scatter gain to the volume")
		showcase.set_lighting_scale(&"mist_entry_scatter", 0.)
		await process_frame
		await RenderingServer.frame_post_draw
		entry_payload = showcase.mist.effect._ground_haze_parameters
		check(is_zero_approx(entry_payload.decode_float(28)), "Live comparison clears just the entry gain")
		showcase.set_lighting_scale(&"mist_entry_scatter", 1.)
		showcase.set_hour(12.)
		await process_frame
		await RenderingServer.frame_post_draw
		entry_payload = showcase.mist.effect._ground_haze_parameters
		check(is_zero_approx(entry_payload.decode_float(28)), "Approved Noon has no entry gain")
		var actor_shade_control: HSlider = showcase._lighting_sliders.get(&"actor_shade_sky")
		check(actor_shade_control != null and is_equal_approx(actor_shade_control.value, 1.),
			"The main settings expose the Valorie canopy sky comparison")
		var actor_receiver: ShaderMaterial
		for material: ShaderMaterial in forest.look._direct_actor_materials:
			if material != null and material.get_meta("verified_valorie", false):
				actor_receiver = material
				break
		check(actor_receiver != null, "Valorie has a verified receiver")
		if actor_receiver != null:
			showcase.set_hour(7.)
			await process_frame
			await RenderingServer.frame_post_draw
			var actor_gain: Variant = actor_receiver.get_shader_parameter("actor_shade_sky")
			check(actor_gain is float and is_equal_approx(actor_gain, .68),
				"Valorie receives dawn canopy sky from the biome")
			showcase.set_lighting_scale(&"actor_shade_sky", 0.)
			actor_gain = actor_receiver.get_shader_parameter("actor_shade_sky")
			check(actor_gain is float and is_zero_approx(actor_gain), "Live comparison clears the extra sky")
			showcase.set_lighting_scale(&"actor_shade_sky", 1.)
			for hour: float in [12., 22.]:
				showcase.set_hour(hour)
				await process_frame
				await RenderingServer.frame_post_draw
				actor_gain = actor_receiver.get_shader_parameter("actor_shade_sky")
				check(actor_gain is float and is_zero_approx(actor_gain), "Noon and night keep their earlier actor sky")
		var wall_sky_control: HSlider = showcase._lighting_sliders.get(&"stone_wall_sky")
		check(wall_sky_control != null and is_equal_approx(wall_sky_control.value, 1.),
			"Main settings expose the default stone-side sky comparison")
		var stone: ShaderMaterial
		for row: Array in forest.look.terrain_materials:
			var material := row[3] as ShaderMaterial
			if material != null and material.get_shader_parameter("ground_grade") == 3:
				stone = material
				break
		check(stone != null, "The main map has a stone transport receiver")
		if stone != null:
			showcase.set_hour(16.5)
			await process_frame
			await RenderingServer.frame_post_draw
			var wall_sky: Variant = stone.get_shader_parameter("stone_wall_sky")
			check(wall_sky is float and is_equal_approx(wall_sky, .75),
				"The afternoon profile reaches the stone diffuse receiver")
			showcase.set_lighting_scale(&"stone_wall_sky", 0.)
			wall_sky = stone.get_shader_parameter("stone_wall_sky")
			check(wall_sky is float and is_zero_approx(wall_sky),
				"The live comparison restores the old stone sky")
			showcase.set_lighting_scale(&"stone_wall_sky", 1.)
			for hour: float in [12., 22.]:
				showcase.set_hour(hour)
				await process_frame
				await RenderingServer.frame_post_draw
				wall_sky = stone.get_shader_parameter("stone_wall_sky")
				check(wall_sky is float and is_zero_approx(wall_sky),
					"The sky addition bypasses protected Noon and night")
		showcase.set_hour(20.25)
		showcase._update_mist()
		var late_region = forest.get("alternate_mist_region")
		check(late_region != null and showcase.mist._local_region == late_region
			and is_equal_approx(showcase.mist._local_gain, .42),
			"Forest uses the new pocket after the daylight region fades out")
		check(showcase.mist._additional_region == forest.night_mist_region,
			"The cliff still uses its own night mist")
		showcase.set_lighting_scale(&"alternate_local_mist", 0.)
		check(is_zero_approx(showcase.mist._local_gain), "The live slider restores the previous mist")
		showcase.set_lighting_scale(&"alternate_local_mist", .42)
		showcase.set_hour(12.)
		showcase._update_mist()
		check(is_zero_approx(showcase.mist._local_gain), "The authored pocket is absent at approved Noon")
		check(showcase._settings._widgets.has("low-mist") and showcase._lighting_sliders.has(&"alternate_local_mist"),
			"The settings menu exposes both the quick hour and the live comparison")
	if showcase.projected_sun.available():
		showcase.set_lighting_scale(&"projected_sun", .40)
		showcase.set_lighting_scale(&"projected_sun_openings", .60)
		for hour: float in [9.5, 14.25]:
			showcase.set_hour(hour)
			check(is_equal_approx(showcase.projected_sun._opening_recovery, .30),
				"Protected daytime shoulders keep projected openings visible")
		showcase.set_hour(12.)
		check(is_zero_approx(showcase.projected_sun._opening_recovery), "Noon has no extra opening recovery")
		showcase.set_hour(19.5)
		check(is_zero_approx(showcase.projected_sun._opening_recovery), "Twilight has no extra sunlight opening")
		showcase.set_hour(9.5)
		showcase.set_weather(1., 0.)
		check(is_equal_approx(showcase.projected_sun._opening_recovery, .15),
			"Overcast keeps only the original opening response")
		showcase.set_weather(0., 0.)
		showcase.set_lighting_scale(&"projected_sun", 0.)
		check(is_zero_approx(showcase.projected_sun._opening_recovery), "Opening recovery needs the map's valid projection")
		showcase.set_lighting_scale(&"projected_sun", .40)
	check(showcase.has_method("set_weather"), "Forest needs the same weather interface as imported maps")
	if forest_settings.overcast != null and showcase.has_method("set_weather"):
		var sun: DirectionalLight3D = forest.get_node("Sun")
		var env: Environment = forest.get_node("WorldEnvironment").environment
		showcase.set_hour(7.)
		var clear := sun.light_energy
		var clear_tint := env.fog_light_color
		showcase.set_weather(.5, 0.)
		check(is_equal_approx(sun.light_energy, clear * lerpf(1., forest_settings.overcast.key_energy_scale, .5)),
			"Forest applies shared sunlight response once")
		check(env.fog_light_color.is_equal_approx(clear_tint.lerp(forest_settings.overcast.fog_color, .5)),
			"Forest applies shared fog color response")
		for index in 3:
			await process_frame
		check(is_equal_approx(sun.light_energy, clear * lerpf(1., forest_settings.overcast.key_energy_scale, .5)),
			"Weather does not accumulate each refresh")
		check(is_equal_approx(showcase.hour, 7.), "Weather keeps the hour independent")
		showcase.set_weather(0., 0.)
		check(is_equal_approx(sun.light_energy, clear) and env.fog_light_color.is_equal_approx(clear_tint),
			"Clear restores the untouched lighting and fog")
		showcase.set_hour(12.)
		var noon := sun.light_energy
		showcase.set_weather(1., 0.)
		check(is_equal_approx(sun.light_energy, noon * forest_settings.overcast.key_energy_scale),
			"Noon can use overcast on both rendering paths")
		showcase.set_weather(0., 0.)
		check(is_equal_approx(sun.light_energy, noon), "Clearing weather restores the Noon anchor")
	forest.free()
	await process_frame
	var map = PORTABLE_SCENE.instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	var graphics = map.biome_controller
	var mobile := RenderingServer.get_rendering_device() != null and RenderingServer.get_current_rendering_method() == "mobile"
	var camera := map.get_node("Camera3D") as Camera3D
	if mobile:
		for index in 8:
			await process_frame
			await RenderingServer.frame_post_draw
	var opened_compositor := camera.compositor
	check(map.map_ready and map.geometry.cells.size() == 5632 and graphics != null,
		"Second map uses imported geometry and portable controller")
	check(map.get_node_or_null("PlayableBoulder") == null, "A second map keeps its own placement data")
	var gameplay_size := camera.size
	map.set_review_view("overview")
	var low: Array = map.runtime.border.min
	var high: Array = map.runtime.border.max
	check(Vector2(camera.position.x, camera.position.z).is_equal_approx(
		Vector2((low[0] + high[0]) * .5, (low[2] + high[2]) * .5)),
		"An imported overview centers on its boundary")
	var overview_frame := root.get_visible_rect()
	for x: float in [low[0], high[0]]:
		for z: float in [low[2], high[2]]:
			check(overview_frame.has_point(camera.unproject_position(Vector3(x, high[1], z))),
				"Every imported boundary corner fits inside the overview")
	var aspect := overview_frame.size.aspect()
	var tight_fit := maxf(50., 50. / aspect) if camera.keep_aspect == Camera3D.KEEP_HEIGHT else maxf(50., 50. * aspect)
	check(camera.size >= tight_fit and camera.size < tight_fit * 1.25, "The 50 m map fills its overview")
	map.set_review_view("gameplay")
	check(is_equal_approx(camera.size, gameplay_size), "Leaving the overview restores play zoom")
	check(not map.biome_graphics.use_forest_reference and not map.showcase.projected_sun.available(),
		"An imported map never binds the private Forest projection")
	if graphics != null:
		var sun: DirectionalLight3D = map.get_node("Sun")
		var env: Environment = map.get_node("WorldEnvironment").environment
		map.showcase.set_hour(7.)
		var clear := sun.light_energy
		var clear_tint := env.fog_light_color
		graphics.set_weather(.5, 0.)
		check(is_equal_approx(sun.light_energy, clear * lerpf(1., map.biome_graphics.overcast.key_energy_scale, .5)),
			"Imported map applies the same weather formula")
		check(env.fog_light_color.is_equal_approx(clear_tint.lerp(map.biome_graphics.overcast.fog_color, .5)),
			"Imported map applies the same fog color formula")
		graphics.set_weather(0., 0.)
		check(is_equal_approx(sun.light_energy, clear) and env.fog_light_color.is_equal_approx(clear_tint),
			"Imported map can also restore clear")
		if mobile:
			for index in 30:
				await process_frame
				await RenderingServer.frame_post_draw
			check(graphics._mist.visible and graphics._mist.effect.snapshot().ready and graphics._mist.failure().is_empty(),
				"Spatial fog runs on the second map")
			var selected_profile = map.biome_graphics
			check(is_equal_approx(graphics._mist_sample.scatter_energy, .483),
				"Woodland uses its authored 07:00 scattering on opening the imported scene")
			var inherited_profile = selected_profile.duplicate()
			inherited_profile.set("mist_scatter_color_by_hour", null)
			inherited_profile.set("mist_scatter_energy_by_hour", null)
			graphics.set_profile(inherited_profile)
			await process_frame
			await RenderingServer.frame_post_draw
			var chromatic_profile = inherited_profile.duplicate()
			var scatter_color := Gradient.new()
			scatter_color.set_color(0, Color(.45, .7, 1.))
			scatter_color.set_color(1, Color(.45, .7, 1.))
			var scatter_energy := Curve.new()
			scatter_energy.max_value = 2.
			scatter_energy.add_point(Vector2(7. / 24., 1.5))
			scatter_energy.add_point(Vector2(.5, 1.))
			chromatic_profile.set("mist_scatter_color_by_hour", scatter_color)
			chromatic_profile.set("mist_scatter_energy_by_hour", scatter_energy)
			var entry_gain := Curve.new()
			entry_gain.max_value = 4.
			entry_gain.add_point(Vector2(7. / 24., 2.))
			entry_gain.add_point(Vector2(.5, 0.))
			chromatic_profile.set("mist_entry_scatter_by_hour", entry_gain)
			var old_near: Vector3 = graphics._mist_sample.near_layer
			var old_density: float = graphics._mist_sample.volume_density
			var old_payload: PackedByteArray = graphics._mist.effect._parameters
			graphics.set_profile(chromatic_profile)
			await process_frame
			await RenderingServer.frame_post_draw
			var payload: PackedByteArray = graphics._mist.effect._parameters
			var rgb := Vector3(payload.decode_float(112), payload.decode_float(116), payload.decode_float(120))
			var old_rgb := Vector3(old_payload.decode_float(112), old_payload.decode_float(116), old_payload.decode_float(120))
			var luma := Vector3(.2126, .7152, .0722)
			check(rgb.z > rgb.y and rgb.y > rgb.x and not rgb.is_equal_approx(old_rgb)
				and is_equal_approx(rgb.dot(luma), old_rgb.dot(luma)),
				"A portable preset independently tints spatial scattering at the original source luminance")
			check(is_equal_approx(payload.decode_float(124), .63)
				and old_near.is_equal_approx(graphics._mist_sample.near_layer)
				and is_equal_approx(old_density, graphics._mist_sample.volume_density)
				and env.fog_light_color.is_equal_approx(clear_tint),
				"The 07:00 scattering curve reaches the shader without altering extinction or depth fog")
			var entry_payload: PackedByteArray = graphics._mist.effect._ground_haze_parameters
			check(is_equal_approx(entry_payload.decode_float(28), 2.),
				"An imported biome authors the same entry response without Forest or local haze assets")
			graphics.set_weather(1., 0.)
			var cloud_source: Vector3 = graphics._mist_sample.get("linear_scatter_rgb", Vector3.ZERO)
			var cloud_tint: Color = selected_profile.overcast.fog_color.srgb_to_linear()
			check(cloud_source.normalized().is_equal_approx(Vector3(cloud_tint.r, cloud_tint.g, cloud_tint.b).normalized())
				and is_equal_approx(cloud_source.dot(luma), rgb.dot(luma)),
				"Overcast retints the authored scattering at constant luminance")
			graphics.set_weather(0., 0.)
			map.showcase.set_hour(12.)
			await process_frame
			await RenderingServer.frame_post_draw
			payload = graphics._mist.effect._parameters
			check(is_equal_approx(payload.decode_float(124), .42), "Noon uses the authored neutral energy multiplier")
			graphics.set_profile(inherited_profile)
			map.showcase.set_hour(7.)
			await process_frame
			await RenderingServer.frame_post_draw
			check(not graphics._mist_sample.has("linear_scatter_rgb"), "Changing profile clears the optional tint")
			entry_payload = graphics._mist.effect._ground_haze_parameters
			check(is_zero_approx(entry_payload.decode_float(28)), "Switching biome clears the prior entry response")
			var alternate_profile = selected_profile.duplicate()
			var alternate_track := Curve.new()
			alternate_track.add_point(Vector2(0., .8))
			alternate_track.add_point(Vector2(1., .8))
			var primary_track := Curve.new()
			primary_track.add_point(Vector2(0., 1.))
			primary_track.add_point(Vector2(.5, 0.))
			primary_track.add_point(Vector2(1., 1.))
			alternate_profile.local_mist_by_hour = primary_track
			alternate_profile.alternate_mist_by_hour = alternate_track
			map.alternate_mist_region = map.local_mist_region.duplicate()
			graphics.set_profile(alternate_profile)
			check(graphics._mist._local_region == map.local_mist_region,
				"A live primary region keeps its slot on an imported map")
			map.showcase.set_hour(12.)
			check(graphics._mist._local_region == map.alternate_mist_region and graphics._mist._local_gain > 0.,
				"The alternate curve can fill the same slot on the imported map")
			graphics.set_profile(selected_profile)
			map.showcase.set_hour(7.)
			var attached_compositor := camera.compositor
			check(attached_compositor == opened_compositor, "Adaptive bloom keeps the camera compositor used at Noon")
			check(attached_compositor.compositor_effects.has(graphics._mist.effect) \
				and attached_compositor.compositor_effects.has(graphics._finish_effect)
				and graphics._finish_effect.snapshot().frames > 0,
				"A map opened at noon adds bloom at dusk on the same compositor as the warmed medium")
			var edge_slider := map.find_child("DisplayEdgeStrength",true,false) as HSlider
			check(edge_slider != null and is_equal_approx(edge_slider.value,.60),
				"Woodland defaults to a moderate portable edge strength")
			for index in 6:
				await process_frame
				await RenderingServer.frame_post_draw
			var edges: Dictionary = graphics._finish_effect.snapshot()
			check(edges.get("scene_edges_active",false), "Portable edge pass runs after bounded exposure and before engine grading")
			map.showcase.set_lighting_scale(&"display_edge_strength",0.)
			for index in 6:
				await process_frame
				await RenderingServer.frame_post_draw
			var original: Dictionary = graphics._finish_effect.snapshot()
			check(not original.get("scene_edges_active",false) and original.bytes == edges.bytes,
				"Turning off portable edges keeps the same scratch memory budget and only removes the filter")
			map.showcase.set_lighting_scale(&"display_edge_strength",.60)
			check(env.fog_density > 0., "Ordinary materials keep valid native fog while custom receivers substitute the medium")
			var full_bytes: int = graphics._mist.effect.snapshot().bytes
			graphics.set_quality(1)
			for index in 8:
				await process_frame
				await RenderingServer.frame_post_draw
			var balanced_bytes: int = graphics._mist.effect.snapshot().bytes
			check(graphics._mist.visible and balanced_bytes > 0 and balanced_bytes < full_bytes,
				"Changing from Full to Balanced rebuilds a smaller mist grid")
			check(not graphics._finish_effect.enabled, "Balanced skips adaptive bloom")
			check(edge_slider != null and not edge_slider.editable and not graphics._finish_effect.snapshot().get("scene_edges_active",false),
				"Balanced releases the edge filter with the adaptive finish")
			graphics.set_quality(2)
			map.showcase.set_hour(19.5)
			for index in 8:
				await process_frame
				await RenderingServer.frame_post_draw
			check(graphics._mist.effect.snapshot().bytes == full_bytes and graphics._finish_effect.enabled,
				"Switching back to Full restores the larger grid and adaptive bloom")
			check(not graphics._mist_sample.get("ground_haze", PackedFloat32Array()).is_empty(),
				"Woodland twilight reaches the shared mist renderer")
			map.showcase.set_hour(12.)
			check(graphics._mist_sample.get("ground_haze", PackedFloat32Array()).is_empty(),
				"Returning to Noon clears twilight parameters")
			map.showcase.set_hour(19.5)
			var woodland = map.biome_graphics
			for index in 8:
				await process_frame
				await RenderingServer.frame_post_draw
			check(graphics._mist.effect.snapshot().bytes > 0 and graphics._finish_effect.snapshot().bytes > 0,
				"Woodland allocates both effects before comparing biomes")
			graphics.set_profile(MEADOW)
			check(not graphics._mist.visible and graphics._mist_sample.is_empty(),
				"Switching preset cannot leave the previous medium active")
			for index in 8:
				await process_frame
				await RenderingServer.frame_post_draw
			check(graphics._mist.effect.snapshot().bytes == 0,
				"Meadow releases the unused spatial mist grid even at Full quality")
			check(graphics._finish_effect.snapshot().bytes == 0,
				"Meadow releases the unused adaptive bloom textures even at Full quality")
			check(env.fog_density > 0. and env.glow_enabled and is_equal_approx(map.showcase.hour, 19.5),
				"Meadow keeps built-in fog and glow and the current time")
			graphics.set_profile(woodland)
			for index in 8:
				await process_frame
				await RenderingServer.frame_post_draw
			check(graphics._mist.effect.snapshot().ready and graphics._finish_effect.snapshot().bytes > 0,
				"Returning to Woodland rebuilds both effects on the existing camera")
			graphics.set_quality(0)
			await process_frame
			await RenderingServer.frame_post_draw
			check(not graphics._mist.visible and not graphics._finish_effect.enabled and env.fog_density > 0.,
				"Quality fallback uses native depth fog and skips the adaptive effect")
			graphics.set_quality(2)
			for index in 15:
				await process_frame
				await RenderingServer.frame_post_draw
			map.set_review_view("overview")
			await process_frame
			await RenderingServer.frame_post_draw
			check(not graphics._mist.visible and env.fog_density > 0.,
				"Changing camera restores native depth fog in overview")
		else:
			check(graphics._mist == null and graphics._finish_effect == null and env.fog_density > 0.,
				"Compatibility renderer uses depth fog without compositor allocations")
	map.free()
	await process_frame
	print("BIOME_SHARED_CHECKS ", checks, " failures=", failures)
	quit(int(not failures.is_empty()))
