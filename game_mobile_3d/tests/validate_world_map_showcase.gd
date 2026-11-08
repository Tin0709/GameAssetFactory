extends SceneTree
var failures:Array[String]=[]
func check(value:bool,message:String)->void:
	if not value:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
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
	check(not w.get_node("HUD/Help").visible,"Technical HUD hidden by default")
	check(not w.showcase.panel.visible,"Options hidden by default")
	check(w.look.stage==2,"Reference graphics stage default")
	if RenderingServer.get_rendering_device()!=null:check(w.look.day_finish_active(),"Combined Day finish default on Mobile")
	check(not w.terrain_sky.enabled,"Unfinished terrain cache optional")
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
