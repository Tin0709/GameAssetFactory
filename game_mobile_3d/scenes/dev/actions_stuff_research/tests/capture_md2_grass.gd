extends SceneTree
## Native Mobile pixels from the EXISTING lab. Test input is not saved gameplay.
var level:Node3D
var out:String
var frames:=0
var fps:=30
var capture:=false
var previous:=0
var times:Array[float]=[]
var field_times:Array[int]=[]
var active_max:=0
func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args();out=args[0];fps=int(args[1]);capture=args.has("capture")
	Engine.max_fps=fps
	level=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(level);current_scene=level
	level.player.scripted_input=true
	for zombie in level.zombie_combat.zombies:
		zombie.target=null;zombie.move_speed=0.
	# Overview documents complete population; the gameplay camera remains the approved one.
	level.grass_overview=true;level._update_camera()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/overview.png")
	level.grass_overview=false;level._camera_initialized=false;level._update_camera()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/gameplay.png")
	previous=Time.get_ticks_usec()
	for f in 12*fps:
		var t:=float(f)/float(fps);var actor=level.player
		actor.requested_direction=Vector2.ZERO;actor.requested_run=false
		if t>=2. and t<5.:actor.requested_direction=Vector2(1,.1).normalized()
		if t>=5. and t<7.:actor.requested_direction=Vector2(-.8,-.6).normalized();actor.requested_run=true
		if t>=7. and t<8.5:actor.requested_direction=Vector2(.2,1.).normalized()
		actor.requested_jump=f==int(7.1*fps)
		if f==int(9.2*fps):level._fire_key_held=true;level._sync_rifle_controls()
		if f==int(11.*fps):level._fire_key_held=false;level._sync_rifle_controls()
		await process_frame;await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();times.append((now-previous)/1000.);previous=now
		field_times.append(level.grass_field.interaction.update_usec);active_max=maxi(active_max,level.grass_field.interaction.active.size())
		if capture:root.get_texture().get_image().save_png(out+("/frame_%04d.png"%f))
		elif f in [int(2.8*fps),int(5.6*fps),int(7.5*fps),int(10.*fps)]:root.get_texture().get_image().save_png(out+("/view_%04d.png"%f))
	times.sort();field_times.sort()
	var report:={"fps_target":fps,"frames":12*fps,"capture_readback_each_frame":capture,"median_frame_ms":times[times.size()/2],"p95_frame_ms":times[int(times.size()*.95)],
		"field_update_median_usec":field_times[field_times.size()/2],"field_update_p95_usec":field_times[int(field_times.size()*.95)],"peak_active_cells":active_max,
		"clumps":level.grass_field.instance_count,"batches":level.grass_field.batch_count,"walk_speed":level.player.walk_speed,"run_speed":level.player.run_speed,
		"shots":level.rifle_fire.shots_fired,"pool_misses":level.rifle_fire.pool_misses,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(out+"/native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("NATIVE_MD2_GRASS ",JSON.stringify(report));level.free();quit()
