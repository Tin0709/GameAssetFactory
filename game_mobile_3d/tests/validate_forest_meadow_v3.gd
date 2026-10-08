extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func tick(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	if not ResourceLoader.exists("res://scenes/ForestMeadowV3.tscn"):
		print("FOREST_MEADOW_V3 missing study scene")
		quit(1)
		return
	for asset in ["tree_oak_a","tree_oak_b","shrub_fern","shrub_leaf"]:
		if not ResourceLoader.exists("res://assets/environment/forest_canopy_v3/%s.glb" % asset):
			print("FOREST_MEADOW_V3 asset not imported: " + asset)
			quit(1)
			return
		var asset_root = load("res://assets/environment/forest_canopy_v3/%s.glb" % asset).instantiate()
		for node in asset_root.find_children("*","MeshInstance3D",true,false):
			var mat = node.mesh.surface_get_material(0)
			check(mat.vertex_color_use_as_albedo and not mat.vertex_color_is_srgb,"Reusable asset retains linear vertex color: " + asset)
		asset_root.free()
	var shared_env = load("res://environment/Gameplay.tres")
	var original_ambient: float = shared_env.ambient_light_energy
	var level = load("res://scenes/ForestMeadowV3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.set_enemies_enabled(false)
	await tick(4)
	check(level.v3_missing_assets.is_empty(),"All four V3 assets are imported; no authoring fallback")
	check(level.player.visual.get_script().resource_path=="res://scripts/player_combat_strafe_r15.gd","Original animation writer preserved")
	check(level.player.smooth_step_up_enabled,"Smooth walking ascent remains enabled")
	check(not level.player.visual.animation_player.has_animation_library("jump_v2"),"Jump remains deferred")
	for node in level.forest.get_children():
		if node is MeshInstance3D and node.name.begins_with("Terrace_"):
			var arrays: Array=node.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var tops: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
			check(tops.size()==vertices.size(),"Each terrace vertex carries its actual face top")
			for i in vertices.size():check(tops[i].x+.001>=vertices[i].y,"Grass-cap reference never lies below face vertex")
	var camera_size: float = level.get_node("Camera3D").size
	for stage in [0,1,2,0,2]:
		level.set_forest_stage(stage)
		check(not level.get_node("WorldEnvironment").environment.fog_enabled,"Fog remains deferred")
		check(level.get_node("WorldEnvironment").environment.glow_enabled==(stage==2),"User-requested bloom only in final V3 light stage")
		check(level.get_node("Camera3D").size == camera_size,"Comparison retains gameplay zoom")
		check(level.get_node("Terrain").visible == (stage == 0),"Exactly one terrain presentation visible")
		check(level.forest.visible == (stage > 0),"Forest visibility follows comparison")
		check(level.get_node("Ground").collision_layer == (1 if stage == 0 else 0),"Baseline floor collision restored")
		for grass in level.forest_grass:
			check(grass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Grass never casts shadows")
	check(shared_env.ambient_light_energy == original_ambient,"Shared Environment remains untouched")
	var boundary_ray := PhysicsRayQueryParameters3D.create(Vector3(-26,1.5,-24.5),Vector3(-24,1.5,-24.5),1)
	check(not level.get_world_3d().direct_space_state.intersect_ray(boundary_ray).is_empty(),"Exterior terrace has a closed side and collision")
	# Probe at ankle height: the first pillar and end wall must reach their local floor.
	for probe in [Vector3(3.7,1.15,-6.3),Vector3(6.8,1.2,-3.25)]:
		var axis := Vector3.FORWARD if probe.x < 4.0 else Vector3.RIGHT
		var ray := PhysicsRayQueryParameters3D.create(probe-axis*0.7,probe+axis*0.7,1)
		check(not level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Courtyard foundations touch the lower terrace: " + str(probe))
	level.reset_player()
	var start: Vector3 = level.player.global_position
	Input.action_press("move_forward")
	await tick(42)
	Input.action_release("move_forward")
	check(level.player.global_position.distance_to(start) > 1.7,"Controller can traverse the opening")
	check(level.player.is_on_floor(),"Rendered terrain retains walkable collision")
	level.player.get_node("Pistol").enabled=false
	level.player.position=Vector3(10,1.02,-2);level.player.velocity=Vector3.ZERO
	await tick(24)
	Input.action_press("move_forward");await tick(50);Input.action_release("move_forward");await tick(24)
	check(level.player.is_on_floor() and absf(level.player.position.y-1.5)<.04,"Smoothly walks up V3's existing right terrace")
	level.player.get_node("Pistol").enabled=true
	level.reset_player()
	level.set_enemies_enabled(true)
	var enemy = level.add_review_zombie(Vector3(2.2,1.02,-2))
	var hp: int = enemy.current_hp
	await tick(150)
	check(not is_instance_valid(enemy) or enemy.current_hp < hp,"Production combat damages zombie in new setting")
	var report: Dictionary={"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"missing_assets":level.v3_missing_assets,"terrain_triangles":level.forest_mesh_triangles}
	DirAccess.make_dir_recursive_absolute("res://.validation/forest_meadow_v3")
	FileAccess.open("res://.validation/forest_meadow_v3/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FOREST_MEADOW_V3 " + JSON.stringify(report))
	level.set_enemies_enabled(false)
	level.queue_free()
	await create_timer(0.3).timeout
	quit(0 if failures.is_empty() else 1)
