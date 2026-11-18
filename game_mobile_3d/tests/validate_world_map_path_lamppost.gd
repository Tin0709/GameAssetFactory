extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func run() -> void:
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	if world.is_device_review():
		await verify_device_review(world)
		print("DEVICE_PATH_LAMPPOST failures=", failures)
		quit(int(not failures.is_empty()))
		return
	var review = world.showcase
	var lamp = review.get("path_lamppost")
	var mobile := RenderingServer.get_current_rendering_method() == "mobile" and RenderingServer.get_rendering_device() != null
	check(lamp != null, "F5 owns an authored ForestA1 path lamp")
	if lamp != null:
		await physics_frame
		check((lamp.fixture != null) == mobile, "Only the private Mobile route loads the source mesh")
		if lamp.fixture != null:
			check(lamp.fixture.visible and lamp.light.light_energy == 0., "The unlit post is present at Noon")
			await verify_lamp(world, review, lamp)
	world.free()
	await process_frame
	if mobile:
		await verify_portable()
	print("PATH_LAMPPOST failures=", failures)
	quit(int(not failures.is_empty()))

func verify_device_review(world: Node3D) -> void:
	for i in 2:
		var graphics = world.biome_controller
		check(world.map_ready and graphics != null, "Device review opens the portable biome")
		if graphics != null:
			world.showcase.set_hour(22.)
			await process_frame
			check(not graphics._path_lamppost._attempted and graphics._path_lamppost.fixture == null,
				"Device review never requests the external lamppost or its collider")
			check(not graphics._path_fixture._attempted and graphics._path_fixture.fixture == null,
				"Device review never requests the external firepit")
			check(graphics._fixture_air().is_empty(), "Device mist has no external fixture light")
			check(not world.showcase.air_light.source_ready, "Device review skips the external air light proof")
		world.free()
		await process_frame
		if i == 0:
			world = load("res://scenes/maps/m2_v1/MeadowBiomeReview.tscn").instantiate()
			root.add_child(world)
			current_scene = world
			await process_frame

func verify_lamp(world: Node3D, review, lamp) -> void:
	review.set_hour(19.15)
	var middle: float = lamp.light.light_energy
	review.set_hour(19.5)
	await process_frame
	await process_frame
	check(middle > 0. and middle < lamp.light.light_energy, "Dusk ramps the light without hiding the mesh")
	check(lamp.fixture.visible and review._point_scope_supported(), "Fixed light preserves player lantern handling")
	check(review.point_kernel_state.w > 0., "Existing player lantern stays active at dusk")
	check(is_equal_approx(lamp.light.omni_range, 3.5), "Local path fixture has the bounded 3.5 m range")
	check(lamp.air_parameters(.5).size() == 12, "Shared mist receives the fixed light")
	check(review._lighting_sliders.has(&"forest_path_lamppost"), "The older fixture is available in the lighting menu")
	review.set_lighting_scale(&"forest_path_light", 0.)
	check(lamp.fixture.visible and lamp.light.light_energy == 0., "The strength slider changes light while leaving the post in place")
	review.set_lighting_scale(&"forest_path_light", .7)
	world.set_review_view("overview")
	await process_frame
	check(lamp.fixture.visible, "Overview keeps the placed post")
	world.set_review_view("gameplay")
	var support: StaticBody3D = lamp.support
	var player: CharacterBody3D = world.player
	var start := Transform3D(player.global_basis, support.global_position + Vector3(.65, -1.4, 0.))
	var hit := KinematicCollision3D.new()
	var offset := Vector3(-1.3, 0., 0.)
	check(player.test_move(start, offset, hit) and hit.get_collider() == support, "The visible shaft stops a direct sweep")
	start.origin.z += 1.
	check(not player.test_move(start, offset), "A route one metre from the post stays clear")
	review.set_lighting_scale(&"forest_path_lamppost", 0.)
	await physics_frame
	check(not lamp.fixture.visible and support.collision_layer == 0 and review.forest_path_light.fixture.visible,
		"Selecting the older fixture removes the post and its collision")
	player.set_physics_process(false)
	player.global_position = support.global_position - Vector3.UP * 1.4
	review.set_lighting_scale(&"forest_path_lamppost", 1.)
	await physics_frame
	check(support.collision_layer == 0, "Selecting the post while standing in its footprint does not trap the player")
	player.global_position += Vector3(1.,0.,0.)
	await process_frame
	await physics_frame
	check(support.collision_layer == 1, "The post becomes solid after the player clears its footprint")
	world.set_reference_look(false)
	await process_frame
	check(not lamp.fixture.visible and support.collision_layer == 0, "Baseline has no added post or blocker")

func verify_portable() -> void:
	var world = load("res://scenes/maps/m2_v1/MeadowBiomeReview.tscn").instantiate()
	world.biome_path_lamp_xz = Vector2(4.5, -4.5)
	world.biome_path_lamp_yaw_degrees = 25.
	root.add_child(world)
	current_scene = world
	await process_frame
	var graphics = world.biome_controller
	var lamp = graphics._path_lamppost
	check(world.map_ready and lamp.fixture != null, "Imported map can place the same private fixture")
	if lamp.fixture != null:
		check(lamp.fixture.visible and lamp.light.light_energy == 0., "Imported biome keeps the post unlit at Noon")
		world.showcase.set_hour(22.)
		check(lamp.light.light_energy > 0. and graphics._fixture_air().size() == 12,
			"Imported biome supplies its own night phase and common fog lights")
		world.set_reference_look(false)
		check(not lamp.fixture.visible and lamp.support.collision_layer == 0, "Imported map also suspends the comparison collider")
	world.free()
	await process_frame
