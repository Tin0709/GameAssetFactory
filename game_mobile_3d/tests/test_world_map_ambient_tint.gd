extends SceneTree

const CONTROL := &"ambient_tint_by_hour"
const FOREST := preload("res://assets/graphics/biomes/forest_reference.tres")
const MEADOW := preload("res://assets/graphics/biomes/meadow.tres")
const MEADOW_SCENE := preload("res://scenes/maps/m2_v1/MeadowBiomeReview.tscn")
const LUMA := Vector3(.2126, .7152, .0722)
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func linear_rgb(color: Color) -> Vector3:
	var linear := color.srgb_to_linear()
	return Vector3(linear.r, linear.g, linear.b)

func check_tint(before: Color, after: Color, label: String) -> void:
	var source := linear_rgb(before)
	var target := linear_rgb(after)
	check(target.z > source.z and target.x < source.x, label + " cools the existing sky tint")
	check(absf(target.dot(LUMA) - source.dot(LUMA)) < 1e-6, label + " preserves linear luminance")

func run() -> void:
	check(FOREST.has_method("tint_ambient"), "Biome resources can tint the existing ambient source")
	if FOREST.has_method("tint_ambient"):
		var base := Color(.68, .73, .81, .6)
		var at_peak: Color = FOREST.call("tint_ambient", 7., base)
		check_tint(base, at_peak, "Forest at 07:00")
		check(is_equal_approx(at_peak.a, base.a), "Ambient tint preserves alpha")
		for hour in [0., 5.1, 10., 12., 16.5, 19.5, 22.]:
			check(FOREST.call("tint_ambient", hour, base) == base, "Forest outside the morning curve is exact at %s" % hour)
		check(FOREST.call("tint_ambient", 7., base, 0.) == base, "A disabled strength is exact")
		check(MEADOW.call("tint_ambient", 7., base) == base, "An unconfigured biome is exact")
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var showcase = world.showcase
	if showcase.private_primary and showcase.atmosphere_review == "combined":
		var env: Environment = world.get_node("WorldEnvironment").environment
		var sun: DirectionalLight3D = world.get_node("Sun")
		var slider := showcase._lighting_sliders.get(CONTROL) as HSlider
		check(slider != null and slider.value == 1., "WorldMap has a default-on live slider")
		if slider != null:
			for cloud: float in [0., 1.]:
				showcase.set_weather(cloud, 0.)
				showcase.set_hour(7.)
				slider.value = 0.
				var base := env.ambient_light_color
				var energy := env.ambient_light_energy
				var key := [sun.light_color, sun.light_energy, sun.rotation]
				slider.value = 1.
				check_tint(base, env.ambient_light_color, "Live Forest, cloud %s" % cloud)
				check(env.ambient_light_energy == energy and key == [sun.light_color, sun.light_energy, sun.rotation],
					"Live tint preserves source strength and direct key")
			for hour: float in [12., 16.5, 19.5, 22.]:
				showcase.set_hour(hour)
				slider.value = 0.
				var original := env.ambient_light_color
				slider.value = 1.
				check(env.ambient_light_color == original, "Live tint preserves the approved phase at %s" % hour)
			var path := "user://test-ambient-tint-%d.cfg" % OS.get_process_id()
			slider.value = .5
			check(showcase.save_lighting_mix(path) == OK, "Preset saves the live strength")
			slider.value = 1.
			check(showcase.load_lighting_mix(path) == OK and slider.value == .5, "Preset restores the saved strength")
			var old := ConfigFile.new()
			if old.load(path) == OK:
				old.set_value("recipe", "version", 205)
				old.erase_section_key("strengths", String(CONTROL))
				check(old.save(path) == OK and showcase.load_lighting_mix(path) == OK and slider.value == 0.,
					"Old presets retain their previous morning palette")
			DirAccess.remove_absolute(path)
	world.free()
	await process_frame
	var meadow = MEADOW_SCENE.instantiate()
	root.add_child(meadow)
	current_scene = meadow
	await process_frame
	if FOREST.has_method("tint_ambient"):
		var env: Environment = meadow.get_node("WorldEnvironment").environment
		meadow.showcase.set_hour(7.)
		var original := env.ambient_light_color
		var profile := MEADOW.duplicate()
		profile.set("ambient_tint_by_hour", FOREST.get("ambient_tint_by_hour"))
		profile.set("ambient_tint_ratio", FOREST.get("ambient_tint_ratio"))
		meadow.biome_controller.set_profile(profile)
		check_tint(original, env.ambient_light_color, "Portable Meadow route with a custom preset")
	meadow.free()
	await process_frame
	print("AMBIENT_TINT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
