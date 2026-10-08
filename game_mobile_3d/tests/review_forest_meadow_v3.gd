extends "res://tests/review_forest_quality.gd"
func run() -> void:
	default_profile_stage=2
	out="res://.validation/forest_meadow_v3"
	DirAccess.make_dir_recursive_absolute(out)
	level=load("res://scenes/ForestMeadowV3.tscn").instantiate()
	root.add_child(level);current_scene=level
	level.set_enemies_enabled(false)
	await tick(3)
	if "--no-grass-shadows" in OS.get_cmdline_user_args():level.set_grass_shadows(false)
	if "--no-haze" in OS.get_cmdline_user_args():level.set_atmosphere(false)
	stats={"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[root.size.x,root.size.y],"target_fps":30,"phone_verified":false,"art_approved":false,"missing_v3_assets":level.v3_missing_assets}
	stats["grass_shadows"]=level.review_grass_shadows
	stats["thin_haze"]=level.review_atmosphere
	stats["warmth"]=level.review_warmth
	if "--profile" in OS.get_cmdline_user_args():await profile()
	elif "--clip" in OS.get_cmdline_user_args():await movie()
	else:await matched()
	level.set_enemies_enabled(false);level.queue_free()
	for i in 3:await process_frame
	if "--profile" in OS.get_cmdline_user_args():await create_timer(.25).timeout
	quit()

func matched() -> void:
	await super.matched()
	# Freeze remains active: isolate real renderer bloom pixels from light changes.
	var environment: Environment=level.get_node("WorldEnvironment").environment
	await capture("bloom_on")
	environment.glow_enabled=false
	await capture("bloom_off")
	environment.glow_enabled=true
	await capture("grass_shadows_on")
	level.set_grass_shadows(false)
	await capture("grass_shadows_off")
	level.set_grass_shadows(true)
	await capture("haze_on")
	level.set_atmosphere(false)
	await capture("haze_off")
	level.set_atmosphere(true)
	await capture("warmth_on")
	var warmth: float=level.review_warmth
	level.set_warmth(0.0)
	await capture("warmth_off")
	level.set_warmth(warmth)
	stats["atmosphere"]={"mode":"depth","begin":environment.fog_depth_begin,"end":environment.fog_depth_end,"curve":environment.fog_depth_curve,"density":environment.fog_density,"color":str(environment.fog_light_color),"energy":environment.fog_light_energy,"sun_scatter":environment.fog_sun_scatter}
	stats["final_light"]={"sun":level.get_node("Sun").light_energy,"ambient":environment.ambient_light_energy,"exposure":environment.tonemap_exposure,"bloom":environment.glow_bloom,"glow_intensity":environment.glow_intensity,"glow_strength":environment.glow_strength,"glow_threshold":environment.glow_hdr_threshold}
	write_report("captures")
