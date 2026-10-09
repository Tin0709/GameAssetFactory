extends SceneTree
const GEOMETRY=preload("res://scripts/world_map_geometry.gd")
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok and not message in failures:failures.append(message)
func tick(count: int) -> void:
	for i in count:await physics_frame

func fixture(records: Array,palette: Array,expected: float,label: String) -> void:
	var node:=GEOMETRY.new()
	root.add_child(node)
	node.build({"offset":[0,0,0],"palette":palette,"cells":records})
	check(node.build_errors.is_empty(),label+" builds")
	check(absf(node.terrain_face_area-expected)<.0001,label+" exposed area")
	node.free()

func run() -> void:
	var full: Dictionary={"kind":"stone_block","category":"terrain","height":1.0,"base_y_offset":0.0}
	var lower: Dictionary={"kind":"grass_slab","category":"terrain","height":.5,"base_y_offset":0.0}
	var upper: Dictionary=lower.duplicate();upper.base_y_offset=.5
	fixture([[0,0,0,0]],[full],6.0,"Isolated full block")
	fixture([[0,0,0,0]],[lower],4.0,"Isolated bottom slab")
	fixture([[0,0,0,0],[1,0,0,1]],[full,lower],9.0,"Full adjacent to bottom slab")
	fixture([[9,0,0,0],[10,0,0,1]],[full,lower],9.0,"Partial contact across chunk edge")
	fixture([[0,0,0,0],[1,0,0,1]],[full,upper],9.0,"Full adjacent to top slab")
	fixture([[0,0,0,0],[0,1,0,0]],[full],10.0,"Stacked full blocks")
	fixture([[0,0,0,0],[0,1,0,1]],[full,lower],8.0,"Full under lower slab")
	fixture([[0,0,0,0],[0,1,0,1]],[full,upper],10.0,"Half-height gap remains open")
	var scene: Node3D=load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	check(scene.map_ready,"Complete map builds")
	if not scene.map_ready:quit(1);return
	await tick(30)
	var data: Dictionary=scene.runtime
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/world_map/manifest.json"))
	var geometry=scene.geometry
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/WorldMap.tscn","F5 uses authored World Map")
	check(geometry.cells.size()==42996,"All original non-air cells retained logically")
	check(absf(geometry.terrain_face_area-float(manifest.expected_terrain_faces.total_area_m2))<.01,"Rendered area matches independent half-voxel audit")
	check(geometry.leaf_collision_count==0,"User requested walk-through leaves: no solid cores")
	var expected_counts: Dictionary={}
	for cell: Array in data.cells:
		var entry: Dictionary=data.palette[int(cell[3])]
		if entry.category in ["terrain","leaf","plant"]:expected_counts[entry.kind]=int(expected_counts.get(entry.kind,0))+1
	check(geometry.placement_counts==expected_counts,"Every mapped logical block/plant placed exactly once")
	check(not geometry.placement_counts.has("red_wool"),"No Red Wool geometry")
	check(geometry.placement_counts.get("tall_grass")==363,"Tall grass upper halves never create duplicate plants")
	check(geometry.placement_counts.get("flower_white")==64,"Both white flower types mapped")
	check(geometry.placement_counts.get("flower_yellow")==257 and geometry.placement_counts.get("flower_blue")==36 and geometry.placement_counts.get("flower_red")==26,"Colored flower positions preserved")
	# Validate actual native MultiMesh translations, not just logical counters.
	var first_part_counts: Dictionary={}
	# Dummy/headless rendering does not retain MultiMesh transform readback.
	var native_readback:=DisplayServer.get_name()!="headless"
	for batch: MultiMeshInstance3D in geometry.vegetation_batches:
		if batch.get_meta("source_part")!=0:continue
		var kind: String=batch.get_meta("kind")
		first_part_counts[kind]=int(first_part_counts.get(kind,0))+batch.multimesh.instance_count
		if not native_readback:continue
		for i in batch.multimesh.instance_count:
			var position: Vector3=batch.transform*batch.multimesh.get_instance_transform(i).origin
			var source:=Vector3i(roundi(position.x-data.offset[0]-.5),floori(position.y-data.offset[1]),roundi(position.z-data.offset[2]-.5))
			check(geometry.cells.has(source),"Plant has original source cell")
			if geometry.cells.has(source):check(data.palette[geometry.cells[source]].kind==kind,"Native plant matches source mapping")
	for kind: String in first_part_counts:check(first_part_counts[kind]==expected_counts[kind],"Native instance count for "+kind)
	check(scene.get_node("Ground/CollisionShape3D").disabled,"Prototype floor disabled")
	check(scene.get_node_or_null("Border")==null,"No procedural prototype cliffs added")
	check(scene.get_node("InvisibleBorder").find_children("*","GeometryInstance3D",true,false).is_empty(),"Boundary is invisible")
	var player: CharacterBody3D=scene.player
	check(player.is_on_floor() and absf(player.position.y-3.0)<.02,"Safe central spawn settles at source height")
	check(player.visual.get_script().resource_path=="res://scripts/player_combat_strafe_r15.gd" and player.smooth_step_up_enabled,"Existing R15 and smooth step retained")
	check(not player.visual.animation_player.has_animation_library("jump_v2"),"Jump animation remains deferred")
	var space:=scene.get_world_3d().direct_space_state
	# Original column heights vs real rendered terrain colliders across the map.
	var excluded: Array[RID]=[]
	for body: StaticBody3D in scene.border_bodies:excluded.append(body.get_rid())
	for body in geometry.find_children("LeafCollision_*","StaticBody3D",true,false):excluded.append(body.get_rid())
	var sampled:=0
	for column: Vector2i in scene.columns:
		if posmod(column.x*7+column.y*11,29)!=0:continue
		var world: Vector3=scene.source_to_world(Vector3i(column.x,0,column.y))
		var ray:=PhysicsRayQueryParameters3D.create(world+Vector3(0,61,0),world+Vector3(0,-2,0),1)
		ray.exclude=excluded
		var hit: Dictionary=space.intersect_ray(ray)
		check(not hit.is_empty() and absf(hit.position.y-float(scene.columns[column]))<.001,"Terrain collider matches source column")
		sampled+=1
	var start: Vector3=player.position
	Input.action_press("move_right");await tick(30);Input.action_release("move_right");await tick(20)
	check(player.position.distance_to(start)>1.0,"WASD moves on authored map")
	# Exercise a real authored half-step, not an extra test platform.
	var step_found:=false
	var stepped:=false
	for column: Vector2i in scene.columns:
		var high: float=scene.columns[column]
		if not is_equal_approx(fposmod(high,1.0),.5):continue
		var target: Vector3=scene.source_to_world(Vector3i(column.x,0,column.y));target.y=high
		if absf(target.x)>45 or absf(target.z)>45 or not scene.clear_standing_space(column,high):continue
		for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var low: float=scene.columns.get(column+direction,-INF)
			if not is_equal_approx(high-low,.5) or not scene.clear_standing_space(column+direction,low):continue
			step_found=true
			player.position=target+Vector3(direction.x,-.48,direction.y);player.velocity=Vector3.ZERO
			await tick(12)
			var action: String="move_right" if direction.x<0 else ("move_left" if direction.x>0 else ("move_backward" if direction.y<0 else "move_forward"))
			Input.action_press(action)
			for step_tick in 40:
				await physics_frame
				if absf(player.position.y-high)<.025 and Vector2(player.position.x-target.x,player.position.z-target.z).length()<.45:
					stepped=true;break
			Input.action_release(action)
			break
		if step_found:break
	check(step_found and stepped,"Existing controller walks smoothly onto an actual mapped half-block")
	# Real character at high clear altitude tests each side/corner without terrain masking the boundary.
	for direction in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
		player.position=Vector3(direction.x*48.5,58,direction.y*48.5);player.velocity=Vector3.ZERO
		var actions: Array[String]=[]
		if direction.x!=0:actions.append("move_right" if direction.x>0 else "move_left")
		if direction.y!=0:actions.append("move_backward" if direction.y>0 else "move_forward")
		for action in actions:Input.action_press(action)
		Input.action_press("sprint");await tick(65)
		for action in actions:Input.action_release(action)
		Input.action_release("sprint")
		check(absf(player.position.x)<50.0 and absf(player.position.z)<50.0,"Sprinting cannot cross side/corner "+str(direction))
		check((direction.x==0 or absf(player.position.x)>49.0) and (direction.y==0 or absf(player.position.z)>49.0),"Character actually reaches boundary")
	scene.reset_player();await tick(20)
	check(player.position.distance_to(scene.spawn_position)<.04,"Reset returns to supported spawn")
	geometry.update_cutaway(player.position,player.position+Vector3(12,15,16))
	geometry.update_cutaway(Vector3.ZERO,Vector3.ZERO)
	for chunk in geometry.terrain_chunks:
		for s in chunk.mesh.get_surface_count():check(chunk.get_surface_override_material(s)==null,"Overview restores native material")
	var env: Environment=scene.get_node("WorldEnvironment").environment
	check(is_equal_approx(env.tonemap_exposure,.96) and env.fog_enabled and env.glow_enabled,"Existing lighting preserved")
	DirAccess.make_dir_recursive_absolute("res://.validation/world_map")
	var report: Dictionary={"checks":checks,"failures":failures,"source_sha256":data.source_sha256,"terrain_area_m2":geometry.terrain_face_area,"terrain_triangles":geometry.terrain_triangles,"terrain_chunks":geometry.terrain_chunks.size(),"placement_counts":geometry.placement_counts,"column_raycasts":sampled,"build_msec":scene.build_msec,"renderer":RenderingServer.get_current_rendering_method(),"phone_verified":false}
	report["native_transform_readback"]=native_readback
	FileAccess.open("res://.validation/world_map/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for failure in failures:push_error(failure)
	print("WORLD_MAP_CHECKS "+JSON.stringify(report))
	scene.queue_free();await process_frame;await create_timer(.25).timeout
	quit(0 if failures.is_empty() else 1)
