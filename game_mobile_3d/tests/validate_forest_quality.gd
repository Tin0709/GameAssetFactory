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
	if not ResourceLoader.exists("res://scenes/ForestQualitySlice.tscn"):
		print("FOREST_QUALITY missing study scene")
		quit(1)
		return
	for asset in ["tree_oak_a","tree_oak_b","shrub_fern","shrub_leaf"]:
		if not ResourceLoader.exists("res://assets/environment/forest_canopy_v2/%s.glb" % asset):
			print("FOREST_QUALITY asset not imported: " + asset)
			quit(1)
			return
		var asset_root = load("res://assets/environment/forest_canopy_v2/%s.glb" % asset).instantiate()
		for node in asset_root.find_children("*","MeshInstance3D",true,false):
			var mat = node.mesh.surface_get_material(0)
			check(mat.vertex_color_use_as_albedo and not mat.vertex_color_is_srgb,"Reusable asset retains linear vertex color: " + asset)
		asset_root.free()
	var shared_env = load("res://environment/Gameplay.tres")
	var original_ambient: float = shared_env.ambient_light_energy
	var level = load("res://scenes/ForestQualitySlice.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.set_enemies_enabled(false)
	await tick(4)
	var camera_size: float = level.get_node("Camera3D").size
	for stage in [0,1,2,0,2]:
		level.set_forest_stage(stage)
		check(not level.get_node("WorldEnvironment").environment.fog_enabled,"Fog remains deferred")
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
	level.reset_player()
	level.set_enemies_enabled(true)
	var enemy = level.add_review_zombie(Vector3(2.2,1.02,-2))
	var hp: int = enemy.current_hp
	await tick(150)
	check(not is_instance_valid(enemy) or enemy.current_hp < hp,"Production combat damages zombie in new setting")
	print("FOREST_QUALITY " + JSON.stringify({"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}))
	level.set_enemies_enabled(false)
	level.queue_free()
	await create_timer(0.3).timeout
	quit(0 if failures.is_empty() else 1)
