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
	world.free()
	await process_frame
	print("WORLD_EXTERIOR_GROUND failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
