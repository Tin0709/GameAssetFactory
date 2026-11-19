extends SceneTree

const EFFECT := &"ground_shadow_fill_reduction"
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func run() -> void:
	var world := (load("res://scenes/WorldMap.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var review: Node = world.showcase
	var slider := review._lighting_sliders.get(EFFECT) as HSlider
	if "absent" in OS.get_cmdline_user_args():
		check(slider == null or not slider.editable, "Unsupported rendering paths keep this control inactive")
	else:
		check(slider != null and slider.editable and slider.value == 1.0, "WorldMap enables the Forest shade preset by default")
		if slider != null:
			test_phases(world, review, slider)
			test_recipe(review, slider)
	world.free()
	await process_frame
	print("GROUND_SHADOW_FILL failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func test_phases(world: Node, review: Node, slider: HSlider) -> void:
	for hour: float in [7., 12., 16.5, 19.5, 22.]:
		review.set_hour(hour)
		review._sync_point_camera()
		var expected := Vector2(.25, .45) if hour in [7., 16.5] else Vector2.ZERO
		check(review._ground_shadow_fill_reduction.is_equal_approx(expected),
			"Authored phase preserves the existing pose and light at %s" % hour)
	review.set_hour(7.)
	var sun := world.get_node("Sun") as DirectionalLight3D
	var before := Vector2(sun.light_energy, sun.shadow_opacity)
	slider.value = .5
	review._sync_point_camera()
	check(review._ground_shadow_fill_reduction.is_equal_approx(Vector2(.125, .225)), "The live slider scales the biome's two floor responses")
	check(Vector2(sun.light_energy, sun.shadow_opacity) == before, "The slider does not change real lighting or shadow opacity")
	slider.value = 0.0
	review._sync_point_camera()
	check(review._ground_shadow_fill_reduction == Vector2.ZERO, "Zero reproduces the old fill")

func test_recipe(review: Node, slider: HSlider) -> void:
	var path := "user://forest_ground_shade_%s.cfg" % OS.get_process_id()
	slider.value = .45
	check(review.save_lighting_mix(path) == OK, "The recipe saves")
	slider.value = 0.0
	check(review.load_lighting_mix(path) == OK and is_equal_approx(slider.value, .45),
		"The recipe restores the user's ground shadow fill setting")
	var older := ConfigFile.new()
	check(older.load(path) == OK, "The new recipe can be read")
	older.set_value("recipe", "version", 208)
	older.erase_section_key("strengths", String(EFFECT))
	check(older.save(path) == OK and review.load_lighting_mix(path) == OK and slider.value == 0.0,
		"An older recipe keeps its original appearance")
	DirAccess.remove_absolute(path)
