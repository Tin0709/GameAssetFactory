extends SceneTree

const MAP := preload("res://scenes/maps/m2_v1/MeadowBiomeReview.tscn")
const MEADOW := preload("res://assets/graphics/biomes/meadow.tres")
const PROFILE := preload("res://scripts/biome_graphics_profile.gd")
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
	check(not world.showcase.forest_active() and world.grove == null, "No Forest route on the portable map")
	check(profile.day_night != null and is_equal_approx(graphics.weather_weight, .25),
		"Woodland profile must load with its own day/night colors and starting weather")
	if profile.day_night == null:
		finish(world)
		return
	graphics.set_weather(0., 0.)
	world.showcase.set_hour(12.)
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
	graphics.set_weather(1., .2)
	graphics.set_process(false)
	graphics._process(.1)
	check(is_equal_approx(graphics.weather_weight, .5), "Overcast blends smoothly and keeps time independent")
	check(light.light_color.is_equal_approx(morning.lerp(profile.overcast.key_color, .5)), "Weather blends over biome sun")
	check(env.fog_light_color.is_equal_approx(morning_fog.lerp(profile.overcast.fog_color, .5)), "Weather blends over biome fog")
	graphics.set_weather(0., 0.)
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
	check(not light.light_color.is_equal_approx(morning), "Another profile on the same map resolves different lighting")
	check(is_equal_approx(world.showcase.hour, 7.) and MEADOW.day_night == null, "Switch keeps current hour and supports older presets")
	graphics.set_profile(profile)
	check(light.light_color.is_equal_approx(morning), "Switching back restores color without editing the map")
	world.set_reference_look(false)
	world.set_reference_look(true)
	env = world.get_node("WorldEnvironment").environment
	check(env.fog_light_color.is_equal_approx(morning_fog), "Baseline toggle restores biome values")
	graphics.set_quality(0)
	check(env.fog_light_color.is_equal_approx(morning_fog), "Mobile quality fallback retains biome tint")
	check(world.map_ready and world.player.is_physics_processing(), "Gameplay controller remains active")
	finish(world)

func finish(world: Node = null) -> void:
	if world != null:
		world.free()
	print("BIOME_DAY_WEATHER failures=", failures)
	quit(int(not failures.is_empty()))
