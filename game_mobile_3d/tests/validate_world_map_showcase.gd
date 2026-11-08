extends SceneTree
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"Project test bus starts muted before scene setup")
	var w=load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(w)
	await process_frame
	check(w.get("showcase")!=null,"Default WorldMap has showcase coordinator")
	if w.get("showcase")==null:w.free();quit(1);return
	check(w.showcase.private_primary,"Primary selection is private hybrid")
	check(w.player.get("using_original_source")==true,"Original reference rig loaded externally")
	check(w.player.get("hybrid_motion")!=null,"Approved hybrid motion loaded")
	check(w.player.skeleton.get_bone_count()==32,"32-joint rig retained")
	check(is_equal_approx(w.player.run_speed,7.),"Verified 7m/s speed retained")
	check(w.get_node_or_null("Combat")==null,"Incompatible pistol director not initialized")
	check(w.player.get("render_presenter")!=null,"Source pose presenter connected")
	for i in 18:await physics_frame
	print("SHOWCASE_STARTUP_STATE ",JSON.stringify({"floor":w.player.is_on_floor(),"floor_initialized":w.player._floor_initialized,"jump_phase":w.player._jump_stage,"clip":w.player.active_clip,"velocity":str(w.player.velocity)}))
	check(w.player.is_on_floor() and w.player._jump_stage.is_empty() and w.player.active_clip=="Idle","Startup settles into grounded Idle without input")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"Test audio muted by default")
	w.reset_player();Input.action_press("jump")
	var immediate_jump_landing:=false
	for i in 65:
		await physics_frame
		if i==2:Input.action_release("jump")
		immediate_jump_landing=immediate_jump_landing or w.player._jump_stage=="JumpLanding"
	check(immediate_jump_landing,"A genuine jump immediately after reset still plays Landing")
	check(not w.get_node("HUD/Help").visible,"Technical HUD hidden by default")
	check(not w.showcase.panel.visible,"Options hidden by default")
	check(w.look.stage==2,"Reference graphics stage default")
	if RenderingServer.get_rendering_device()!=null:check(w.look.day_finish_active(),"Combined Day finish default on Mobile")
	check(not w.terrain_sky.enabled,"Unfinished terrain cache optional")
	var vegetation_hidden:bool=not w.grove.visible
	for batch:MultiMeshInstance3D in w.geometry.vegetation_batches+w.geometry.accent_batches:
		vegetation_hidden=vegetation_hidden and not batch.is_visible_in_tree()
	check(vegetation_hidden,"Trees, schematic foliage, grass and flowers absent by default")
	check(not w.look.canopy_contact_active(),"No contact shading from removed vegetation")
	var trunks_disabled:=true
	for trunk:StaticBody3D in w.grove._trunks:trunks_disabled=trunks_disabled and trunk.collision_layer==0
	check(trunks_disabled,"Removed trees have no invisible trunk collisions")
	var leftover_root_cells:=0
	for y in w.look.path_map_image.get_height():
		for x in w.look.path_map_image.get_width():
			if w.look.path_map_image.get_pixel(x,y).a>1.:leftover_root_cells+=1
	check(leftover_root_cells==0,"Hidden vegetation leaves no root soil or plant contact masks")
	w.set_grove_visible(true,w.player.global_position)
	check(w.look.path_map_image.get_data()==w.look._planted_path_map_image.get_data(),"Vegetation comparison restores exact original ground field")
	w.set_grove_visible(false,w.player.global_position)
	w.showcase.set_audio_enabled(true)
	check(not AudioServer.is_bus_mute(0),"Audio can be explicitly enabled for review")
	w.showcase.set_audio_enabled(false)
	w.reset_player();check(w.player.position.distance_to(w.spawn_position)<.001,"Reset preserves authored spawn")
	w.player.effects.sample(.01,true,Vector3.ZERO,Vector3.UP,123)
	check(not w.player.effects.samples.is_empty(),"Reset test contains trail history")
	w.reset_player();check(w.player.effects.samples.is_empty(),"Reset clears prior blade trail")
	var sun:Vector3=w.get_node("Sun").rotation
	w.showcase.set_hour(22.)
	await process_frame
	check(w.get_node("Sun").rotation.distance_to(sun)>.01,"Night preview changes sun")
	check(not w.look.ground_bounce_active(),"No stale Day bounce at night")
	w.showcase.set_hour(12.)
	await process_frame
	check(w.get_node("Sun").rotation.distance_to(sun)<.00001,"Noon restores exact sun")
	w.set_review_view("overview")
	var overview_env:Environment=w.get_node("WorldEnvironment").environment
	var overview_fog:float=overview_env.fog_density
	w.showcase.set_hour(22.);w.showcase.set_hour(12.)
	check(is_equal_approx(overview_env.fog_density,overview_fog),"Night-Day restores current overview atmosphere")
	w.set_review_view("gameplay")
	w.showcase.compare_baseline()
	check(w.look.stage==0,"Comparison restores baseline")
	w.showcase.compare_baseline()
	check(w.look.stage==2,"Comparison restores combined look")
	if RenderingServer.get_rendering_device()!=null:
		check(w.look.local_exposure_active(),"Combined local exposure restored")
		check(is_equal_approx(w.look._exposure_effect._review_strength,.12),"Bounded scene profile survives comparison")
	print("WORLD_MAP_SHOWCASE_RESULT ",JSON.stringify({"failures":failures,"private":w.player.using_original_source,"clips":w.player.clips.size()}))
	w.free();await process_frame;await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
