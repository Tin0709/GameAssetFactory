extends SceneTree
## Checks the playable floor and F5 entry point, independently of terrain building.
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://scenes/GameplayMap.tscn"
	if not ResourceLoader.exists(path):
		push_error("Missing official 100 x 100 gameplay map")
		quit(1)
		return
	check(ProjectSettings.get_setting("application/run/main_scene") == path, "F5 opens official map")
	var level: Node3D = load(path).instantiate()
	root.add_child(level)
	current_scene = level
	for i in 30: await physics_frame
	var terrain: Node3D = level.get_node("Terrain")
	check(terrain.get_child_count() == 100, "100 terrain chunks")
	var area := 0.0
	var bounds := AABB()
	var first := true
	for child in terrain.get_children():
		var mesh: Mesh = child.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			# Flat render AABBs receive epsilon padding; measure actual mesh points.
			for vertex in vertices:
				var point: Vector3 = child.transform * vertex
				bounds = AABB(point,Vector3.ZERO) if first else bounds.expand(point)
				first = false
			for i in range(0, indices.size(), 3):
				var a: Vector3 = child.transform * vertices[indices[i]]
				var b: Vector3 = child.transform * vertices[indices[i+1]]
				var c: Vector3 = child.transform * vertices[indices[i+2]]
				if absf(a.y-1.0)<.00001 and absf(b.y-1.0)<.00001 and absf(c.y-1.0)<.00001:
					area += (b-a).cross(c-a).length()*.5
	check(bounds.position.is_equal_approx(Vector3(-50,0,-50)) and bounds.size.is_equal_approx(Vector3(100,1,100)), "Exact 100 x 100 x 1 metre bounds")
	check(absf(area-10000.0)<.01, "Exactly 10000 square metres of level grass tops")
	var floor_shape: CollisionShape3D = level.get_node("Ground/CollisionShape3D")
	check(floor_shape.shape.size == Vector3(100,1,100) and floor_shape.position.y == .5, "Collision matches visual floor")
	var space := level.get_world_3d().direct_space_state
	var border_bodies: Array[RID] = []
	for body in level.get_node("Border").find_children("*","StaticBody3D",true,false): border_bodies.append(body.get_rid())
	for x in range(-49,50,7):
		for z in range(-49,50,7):
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,3,z), Vector3(x,-1,z), 1)
			ray.exclude = border_bodies
			var hit := space.intersect_ray(ray)
			check(not hit.is_empty() and absf(hit.position.y-1)<.00001, "Flat supported floor at %d,%d" % [x,z])
	var outside_ray := PhysicsRayQueryParameters3D.create(Vector3(50.1,3,0),Vector3(50.1,-1,0),1)
	outside_ray.exclude = border_bodies
	var outside := space.intersect_ray(outside_ray)
	check(outside.is_empty(), "Floor ends at exact map perimeter")
	var player: CharacterBody3D = level.get_node("Actors/Player")
	check(player.is_on_floor() and absf(player.position.y-1.0)<.01, "Player settles at central spawn")
	check(player.get_node("Visual").get_script().resource_path == "res://scripts/player_combat_strafe_r15.gd", "Existing R15 animation system retained")
	check(player.smooth_step_up_enabled, "Existing smooth step controller retained")
	var start := player.position
	Input.action_press("move_right")
	for i in 30: await physics_frame
	Input.action_release("move_right")
	for i in 10: await physics_frame
	check(player.is_on_floor() and player.position.x-start.x>1.5, "Existing WASD moves the player on the new floor")
	player.position = Vector3(38,1.02,38)
	player.velocity = Vector3.ZERO
	for i in 20: await physics_frame
	check(player.is_on_floor() and player.position.x>37 and player.position.z>37, "New outer area beyond old map remains playable")
	var camera: Camera3D = level.get_node("Camera3D")
	check(camera.position.distance_to(player.position+Vector3(12,15,16))<.01, "Camera follows at existing offset")
	check(camera.projection==Camera3D.PROJECTION_ORTHOGONAL and camera.size==14.5, "Existing camera zoom retained")
	level.reset_player()
	for i in 20: await physics_frame
	check(Vector2(player.position.x,player.position.z).length()<.01, "R resets to map centre")
	check(level.get_node("Actors").get_child_count()==1, "Peaceful map startup")
	check(RenderingServer.get_current_rendering_method()=="mobile", "Mobile renderer retained")
	var env: Environment = level.get_node("WorldEnvironment").environment
	print("MAP_DIAGNOSTIC bounds=%s exposure=%.10f glow=%s fog=%s" % [bounds,env.tonemap_exposure,env.glow_enabled,env.fog_enabled])
	check(is_equal_approx(env.tonemap_exposure,.96) and env.glow_enabled and env.fog_enabled, "Current light/bloom/haze retained")
	var imported := ConfigFile.new()
	check(imported.load("res://assets/environment/litematic_m2_v2/grass_block_di_v3_meadow_m2_atlas.png.import")==OK and imported.get_value("params","compress/mode")==0, "Original pixel atlas retains lossless import")
	DirAccess.make_dir_recursive_absolute("res://.validation/flat_map_100x100")
	FileAccess.open("res://.validation/flat_map_100x100/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"top_area_m2":area,"geometry_bounds":str(bounds),"terrain_triangles":level.terrain_triangles,"main_scene":ProjectSettings.get_setting("application/run/main_scene"),"scope":"Map floor/controller contract; phone FPS not measured"},"\t"))
	for failure in failures: push_error(failure)
	print("GAMEPLAY_MAP_VALIDATION: %d checks, %d failures; top_area=%.2f" % [checks,failures.size(),area])
	quit(0 if failures.is_empty() else 1)
