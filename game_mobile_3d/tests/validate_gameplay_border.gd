extends SceneTree
## Independent physics checks: removing an edge/corner or its collider must fail.
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func finish() -> void:
	DirAccess.make_dir_recursive_absolute("res://.validation/flat_map_100x100")
	FileAccess.open("res://.validation/flat_map_100x100/border_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	for failure in failures: push_error(failure)
	print("GAMEPLAY_BORDER_VALIDATION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	var level: Node3D = load("res://scenes/GameplayMap.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for i in 30: await physics_frame
	check(level.has_node("Border"), "Continuous dirt/stone border is present in the F5 map")
	if not level.has_node("Border"):
		finish()
		return
	var space := level.get_world_3d().direct_space_state
	var heights: Array[float] = []
	# Four complete edges and their four corner transitions, at half-cell centres.
	for side in 4:
		for cell in range(-50,50):
			var p := Vector2(-50.5,cell+.5)
			if side==1: p = Vector2(50.5,cell+.5)
			if side==2: p = Vector2(cell+.5,-50.5)
			if side==3: p = Vector2(cell+.5,50.5)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,40,p.y),Vector3(p.x,-1,p.y),1))
			check(not hit.is_empty() and hit.position.y>=11.0, "Wall at least 10 blocks above floor: side %d cell %d" % [side,cell])
			if not hit.is_empty(): heights.append(hit.position.y)
	for x in [-50.5,50.5]:
		for z in [-50.5,50.5]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,40,z),Vector3(x,-1,z),1))
			check(not hit.is_empty() and hit.position.y>=11, "Closed corner at %s,%s" % [x,z])
	check(not heights.is_empty() and heights.max()-heights.min()>=5.0, "Noticeably uneven cliff heights")
	for side in 4:
		var low_tops: Array[float] = []
		for s in range(-45,46,3):
			for d in range(42,50):
				var p := Vector2(-d-.5,s+.5)
				if side==1: p = Vector2(d+.5,s+.5)
				if side==2: p = Vector2(s+.5,-d-.5)
				if side==3: p = Vector2(s+.5,d+.5)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,40,p.y),Vector3(p.x,-1,p.y),1))
				if not hit.is_empty() and hit.position.y>=3.0 and hit.position.y<11.0: low_tops.append(hit.position.y)
		check(low_tops.size()>20, "Smaller 2+ block columns on inner side %d" % side)
		check(not low_tops.is_empty() and low_tops.max()-low_tops.min()>=2, "Uneven low columns on inner side %d" % side)
	for p in [Vector2(-39.5,0),Vector2(39.5,0),Vector2(0,-39.5),Vector2(0,39.5),Vector2(-39.5,-39.5),Vector2(39.5,39.5)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,40,p.y),Vector3(p.x,-1,p.y),1))
		check(not hit.is_empty() and is_equal_approx(hit.position.y,1.0), "Central playable area stays flat at %s" % p)
	var player: CharacterBody3D = level.get_node("Actors/Player")
	var approach := Vector3(48.5,1.02,2.5)
	var approach_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(approach+Vector3(0,39,0),approach-Vector3(0,3,0),1))
	check(not approach_hit.is_empty() and is_equal_approx(approach_hit.position.y,1.0), "Wall approach starts on clear floor, outside buttresses")
	player.position = approach
	player.velocity = Vector3.ZERO
	Input.action_press("move_right")
	var stayed_inside := true
	var contacted_border := false
	for i in 120:
		await physics_frame
		stayed_inside = stayed_inside and player.position.x<49.9 and player.position.x>48.0 and player.position.y>.9
		for collision in player.get_slide_collision_count():
			var collider = player.get_slide_collision(collision).get_collider()
			contacted_border = contacted_border or level.get_node("Border").is_ancestor_of(collider)
	Input.action_release("move_right")
	for i in 10: await physics_frame
	check(stayed_inside and contacted_border and player.is_on_floor() and player.position.x>48 and player.position.y<1.1, "Player contacts border without crossing, falling or resetting")
	var border: Node3D = level.get_node("Border")
	check(border.get_meta("dirt_columns",0)>0 and border.get_meta("stone_columns",0)>0, "Both dirt and stone clusters exist")
	print("BORDER_DIAGNOSTIC heights=%s..%s triangles=%s" % [heights.min(),heights.max(),border.get_meta("triangles",0)])
	finish()
