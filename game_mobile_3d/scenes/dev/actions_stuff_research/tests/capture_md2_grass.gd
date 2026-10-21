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
var viewport:SubViewport
func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args();out=args[0];fps=int(args[1]);capture=args.has("capture")
	var short_preview:=args.has("short");var duration:=6 if short_preview else 12
	Engine.max_fps=fps
	# Offscreen native GPU target keeps capture independent of which editor window
	# the user is operating; it still instantiates the exact existing lab scene.
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	level=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();viewport.add_child(level);current_scene=level
	level.player.scripted_input=true
	for zombie in level.zombie_combat.zombies:
		zombie.target=null;zombie.move_speed=0.
	# Overview documents complete population; the gameplay camera remains the approved one.
	level.grass_overview=true;level._update_camera()
	for i in 12:await process_frame
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(out+"/overview.png")
	level.grass_overview=false;level._camera_initialized=false;level._update_camera()
	for i in 12:await process_frame
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(out+"/gameplay.png")
	previous=Time.get_ticks_usec()
	var first_clock:float=level.grass_field.clock
	for f in duration*fps:
		var t:=float(f)/float(fps);var actor=level.player
		actor.requested_direction=Vector2.ZERO;actor.requested_run=false
		if t>=2. and t<5.:actor.requested_direction=Vector2(1,.1).normalized()
		if t>=5. and t<7.:actor.requested_direction=Vector2(-.8,-.6).normalized();actor.requested_run=true
		if t>=7. and t<8.5:actor.requested_direction=Vector2(.2,1.).normalized()
		if short_preview:
			actor.requested_direction=Vector2.ZERO;actor.requested_run=false
			if t>=.8 and t<2.5:actor.requested_direction=Vector2(1,.15).normalized()
			if t>=2.5 and t<3.5:actor.requested_direction=Vector2(-1,-.2).normalized();actor.requested_run=true
			if t>=3.5 and t<4.2:actor.requested_direction=Vector2(.2,1).normalized()
		actor.requested_jump=f==int(7.1*fps)
		if f==int(9.2*fps):level._fire_key_held=true;level._sync_rifle_controls()
		if f==int(11.*fps):level._fire_key_held=false;level._sync_rifle_controls()
		await process_frame;RenderingServer.force_draw(false)
		var now:=Time.get_ticks_usec();times.append((now-previous)/1000.);previous=now
		field_times.append(level.grass_field.interaction.update_usec);active_max=maxi(active_max,level.grass_field.interaction.active.size())
		if capture:viewport.get_texture().get_image().save_png(out+("/frame_%04d.png"%f))
		elif f in [int(2.8*fps),int(5.6*fps),int(7.5*fps),int(10.*fps)]:viewport.get_texture().get_image().save_png(out+("/view_%04d.png"%f))
	times.sort();field_times.sort()
	var report:={"fps_target":fps,"frames":duration*fps,"capture_readback_each_frame":capture,"median_frame_ms":times[times.size()/2],"p95_frame_ms":times[int(times.size()*.95)],
		"field_update_median_usec":field_times[field_times.size()/2],"field_update_p95_usec":field_times[int(field_times.size()*.95)],"peak_active_cells":active_max,
		"clumps":level.grass_field.instance_count,"batches":level.grass_field.batch_count,"walk_speed":level.player.walk_speed,"run_speed":level.player.run_speed,
		"shots":level.rifle_fire.shots_fired,"pool_misses":level.rifle_fire.pool_misses,"renderer":RenderingServer.get_current_rendering_method(),"simulated_seconds":level.grass_field.clock-first_clock}
	# Freeze actor/camera/wind time. Only the requested shader contribution changes.
	paused=true
	for material in level.grass_field.materials:material.set_shader_parameter("interaction_strength",0.)
	await process_frame;RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(out+"/contact_off.png")
	for material in level.grass_field.materials:material.set_shader_parameter("interaction_strength",1.)
	await process_frame;RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(out+"/contact_on.png")
	for material in level.grass_field.materials:
		material.set_shader_parameter("interaction_strength",0.);material.set_shader_parameter("wind_strength",0.)
	await process_frame;RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(out+"/wind_off.png")
	for material in level.grass_field.materials:material.set_shader_parameter("wind_strength",1.)
	await process_frame;RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(out+"/wind_on.png")
	paused=false
	FileAccess.open(out+"/native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("NATIVE_MD2_GRASS ",JSON.stringify(report))
	level.free();level=null;viewport.free();viewport=null
	for i in 4:await process_frame
	quit()
