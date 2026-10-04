extends SceneTree
## Run with --script res://scripts/validate_scene.gd; add -- --capture for a PNG.

func _initialize() -> void:
	call_deferred("_validate")

func _validate() -> void:
	var scene := load("res://scenes/Main.tscn") as PackedScene
	assert(scene != null, "Main scene must load")
	var main := scene.instantiate()
	root.add_child(main)
	assert(main is Node3D)
	assert(main.get_node("Camera3D").current)
	assert(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile")
	if DisplayServer.get_name() != "headless":
		assert(RenderingServer.get_current_rendering_method() == "mobile", "Run with --rendering-method mobile")
	var lights := main.find_children("*", "Light3D", true, false)
	assert(lights.size() == 1 and lights[0] is DirectionalLight3D)
	var environment: Environment = main.get_node("WorldEnvironment").environment
	assert(environment.fog_enabled and not environment.volumetric_fog_enabled)
	assert(not environment.ssao_enabled and not environment.ssr_enabled and not environment.glow_enabled)
	var meshes := main.find_children("*", "MeshInstance3D", true, false)
	var casters := 0
	var triangles := 0
	for mesh: MeshInstance3D in meshes:
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters += 1
		triangles += mesh.mesh.get_faces().size() / 3
	print("VALIDATION PASS: %d meshes, %d triangles, %d shadow casters, one sun; actual renderer: %s" % [meshes.size(), triangles, casters, RenderingServer.get_current_rendering_method()])
	await create_timer(2.0).timeout
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("res://validation_preview.png")
		assert(error == OK)
		print("Preview saved: res://validation_preview.png")
	quit()
