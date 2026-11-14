extends SceneTree

const FOREST_SCENE := preload("res://scenes/WorldMap.tscn")
const PORTABLE_SCENE := preload("res://scenes/maps/m2_v1/MeadowBiomeReview.tscn")
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
	check(forest_settings.overcast != null, "Forest needs its own overcast resource")
	check(showcase.has_method("set_weather"), "Forest needs the same weather interface as imported maps")
	if forest_settings.overcast != null and showcase.has_method("set_weather"):
		var sun: DirectionalLight3D = forest.get_node("Sun")
		var env: Environment = forest.get_node("WorldEnvironment").environment
		showcase.set_hour(7.)
		var clear := sun.light_energy
		var clear_tint := env.fog_light_color
		showcase.set_weather(.5, 0.)
		check(not showcase.forest_active() or is_equal_approx(sun.light_energy, clear * lerpf(1., forest_settings.overcast.key_energy_scale, .5)),
			"Forest applies shared sunlight response once")
		if showcase.forest_active():
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
			var attached_compositor := camera.compositor
			check(attached_compositor == opened_compositor, "Adaptive bloom keeps the camera compositor used at Noon")
			check(attached_compositor.compositor_effects.has(graphics._mist.effect) \
				and attached_compositor.compositor_effects.has(graphics._finish_effect)
				and graphics._finish_effect.snapshot().frames > 0,
				"A map opened at noon adds bloom at dusk on the same compositor as the warmed medium")
			check(env.fog_density > 0., "Ordinary materials keep valid native fog while custom receivers substitute the medium")
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
	map.free()
	await process_frame
	print("BIOME_SHARED_CHECKS ", checks, " failures=", failures)
	quit(int(not failures.is_empty()))
