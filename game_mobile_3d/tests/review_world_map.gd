extends SceneTree
## GPU pixels from the F5 scene; no offline image substitute.
const OUT:="res://.validation/world_map/"
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
	print("WORLD_MAP_CAPTURE "+name)
func tick(count: int) -> void:
	for i in count:await physics_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var level: Node3D=load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(level);current_scene=level
	await tick(30)
	var args:=OS.get_cmdline_user_args()
	var prefix:="baseline" if "--baseline" in args else "review"
	if "--baseline" in args and level.has_method("set_reference_look"):level.set_reference_look(false)
	if "--materials" in args:level.look.set_stage(1);prefix="materials"
	if "--no-shadows" in args:level.get_node("Sun").shadow_enabled=false;prefix="no_shadows"
	if "--bias-probe" in args:
		level.get_node("Sun").shadow_bias=.12
		level.get_node("Sun").shadow_normal_bias=1.2
		prefix="bias_probe"
	if level.get_node_or_null("ReferenceLook")!=null:level.look.freeze_motion()
	if "--no-variation" in args:
		for item: Array in level.look.terrain_materials:item[3].set_shader_parameter("grass_variation_strength",0.0)
		level.geometry.reset_cutaway_materials()
		prefix="no_variation"
	if "--no-contact" in args:
		for item: Array in level.look.terrain_materials:item[3].set_shader_parameter("contact_shade_strength",0.0)
		level.geometry.reset_cutaway_materials()
		prefix="no_contact"
	if "--no-soil" in args:
		for item: Array in level.look.terrain_materials:item[3].set_shader_parameter("plant_soil_strength",0.0)
		level.geometry.reset_cutaway_materials()
		prefix="no_soil"
	level.set_process(false)
	level.player.set_physics_process(false)
	level.player.visual.set_process(false)
	level.get_node("HUD").hide()
	await capture(prefix+"_gameplay")
	var camera: Camera3D=level.get_node("Camera3D")
	var env: Environment=level.get_node("WorldEnvironment").environment
	var saved_fog:=env.fog_enabled
	level.set_review_view("overview")
	env.fog_enabled=false
	await capture(prefix+"_topdown_diagnostic")
	camera.size=142.0;camera.position=Vector3(70,97,98);camera.rotation_degrees=Vector3(-36.315886,36.869898,0)
	await capture(prefix+"_isometric_diagnostic")
	env.fog_enabled=saved_fog
	# Shared camera coordinates make before/after views reproducible.
	for spec: Array in [["west_grove",Vector2(-26,6)],["cliffs",Vector2(40,-31)],["flowers",Vector2(-4,-8)],["leaf_walk",Vector2(-31,7)]]:
		var point: Vector2=spec[1]
		var height: float=level.surface_height(point.x,point.y)
		if not is_finite(height):continue
		level.player.position=Vector3(point.x,height+.02,point.y)
		level.set_review_view("gameplay")
		level.geometry.update_cutaway(level.player.position,camera.position)
		await capture(prefix+"_"+spec[0])
	if prefix=="review":
		await capture("contact_on")
		for item: Array in level.look.terrain_materials:item[3].set_shader_parameter("contact_shade_strength",0.0)
		level.geometry.reset_cutaway_materials()
		level.geometry.update_cutaway(level.player.position,camera.position)
		await capture("contact_off")
		for item: Array in level.look.terrain_materials:item[3].set_shader_parameter("contact_shade_strength",.13)
		level.player.position=level.spawn_position
		level.set_review_view("gameplay")
		level.geometry.reset_cutaway_materials()
		level.geometry.update_cutaway(level.player.position,camera.position)
		await capture("variation_on")
		for item: Array in level.look.terrain_materials:item[3].set_shader_parameter("grass_variation_strength",0.0)
		await capture("variation_off")
		for item: Array in level.look.terrain_materials:item[3].set_shader_parameter("grass_variation_strength",.16)
		await capture("soil_on")
		for item: Array in level.look.terrain_materials:item[3].set_shader_parameter("plant_soil_strength",0.0)
		await capture("soil_off")
	level.queue_free();await process_frame
	quit()
