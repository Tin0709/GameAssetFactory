extends SceneTree

const Grove := preload("res://scripts/world_map_grove.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func run() -> void:
	var script := Grove as Script
	if script.has_method("small_leaf_gap_mask"):
		test_source_mask(script)
	else:
		check(false, "The runtime can derive small gaps from the source texture")
	var world := (load("res://scenes/WorldMap.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var toggle := world.find_child("SpruceGapCoverageToggle", true, false) as CheckButton
	if "absent" in OS.get_cmdline_user_args():
		check(toggle == null, "Unsupported renderers do not expose this comparison")
	else:
		check(toggle != null and toggle.button_pressed, "F5 enables small spruce leaf gap coverage")
		if toggle != null:
			test_gameplay(world, toggle)
	world.free()
	await process_frame
	print("SPRUCE_GAP_COVERAGE failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func test_source_mask(script: Script) -> void:
	var image := Image.create_empty(9, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var small := [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(2, 1)]
	var large := [Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6)]
	var outside := [Vector2i(0, 5), Vector2i(1, 5), Vector2i(1, 6)]
	for point: Vector2i in small + large + outside:
		image.set_pixelv(point, Color.TRANSPARENT)
	var mask: Image = script.call("small_leaf_gap_mask", image)
	check(mask.get_format() == Image.FORMAT_L8 and mask.get_size() == image.get_size(), "Gap mask uses one byte per source texel")
	for y in image.get_height():
		for x in image.get_width():
			check((mask.get_pixel(x, y).r > 0.) == small.has(Vector2i(x, y)),
				"Only four-connected enclosed gaps of at most four texels qualify")

func test_gameplay(world: Node, toggle: CheckButton) -> void:
	var look: Node = world.look
	var grove: Node = world.grove
	var material: ShaderMaterial = grove._spruce_appearance
	var shadow: Shader = grove._spruce_shadow.shader
	check(look.grove_reveal_coverage_active(), "Native F5 uses the verified 2x coverage path")
	check(material.get_shader_parameter("spruce_gap_coverage") == true, "The default reaches the spruce material")
	var mask: ImageTexture = material.get_shader_parameter("spruce_leaf_gap_mask")
	check(mask != null, "The source-derived mask reaches the spruce material")
	if mask != null:
		var pixels := mask.get_image()
		var count := 0
		for alpha: int in pixels.get_data():
			count += int(alpha > 0)
		check(pixels.get_size() == Vector2i(16, 32) and count == 42, "The verified spruce source gives 42 enclosed gap texels")
		var values: Dictionary[int, bool] = {}
		for rank: int in pixels.get_data():
			if rank > 0:
				values[rank] = true
		check(values.size() == count and values.has(255), "Coverage can fade across individual source texels")
	check(not shadow.code.contains("#define GAF_GROVE_REVEAL_COVERAGE"), "Shadows retain the original alpha test")
	toggle.button_pressed = false
	check(material.get_shader_parameter("spruce_gap_coverage") == false, "The checkbox restores the original spruce coverage")
	toggle.button_pressed = true
	look.set_grove_reveal_coverage(false)
	check(not material.shader.code.contains("#define GAF_GROVE_REVEAL_COVERAGE"), "The effect follows the verified renderer guard")
	look.set_grove_reveal_coverage(true)
	check(material.shader.code.contains("#define GAF_GROVE_REVEAL_COVERAGE")
		and material.get_shader_parameter("spruce_gap_coverage") == true, "Rebuilding the material restores the chosen coverage")
	check(grove._spruce_shadow.shader == shadow, "Comparison leaves the caster shader intact")
	for hours: Vector2 in [Vector2(12., 1.), Vector2(19.5, 0.), Vector2(20.125, 0.), Vector2(22., 1.)]:
		world.showcase.set_hour(hours.x)
		check(material.get_shader_parameter("spruce_gap_coverage_weight") == hours.y,
			"Forest applies the validated coverage amount at %s" % hours.x)
	for hour: float in [19.125, 20.5]:
		world.showcase.set_hour(hour)
		var weight: Variant = material.get_shader_parameter("spruce_gap_coverage_weight")
		check(weight is float and weight > 0. and weight < 1., "Coverage transitions gradually around dusk")
