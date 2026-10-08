extends SceneTree
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://scenes/Grassland_50x50.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	var summary: Dictionary = scene.get_environment_summary()
	check(summary.terrain_cells == 2500 and summary.terrain_chunks == 25,"2500 cells / 25 chunks")
	check(summary.missing_assets.is_empty(),"missing native assets")
	check(summary.asset_usage.size() == 21,"all 18 scatter + V4 block/dirt/grass assets")
	for name in summary.asset_usage: check(summary.asset_usage[name] > 0,"unused asset " + name)
	var repeat = preload("res://scripts/grassland_50x50_layout.gd").new()
	repeat.build(scene.entries,scene.environment_seed,1,1,1,1)
	check(repeat.grass == scene.layout.grass and repeat.props == scene.layout.props,"determinism")
	var sparse = preload("res://scripts/grassland_50x50_layout.gd").new()
	sparse.build(scene.entries,scene.environment_seed,0.3,0.3,0.3,0.3)
	check(sparse.grass.size() < repeat.grass.size(),"grass density responds")
	for name in scene.layout.props:
		for t in scene.layout.props[name]:
			check(not scene.layout.is_clear(Vector2(t.origin.x,t.origin.z),0.2),"prop obstructs clearing/path")
	for point in scene.layout.grass:
		check(Vector2(point.origin.x,point.origin.z).length() > 2.5,"spawn grass clearance")
	check(scene.combat.living_zombies.is_empty() and not scene.enemies_enabled,"peaceful startup")
	check(scene.spawn_review_enemies(5) == 0,"OFF rejects spawn")
	scene.set_enemies_enabled(true)
	for i in range(120): await physics_frame
	check(scene.combat.living_zombies.is_empty(),"ON is manual only over 120 physics frames")
	check(scene.spawn_review_enemies(1) == 1,"manual one")
	check(scene.spawn_review_enemies(5) == 5,"manual five")
	check(scene.combat.living_zombies.size() == 6,"exactly six real enemies")
	for enemy in scene.combat.living_zombies:
		check(absf(enemy.position.y-1.02)<0.001,"spawn terrain height")
		check(scene.layout.rock_clear(Vector2(enemy.position.x,enemy.position.z),1.2),"spawn rock clearance")
	# ON must stay manual: its processing flag is the contract.
	check(not scene.spawner.is_physics_processing(),"automatic spawning disabled")
	scene.set_enemies_enabled(false)
	await process_frame
	check(scene.combat.living_zombies.is_empty() and scene.get_node("Actors").get_child_count()==1,"OFF clears actors")
	check(scene.combat.projectiles.get_child_count()==0,"OFF clears projectiles")
	for i in range(8): await physics_frame
	check(scene.combat.living_zombies.is_empty(),"OFF stays peaceful")
	scene.set_graphics_quality(true)
	check(scene.high_quality and scene.vegetation[0].visibility_range_end==65,"detail vegetation range")
	scene.set_graphics_quality(false)
	check(not scene.high_quality and scene.vegetation[0].visibility_range_end==50,"mobile vegetation range")
	var camera: Camera3D = scene.get_node("Camera3D")
	var view_size := root.get_visible_rect().size
	for screen in [Vector2.ZERO,Vector2(view_size.x,0),view_size,Vector2(0,view_size.y)]:
		var origin := camera.project_ray_origin(screen)
		var direction := camera.project_ray_normal(screen)
		var ground_point := origin + direction * ((1.0-origin.y)/direction.y)
		check(camera.global_position.distance_to(ground_point)+7.1 < 50.0,"mobile culling covers viewport plus chunk radius")
	var rock_positions: Array[Vector3] = []
	for name in scene.layout.props:
		if not str(name).begins_with("ENV_Rock"): continue
		for t in scene.layout.props[name]:
			check(absf(t.origin.x)<=23 and absf(t.origin.z)<=23,"accepted rock in bounds")
			for previous in rock_positions: check(t.origin.distance_to(previous)>=0.8999,"cross and same variant rock spacing")
			rock_positions.append(t.origin)
	var ground: BoxShape3D = scene.get_node("Ground/CollisionShape3D").shape
	check(ground.size == Vector3(50,1,50),"flat collider")
	var space := scene.get_world_3d().direct_space_state
	for x in [-24.0,0.0,24.0]:
		for z in [-24.0,0.0,24.0]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,3,z),Vector3(x,0,z),1))
			check(not hit.is_empty() and absf(hit.position.y-1.0)<0.001,"ground continuity")
	scene.player.take_damage(99999)
	check(scene.player.is_dead and not scene.combat.active,"production defeat occurred")
	scene.reset_player()
	await process_frame
	await process_frame
	scene = current_scene
	check(scene != null and not scene.player.is_dead and scene.combat.active,"R recreates defeated scene through lifecycle")
	check(not scene.enemies_enabled and scene.combat.living_zombies.is_empty(),"defeat reload returns peaceful scene")
	check(scene.player.get_node("Pistol").is_physics_processing(),"defeat reload restores production pistol processing")
	var report := {"passed":failures.is_empty(),"failures":failures,"summary":summary,"landmarks":scene.get_review_landmarks()}
	var file := FileAccess.open("res://../.validation/grassland_e2/map_validation.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)



