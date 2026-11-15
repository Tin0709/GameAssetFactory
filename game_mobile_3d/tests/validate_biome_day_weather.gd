extends SceneTree

const MAP := preload("res://scenes/maps/m2_v1/MeadowBiomeReview.tscn")
const MEADOW := preload("res://assets/graphics/biomes/meadow.tres")
const PROFILE := preload("res://scripts/biome_graphics_profile.gd")
const FOREST := preload("res://assets/graphics/biomes/forest_reference.tres")
var failures: Array[String] = []

func _initialize() -> void:
	verify.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func verify() -> void:
	check("day_night" in PROFILE.new(), "Biome must accept a day/night resource")
	check("start_overcast" in PROFILE.new(), "Starting weather must be a biome setting")
	if not failures.is_empty():
		finish()
		return
	check(FOREST.get("ground_haze") != null and FOREST.get("twilight_ground_haze") != null,
		"Forest authors both low-air envelopes in its biome preset")
	var world = MAP.instantiate()
	var profile = world.biome_graphics.duplicate()
	profile.start_overcast = .25
	world.biome_graphics = profile
	root.add_child(world)
	current_scene = world
	await process_frame
	var graphics = world.biome_controller
	var light: DirectionalLight3D = world.get_node("Sun")
	var env: Environment = world.get_node("WorldEnvironment").environment
	check(world.map_ready and world.geometry.cells.size() == 5632, "Load actual second Litematica map")
	check(not world.showcase.forest_active() and world.grove == null and world.showcase.forest.phases.is_empty(),
		"Portable map skips even reading the private Forest atmosphere")
	check(profile.get("twilight_ground_haze") != null,
		"Woodland profile loads its own twilight envelope")
	if profile.has_method("sample_ground_haze"):
		var noon_haze: PackedFloat32Array = profile.sample_ground_haze(12., 20., 3.)
		var twilight_haze: PackedFloat32Array = profile.sample_ground_haze(19.5, 20., 3.)
		check(noon_haze.is_empty() and twilight_haze.size() == 8 and twilight_haze[4] > 0.,
			"Woodland only publishes low-air scattering at twilight")
		check(profile.sample_ground_haze(19.5, 20., 3., 1., 0.).is_empty()
			and MEADOW.sample_ground_haze(19.5, 20., 3.).is_empty(),
			"Layer controls and Meadow leave the shared payload neutral")
		if twilight_haze.size() == 8:
			var moved: PackedFloat32Array = profile.sample_ground_haze(19.5, 24., 10.)
			check(is_equal_approx(moved[0] - twilight_haze[0], 4.) and is_equal_approx(moved[2] - twilight_haze[2], 7.),
				"Moving the subject or changing map elevation moves the depth or height envelope")
	else:
		check(false, "Both maps need the same low-air sampling function")
	check(profile.day_night != null and is_equal_approx(graphics.weather_weight, .25),
		"Woodland profile must load with its own day/night colors and starting weather")
	var settings = world.showcase._settings
	var preset := settings._widgets.get("biome-preset") as OptionButton
	var quality := settings._widgets.get("biome-quality") as OptionButton
	check(preset != null and quality != null, "Imported maps expose biome and quality in the mouse settings menu")
	if preset != null and quality != null:
		var map_hud := world.get_node("HUD") as CanvasLayer
		var was_visible := map_hud.visible
		var hud_key := InputEventKey.new()
		hud_key.physical_keycode = KEY_L
		hud_key.pressed = true
		world._input(hud_key)
		check(map_hud.visible != was_visible, "L still toggles the HUD on an imported map")
		world._input(hud_key)
		map_hud.show()
		settings.gear.pressed.emit()
		check(settings.panel.visible and preset.is_visible_in_tree() and quality.is_visible_in_tree(),
			"Settings opens both selections through the gear button")
		var start_position: Vector3 = world.player.position
		var start_hour: float = world.showcase.hour
		preset.get_popup().about_to_popup.emit()
		preset.select(1)
		preset.item_selected.emit(1)
		check(graphics._profile == MEADOW and is_equal_approx(world.showcase.hour, start_hour)
			and is_equal_approx(graphics.weather_weight, .25) and world.player.position == start_position,
			"Mouse-selected biome keeps hour, weather and the same player")
		settings._undo_button.pressed.emit()
		check(graphics._profile == profile and preset.selected == 0, "Undo restores the previous biome")
		quality.get_popup().about_to_popup.emit()
		quality.select(0)
		quality.item_selected.emit(0)
		check(graphics.quality == 0, "Mouse-selected quality applies immediately")
		settings._undo_button.pressed.emit()
		check(graphics.quality == 2 and quality.selected == 2, "Undo restores the previous quality")
		settings.set_open(false)
		var shortcut := InputEventKey.new()
		shortcut.pressed = true
		shortcut.physical_keycode = KEY_F8
		world._input(shortcut)
		check(preset.selected == 1 and graphics._profile == MEADOW, "F8 also updates the displayed selection")
		world._input(shortcut)
		shortcut.physical_keycode = KEY_F7
		shortcut.shift_pressed = true
		world._input(shortcut)
		check(quality.selected == 1 and graphics.quality == 1, "Shift+F7 updates the displayed quality")
		graphics.set_quality(2)
		map_hud.visible = was_visible
	if profile.day_night == null:
		finish(world)
		return
	profile.set("shadow_blur", 2.1)
	profile.set("shadow_opacity", .66)
	profile.set("fog_depth_curve", 2.2)
	profile.set("fog_light_energy", .81)
	graphics.set_weather(0., 0.)
	world.showcase.set_hour(12.)
	check(is_equal_approx(light.shadow_blur, 2.1) and is_equal_approx(light.shadow_opacity, .66),
		"Directional shadow softness and opacity come from the selected biome")
	check(is_equal_approx(env.fog_depth_curve, 2.2) and is_equal_approx(env.fog_light_energy, .81),
		"Depth fog shape and lighting come from the selected biome")
	var key_track: Curve = profile.key_energy_by_hour
	var fog_track: Curve = profile.fog_density_by_hour
	profile.key_energy_by_hour = null
	profile.fog_density_by_hour = null
	graphics.refresh()
	var key_without_track := light.light_energy
	var fog_without_track := env.fog_density
	profile.key_energy_by_hour = Curve.new()
	profile.fog_density_by_hour = Curve.new()
	graphics.refresh()
	check(is_equal_approx(light.light_energy, key_without_track), "Empty sun energy track uses the inherited energy")
	check(is_equal_approx(env.fog_density, fog_without_track), "Empty fog density track uses the inherited density")
	profile.key_energy_by_hour = key_track
	profile.fog_density_by_hour = fog_track
	graphics.refresh()
	for code in [KEY_U, KEY_P]:
		var event := InputEventKey.new()
		event.pressed = true
		event.physical_keycode = code
		world._unhandled_input(event)
	check(env.adjustment_color_correction == profile.color_correction, "Legacy grading shortcut cannot override the biome")
	check(is_equal_approx(env.fog_depth_curve, 2.2), "Legacy fog shortcut cannot override the biome")
	world.look.refresh_directional_shadow_blur(light)
	check(is_equal_approx(light.shadow_blur, 2.1), "Shadow refresh retains the active biome radius")
	check(light.light_color.is_equal_approx(profile.noon_sun_color), "Authored Noon remains unchanged")
	check(env.fog_light_color.is_equal_approx(profile.noon_fog_color), "Noon fog retains its anchor")
	world.showcase.set_hour(7.)
	var morning := light.light_color
	var morning_fog := env.fog_light_color
	var morning_fill := env.ambient_light_color
	var morning_sky := env.background_color
	check(morning.is_equal_approx(profile.day_night.sun_color.sample(7. / 24.)), "Sun phase comes from the biome")
	check(morning_fog.is_equal_approx(profile.day_night.fog_color.sample(7. / 24.)), "Fog phase comes from the biome")
	check(morning_fill.is_equal_approx(profile.day_night.ambient_color.sample(7. / 24.)), "Ambient phase comes from the biome")
	check(morning_sky.is_equal_approx(profile.day_night.sky_color.sample(7. / 24.)), "Sky phase comes from the biome")
	world.showcase.set_weather(1., .2)
	graphics.set_process(false)
	graphics._process(.1)
	check(is_equal_approx(graphics.weather_weight, .5), "Overcast blends smoothly and keeps time independent")
	check(light.light_color.is_equal_approx(morning.lerp(profile.overcast.key_color, .5)), "Weather blends over biome sun")
	check(env.fog_light_color.is_equal_approx(morning_fog.lerp(profile.overcast.fog_color, .5)), "Weather blends over biome fog")
	world.showcase.set_weather(0., 0.)
	check(morning.is_equal_approx(light.light_color) and morning_fog.is_equal_approx(env.fog_light_color), "Clear restores authored phase")
	profile.day_night = profile.day_night.duplicate()
	var angle_track := Curve.new()
	angle_track.min_value = -90.
	angle_track.max_value = 90.
	angle_track.add_point(Vector2(7. / 24., -24.))
	var exposure_track := Curve.new()
	exposure_track.max_value = 2.
	exposure_track.add_point(Vector2(7. / 24., .88))
	profile.day_night.set("sun_pitch_degrees", angle_track)
	profile.day_night.set("exposure", exposure_track)
	graphics.refresh()
	check(is_equal_approx(light.rotation_degrees.x, -24.), "Biome can override the phase sun elevation")
	check(is_equal_approx(env.tonemap_exposure, .88), "Biome can override the phase exposure")
	world.showcase.set_hour(9.5)
	check(light.light_color.is_equal_approx(morning.lerp(profile.noon_sun_color, .5)),
		"Morning and Noon colors blend continuously between authored keys")
	world.showcase.set_hour(23.999)
	var before_midnight := env.fog_light_color
	world.showcase.set_hour(0.)
	check(before_midnight.is_equal_approx(env.fog_light_color) or (Vector3(before_midnight.r,before_midnight.g,before_midnight.b) - Vector3(env.fog_light_color.r,env.fog_light_color.g,env.fog_light_color.b)).length() < .001, "No color discontinuity at midnight")
	world.showcase.set_hour(7.)
	graphics.set_profile(MEADOW)
	check(is_equal_approx(light.shadow_blur, 1.25) and is_equal_approx(light.shadow_opacity, .782),
		"Switching biome restores legacy shadow defaults")
	check(is_equal_approx(env.fog_depth_curve, 1.7) and is_equal_approx(env.fog_light_energy, .75),
		"Switching biome restores legacy fog defaults")
	check(not light.light_color.is_equal_approx(morning), "Another profile on the same map resolves different lighting")
	check(is_equal_approx(world.showcase.hour, 7.) and MEADOW.day_night == null, "Switch keeps current hour and supports older presets")
	graphics.set_profile(profile)
	check(light.light_color.is_equal_approx(morning), "Switching back restores color without editing the map")
	world.set_reference_look(false)
	env = world.get_node("WorldEnvironment").environment
	check(is_equal_approx(light.shadow_blur, 1.1) and not is_equal_approx(env.fog_depth_curve, 2.2),
		"Baseline retains its own sun and fog")
	world.set_reference_look(true)
	env = world.get_node("WorldEnvironment").environment
	check(env.fog_light_color.is_equal_approx(morning_fog), "Baseline toggle restores biome values")
	graphics.set_quality(0)
	check(env.fog_light_color.is_equal_approx(morning_fog), "Mobile quality fallback retains biome tint")
	check(is_equal_approx(env.fog_depth_curve, 2.2) and is_equal_approx(env.fog_light_energy, .81),
		"Essential fallback keeps authored fog shape and lighting")
	check(is_equal_approx(light.shadow_blur, 2.1) and is_equal_approx(light.shadow_opacity, .66),
		"Baseline restore reapplies the same biome shadows")
	check(world.map_ready and world.player.is_physics_processing(), "Gameplay controller remains active")
	world.free()
	await process_frame

	world = MAP.instantiate()
	world.set("biome_start_hour", 19.5)
	world.set("biome_start_overcast", .65)
	world.set("biome_atmosphere_base_y", 6.)
	root.add_child(world)
	current_scene = world
	await process_frame
	graphics = world.biome_controller
	check(is_equal_approx(world.showcase.hour, 19.5) and is_equal_approx(graphics.weather_weight, .65),
		"Imported map can choose first hour and weather without editing either biome resource")
	check(is_equal_approx(world.biome_graphics.start_hour, 12.) and is_zero_approx(world.biome_graphics.start_overcast),
		"Map overrides never mutate the shared preset")
	graphics.set_profile(MEADOW)
	check(is_equal_approx(world.showcase.hour, 19.5) and is_equal_approx(graphics.weather_weight, .65),
		"Switching biome does not reset map overrides into the running clock or weather")
	graphics.set_profile(world.biome_graphics)
	if RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null:
		var sample: Dictionary = graphics._mist_sample
		var near_layer: Vector3 = sample.get("near_layer", Vector3.ZERO)
		var haze: PackedFloat32Array = sample.get("ground_haze", PackedFloat32Array())
		check(is_equal_approx(near_layer.z, 6.) and is_equal_approx(graphics._mist._base, 6.)
			and haze.size() == 8 and is_equal_approx(haze[2], 6.4),
			"Near transmission and twilight scattering use the same map-authored height")
	finish(world)

func finish(world: Node = null) -> void:
	if world != null:
		world.free()
	print("BIOME_DAY_WEATHER failures=", failures)
	quit(int(not failures.is_empty()))
