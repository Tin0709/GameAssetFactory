extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func verify(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	var world = load("res://scenes/WorldMap.tscn").instantiate()
	var absent := "absent" in OS.get_cmdline_user_args()
	root.add_child(world)
	current_scene = world
	await process_frame
	var extension := world.get_node_or_null("ExteriorGround") as Node3D
	var toggle := world.find_child("ExteriorGroundToggle", true, false) as CheckButton
	if absent:
		verify(extension == null and toggle == null, "Unsupported/private source absent leaves the original map")
	else:
		verify(extension != null and toggle != null and toggle.button_pressed, "Private WorldMap enables cliff foot terrain in F5")
		if extension != null and toggle != null:
			verify(extension.visible and extension.get_child_count() == 2, "Both exterior strips are present")
			verify(extension.find_children("*", "CollisionObject3D", true, false).is_empty(), "Exterior has no gameplay collision")
			for child in extension.get_children():
				var mesh := child as MeshInstance3D
				verify(mesh != null and mesh.mesh != null and mesh.mesh.get_surface_count() == 1, "Each strip is one shared stone material batch")
				if mesh != null:
					verify(mesh.get_aabb().end.y < 0., "No new surface rises to the authored world floor")
					verify(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Exterior does not alter existing shadow maps")
					verify(world.showcase._mist_materials().has(mesh.mesh.surface_get_material(0)), "Exterior shares the terrain lighting and mist material")
			var camera: Camera3D = world.get_node("Camera3D")
			var pose := camera.global_transform
			toggle.button_pressed = false
			verify(not extension.visible and camera.global_transform == pose, "The comparison leaves camera placement unchanged")
			toggle.button_pressed = true
			verify(extension.visible, "Re-enable both strips")
			world.set_review_view("overview")
			verify(not extension.visible, "Overview keeps the authored layout")
			world.set_review_view("gameplay")
			verify(extension.visible, "Returning from overview restores the gameplay layer")
			world.showcase.set_source_terrain(false)
			verify(not extension.visible, "Original atlas comparison hides the extension")
			world.showcase.set_source_terrain(true)
			verify(extension.visible, "Returning to the source atlas restores the extension")
			test_source_path_filter(world)
	world.free()
	await process_frame
	print("WORLD_EXTERIOR_GROUND failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func test_source_path_filter(world: Node) -> void:
	var showcase: Node = world.showcase
	var id := &"source_path_edge_filter"
	var slider: HSlider = showcase._settings._sliders.get(String(id))
	verify(slider != null and slider.editable and is_equal_approx(slider.value, 1.),
		"The source atlas enables the Forest path edge control")
	var material: ShaderMaterial = world.look.terrain_materials[0][3]
	var initial: Variant = material.get_shader_parameter(id)
	verify(initial != null and is_equal_approx(float(initial), 1.),
		"The terrain receives the authored path filter")
	showcase.set_lighting_scale(id, 0.)
	var off: Variant = material.get_shader_parameter(id)
	verify(off != null and is_zero_approx(float(off)), "Zero restores point-sampled path noise")
	showcase.set_lighting_scale(id, 1.)
	showcase.set_source_terrain(false)
	verify(slider != null and not slider.editable, "The control is disabled with the source atlas off")
	showcase.set_source_terrain(true)
	verify(slider != null and slider.editable and material.get_shader_parameter(id) == 1.,
		"Restoring the source atlas restores the path filter")
	var path := "user://source_path_filter_%d.cfg" % OS.get_process_id()
	var config := ConfigFile.new()
	verify(showcase.save_lighting_mix(path) == OK and config.load(path) == OK
		and config.get_value("recipe", "version", 0) == 211
		and config.get_value("strengths", String(id), -1.) == 1., "Recipe saves the profile control")
	config.set_value("recipe", "version", 210)
	if config.has_section_key("strengths", String(id)):
		config.erase_section_key("strengths", String(id))
	verify(config.save(path) == OK and showcase.load_lighting_mix(path) == OK
		and material.get_shader_parameter(id) == 0., "An older recipe retains the original path sampling")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
