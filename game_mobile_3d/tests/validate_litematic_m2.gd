extends SceneTree
var failures: Array[String] = []
var report := {}
var map
const SOLIDS := ["minecraft:dirt","minecraft:grass_block[snowy=false]","minecraft:stone"]
const DIRS := [Vector3i(1,0,0),Vector3i(-1,0,0),Vector3i(0,1,0),Vector3i(0,-1,0),Vector3i(0,0,1),Vector3i(0,0,-1)]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	call_deferred("run")
func face_key(p: Vector3i,d: Vector3i) -> String:
	return "%d,%d,%d:%d,%d,%d" % [p.x,p.y,p.z,d.x,d.y,d.z]
func expected_faces(cells: Dictionary) -> Dictionary:
	var result := {}
	for p in cells:
		if cells[p] not in SOLIDS: continue
		for d in DIRS:
			if cells.get(p+d,"") not in SOLIDS: result[face_key(p,d)] = 2
	return result
func actual_faces(parent: Node3D) -> Dictionary:
	var result := {}
	for node in parent.get_children():
		var mesh: Mesh = node.mesh
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var a: Vector3 = node.transform*vertices[indices[i]]
				var b: Vector3 = node.transform*vertices[indices[i+1]]
				var c: Vector3 = node.transform*vertices[indices[i+2]]
				var d := Vector3i(normals[indices[i]].round())
				var center := (a.min(b).min(c)+a.max(b).max(c))*0.5
				var owner := Vector3i((center-Vector3(d)*0.5).floor())
				var key := face_key(owner,d)
				result[key] = result.get(key,0)+1
	return result
