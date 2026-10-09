extends SceneTree
## Native Mobile frames, actual input/controller passage; silent fixed-FPS movie is not a benchmark.
const OUT:="res://.validation/world_map/"
var failures: Array[String]=[]
var checks:=0
var content_start:=0
var landmarks: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func frames(count: int) -> void:
	for i in count:await process_frame
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
	landmarks[name]=Engine.get_frames_drawn()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var level: Node3D=load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(level);current_scene=level
	await frames(15)
	level.get_node("HUD").hide()
	var look=level.look
	level.player.set_physics_process(false)
	level.player.visual.set_process(false)
	look.freeze_motion(0.0)
	content_start=Engine.get_frames_drawn()
	await capture("wind_phase_0")
	look.freeze_motion(1.0)
	await capture("wind_phase_1")
	for material: ShaderMaterial in look.wind_materials:
		var tall: bool=material.shader.resource_path.ends_with("world_map_leaves.gdshader") or material.get_shader_parameter("plant_kind")==2
		check(is_equal_approx(material.get_shader_parameter("wind_strength"),1.5 if tall else 2.0),"Requested per-kind wind gain")
	# A/B must restore every native texture/material without changing the world.
	var position: Vector3=level.player.position
	level.set_reference_look(false)
	for item: Array in look.terrain_materials:check(item[0].surface_get_material(item[1])==item[2],"Native terrain restored")
	for item: Array in look.plant_meshes:check(item[0].mesh==item[1],"Native plant mesh restored")
	level.set_reference_look(true)
	check(level.player.position==position and level.runtime.cells.size()==42996,"Look toggle preserves position and map")
	check(level.geometry.leaf_collision_count==0,"Leaves remain walk-through in both looks")
	for item: Array in look.terrain_materials:
		check(item[3].get_shader_parameter("atlas").get_image().has_mipmaps(),"Runtime ground uses valid mipmaps")
	look.active=true
	level.player.set_physics_process(true);level.player.visual.set_process(true)
	await frames(60)
	landmarks["walk_through_grass_flowers"]=Engine.get_frames_drawn()
	Input.action_press("move_left")
	await frames(30)
	check(look.motion.active_count>0,"Actual player movement records plant passage")
	# Freeze at contact: compare only interaction, same pose/light/wind/camera.
	level.player.set_physics_process(false);level.player.visual.set_process(false);look.active=false
	await capture("passage_on")
	for material: ShaderMaterial in look.wind_materials:material.set_shader_parameter("interaction_strength",0.0)
	await capture("passage_off")
	for material: ShaderMaterial in look.wind_materials:material.set_shader_parameter("interaction_strength",1.0)
	level.player.set_physics_process(true);level.player.visual.set_process(true);look.active=true
	await frames(30)
	Input.action_release("move_left")
	await frames(36)
	check(look.motion.active_count==0,"Passage recovers after stopping")
	check(level.player.position.x< -7.0,"Actual walk crosses the authored flower/grass band")
	# Explicit second shot of another map area; teleport is not claimed as locomotion.
	level.player.position=Vector3(-33.5,3.02,7.5);level.player.velocity=Vector3.ZERO
	await frames(30)
	landmarks["leaf_area_cut"]=Engine.get_frames_drawn()
	Input.action_press("move_right")
	await frames(58)
	Input.action_release("move_right")
	await frames(30)
	check(level.player.position.x> -27.0,"Player walks fully through real full/half leaf cluster")
	check(level.player.position.y<3.1,"Leaf cluster does not lift the player onto a solid box")
	var last:=Engine.get_frames_drawn()
	var report: Dictionary={"checks":checks,"failures":failures,"first_content_frame":content_start,"last_content_frame":last,"landmarks":landmarks,"actual_player_end":var_to_str(level.player.position),"offline_movie_fps":30,"phone_verified":false,"audio":"Dummy in test process only"}
	FileAccess.open(OUT+"movie.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WORLD_MAP_MOTION "+JSON.stringify(report))
	for failure in failures:push_error(failure)
	level.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
