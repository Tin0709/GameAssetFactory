extends SceneTree
## Native renderer smoke review of the existing encounter; no alternate scene.
var frames: Array[float]=[]
var process_ms: Array[float]=[]
var physics_ms: Array[float]=[]
func _initialize() -> void:call_deferred("run")
func percentile(values: Array[float],fraction: float) -> float:
	var sorted:=values.duplicate();sorted.sort()
	return sorted[mini(sorted.size()-1,int(sorted.size()*fraction))]
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var stage:=OS.get_environment("ZOMBIE_HIT_STAGE")
	var fps:=60 if args.has("60") else 30
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	root.add_child(scene);current_scene=scene;scene.player.scripted_input=true
	Engine.max_fps=fps
	var event:=InputEventKey.new();event.physical_keycode=KEY_E;event.pressed=true
	var saw_hit:=false;var max_angle:=0.;var max_corpses:=0;var captured_hit:=false;var captured_death:=false
	var shot_times: Array[float]=[];var last_shot:=0;var elapsed:=0.
	var fixed_feedback_nodes:=0
	for z in scene.zombie_combat.zombies:fixed_feedback_nodes+=z.damage_feedback.get_child_count()
	for i in int(fps*7.5):
		if i==int(fps*.3):scene._unhandled_input(event)
		await process_frame
		var dt:=get_process_time_delta();elapsed+=dt
		if i>fps:
			frames.append(dt*1000.)
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
			physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		if scene.rifle_fire.shots_fired>last_shot:
			last_shot=scene.rifle_fire.shots_fired;shot_times.append(elapsed)
		max_corpses=maxi(max_corpses,scene.zombie_combat.active_ragdolls())
		for z in scene.zombie_combat.zombies:
			if not z.is_dead:
				saw_hit=saw_hit or z.visual.hit_count>0
				max_angle=maxf(max_angle,z.visual.hit_rotation.length())
				if not captured_hit and z.visual.hit_rotation.length()>deg_to_rad(3.):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(stage+"/native_hit_"+str(fps)+".png");captured_hit=true
			elif not captured_death and z.corpse_age>=.22:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(stage+"/native_death_"+str(fps)+".png");captured_death=true
	var result:={"passed":saw_hit and captured_hit and captured_death and scene.zombie_combat.kills==4 and scene.rifle_fire.pool_misses==0,"target_fps":fps,"native_renderer":RenderingServer.get_current_rendering_method(),"physics_hz":Engine.physics_ticks_per_second,"shots":scene.rifle_fire.shots_fired,"kills":scene.zombie_combat.kills,"nonlethal_seen":saw_hit,"max_live_reaction_deg":rad_to_deg(max_angle),"max_corpses":max_corpses,"pool_misses":scene.rifle_fire.pool_misses,"fixed_feedback_children":fixed_feedback_nodes,"frame_median_ms":percentile(frames,.5),"frame_p95_ms":percentile(frames,.95),"script_process_p95_ms":percentile(process_ms,.95),"physics_p95_ms":percentile(physics_ms,.95)}
	print("NATIVE_ZOMBIE_HIT ",JSON.stringify(result))
	FileAccess.open(stage+"/native"+str(fps)+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	scene.free();quit(0 if result.passed else 1)