func diff_count(a: Dictionary,b: Dictionary) -> int:
	var count := 0
	for k in a:
		if b.get(k) != a[k]: count += 1
	for k in b:
		if not a.has(k): count += 1
	return count
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var scene := "res://scenes/maps/m2_v1/LitematicMapPreview.tscn"
	check(ResourceLoader.exists(scene),"M2 reconstruction scene missing")
	if not failures.is_empty(): quit(1); return
	map = load(scene).instantiate()
	root.add_child(map)
	await frames(3)
	check(map.validate_runtime(),"complete package validation")
	var saved: Dictionary = map.runtime
	var malformed: Dictionary = saved.duplicate(true)
	for c in malformed.cells:
		if c[3] == map.UPPER:
			c[3] = "minecraft:air"
			break
	map.runtime = malformed
	check(not map.validate_runtime(),"unpaired tall upper accepted")
	malformed = saved.duplicate(true)
	malformed.cells.append(malformed.cells[0])
	map.runtime = malformed
	check(not map.validate_runtime(),"duplicate coordinate accepted")
	malformed = saved.duplicate(true)
	malformed.cells[0][3] = "minecraft:unsupported_variant"
	map.runtime = malformed
	check(not map.validate_runtime(),"unsupported state accepted")
	malformed = saved.duplicate(true)
	var forged: Dictionary = malformed.registry[0].duplicate(true)
	forged.state = "minecraft:unsupported_variant"
	malformed.registry.append(forged)
	malformed.cells[0][3] = forged.state
	map.runtime = malformed
	check(not map.validate_runtime(),"forged self-consistent registry state accepted")
	malformed = saved.duplicate(true)
	malformed.cells[0][0] = float(malformed.cells[0][0])+0.25
	map.runtime = malformed
	check(not map.validate_runtime(),"fractional cell coordinate accepted")
	map.runtime = saved
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../minecraft_maps/m2_v1/map_data.json")))
	var expected := {}
	for region in source.regions:
		for c in region.cells_including_air:
			var p := Vector3i(c[0],c[1],c[2])
			expected[p] = c[3]
	var mismatches := diff_count(expected,map.cells)
	var counts := {}
	for p in expected: counts[expected[p]] = counts.get(expected[p],0)+1
	check(diff_count(counts,map.runtime.counts) == 0,"independent source state counts differ")
	check(mismatches == 0,"logical coordinate/state mismatches")
	check(expected.size() == 15000,"full volume")
	report.logical_mismatches = mismatches
	report.summary = map.get_map_summary()
	report.fail_closed_malformed_packages = 5
	var exp_faces := expected_faces(expected)
	var got_faces := actual_faces(map.get_node("Terrain"))
	var face_diff := diff_count(exp_faces,got_faces)
	check(face_diff == 0,"ACTUAL committed terrain face keys differ")
	check(got_faces.size() == 5448 and map.terrain_triangles == 10896,"face/triangle contract")
	report.actual_face_key_mismatches = face_diff
	report.actual_exposed_faces = got_faces.size()
	var fixture := {Vector3i(2,1,4):"minecraft:dirt",Vector3i(3,1,4):"minecraft:stone",Vector3i(2,2,4):"minecraft:grass_block[snowy=false]",Vector3i(2,1,5):"minecraft:stone"}
	var fixture_node := Node3D.new()
	map.add_child(fixture_node)
	map.build_terrain(fixture,fixture_node)
	var fixture_diff := diff_count(expected_faces(fixture),actual_faces(fixture_node))
	check(fixture_diff == 0,"asymmetric +X/+Y/+Z fixture geometry")
	report.asymmetric_fixture_face_mismatches = fixture_diff
	fixture_node.queue_free()
	await frames(2)
	var expected_plants := {}
	for p in expected:
		if expected[p] in [map.SHORT,map.LOWER]: expected_plants["%s@%s" % [expected[p],Vector3(p)+Vector3(0.5,0,0.5)]] = 1
	var actual_plants := {}
	var plant_counts := {"short":0,"tall":0}
	var attribute_bad := 0
	for node in map.vegetation:
		var state: String = node.get_meta("source_state")
		var mm: MultiMesh = node.multimesh
		for i in range(mm.instance_count):
			var transform := mm.get_instance_transform(i)
			check(transform.basis.is_equal_approx(Basis.IDENTITY),"plant orientation modified")
			var key := "%s@%s" % [state,node.transform*transform.origin]
			actual_plants[key] = actual_plants.get(key,0)+1
		plant_counts["short" if state == map.SHORT else "tall"] += mm.instance_count
		for s in range(mm.mesh.get_surface_count()):
			var a := mm.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = a[Mesh.ARRAY_COLOR]
			var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
			for i in range(vertices.size()):
				var t := vertices[i].y/mm.mesh.get_aabb().size.y
				if absf(colors[i].r-t*t)>0.004 or absf(colors[i].g-t)>0.004 or not uv2[i].is_equal_approx(Vector2(0.5,0.5)): attribute_bad += 1
	var plant_diff := diff_count(expected_plants,actual_plants)
	print("PLANT_COUNTS ",plant_counts," expected sample ",expected_plants.keys()[0]," actual ",actual_plants.keys()[0]," diff ",plant_diff)
	check(plant_diff == 0 and plant_counts.short == 512 and plant_counts.tall == 50,"actual plant transforms missing/duplicate")
	check(attribute_bad == 0,"plant root/tip COLOR/UV2 attributes")
	report.actual_plant_transform_mismatches = plant_diff
	report.plants = plant_counts
	report.bend_attribute_mismatches = attribute_bad
	var ray_bad := 0
	var heights := {}
	var space = map.get_world_3d().direct_space_state
	for z in range(50):
		for x in range(50):
			var h := -1
			for y in range(6):
				if expected.get(Vector3i(x,y,z),"") in SOLIDS: h = y+1
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x+0.5,9,z+0.5),Vector3(x+0.5,-2,z+0.5),1))
			if hit.is_empty() or absf(hit.position.y-h)>0.001: ray_bad += 1
			heights[str(h)] = heights.get(str(h),0)+1
	for p in [Vector3(-0.5,9,25),Vector3(50.5,9,25),Vector3(25,9,-0.5),Vector3(25,9,50.5)]:
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p-Vector3(0,12,0),1)).is_empty(): ray_bad += 1
	check(ray_bad == 0,"real terrain collision rays failed")
	report.collision_rays = {"columns":2500,"outside":4,"mismatches":ray_bad,"source_top_heights":heights}
	var player: CharacterBody3D = map.player
	check(player.walk_speed == 4.25 and player.run_speed == 6.25,"production speeds changed")
	player.global_position = Vector3(10.5,5,10.5)
	player.velocity = Vector3.ZERO
	await frames(120)
	check(player.is_on_floor() and absf(player.position.y-2)<0.05,"production player fall/settle")
	report.player_settle_y = player.position.y
	var start := player.position
	Input.action_press("move_right")
	await frames(45)
	Input.action_release("move_right")
	check(player.position.x-start.x>1.5 and player.is_on_floor(),"walk on exact terrain")
	check(map.motion.active_count>0,"live player interaction trail")
	check(map.grass_material.get_shader_parameter("wind_phase") == map.tall_grass_material.get_shader_parameter("wind_phase"),"wind clocks differ")
	check(map.grass_material.get_shader_parameter("wind_direction") == map.tall_grass_material.get_shader_parameter("wind_direction"),"wind direction differs")
	report.walk_distance = player.position.x-start.x
	report.motion_active_count = map.motion.active_count
	check(map.get_node("Camera3D").position.distance_to(player.position+map.camera_offset)<0.2,"production camera follow")
	var wall := Vector3i.ZERO
	for p in expected:
		if expected[p] == "minecraft:stone" and p.y==2 and expected.get(p+Vector3i(-1,0,0),"") not in SOLIDS:
			wall = p; break
	player.position = Vector3(wall.x-1.0,2.02,wall.z+0.5)
	player.velocity = Vector3.ZERO
	await frames(15)
	Input.action_press("move_right")
	await frames(45)
	Input.action_release("move_right")
	check(player.position.x <= wall.x-0.28 and player.position.y <2.1,"1m stone face collision preserved")
	report.stone_wall = {"cell":[wall.x,wall.y,wall.z],"player_stop":[player.position.x,player.position.y,player.position.z]}
	check(map.combat.living_zombies.is_empty() and not map.enemies_enabled and map.spawner.spawn_remaining==0,"peaceful startup")
	map.set_enemies_enabled(true)
	await frames(90)
	check(map.combat.living_zombies.is_empty() and map.spawner.spawn_remaining==0 and not map.spawner.is_physics_processing(),"no automatic spawn after enabling manual control")
	var spawned: int = map.spawn_review_enemies(1)
	check(spawned == 1,"manual spawn control")
	map.set_enemies_enabled(false)
	map.reset_player()
	report.manual_spawn = spawned
	report.failures = failures
	report.status = "PASS" if failures.is_empty() else "FAIL"
	var path := ProjectSettings.globalize_path("res://").path_join("../.validation/m2_litematic/godot_validation.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)



