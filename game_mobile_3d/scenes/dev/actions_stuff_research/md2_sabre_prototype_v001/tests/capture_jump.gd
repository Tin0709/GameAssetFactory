extends SceneTree
## Captures OUR playable jump; no native MD2 timing is inferred from images.
var lab:Node3D
var actor:CharacterBody3D
var folder:=""
var frames:Array[Dictionary]=[]
var trials:Array[Dictionary]=[]
var failures:Array[String]=[]
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-16000,-16000));call_deferred("run")
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
	frames.append({"name":label,"elapsed":actor.simulation_clock,"y":actor.position.y,"vertical_speed":actor.velocity.y,"clip":actor.active_clip,"rate":actor._playback_speed,"camera":lab.sabre_mode.camera_measurements()})
func run()->void:
	Engine.physics_ticks_per_second=60
	lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab);current_scene=lab;actor=lab.player
	folder=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/jump");DirAccess.make_dir_recursive_absolute(folder)
	await ticks(20);var responsive_gravity:float=actor.gravity
	for gravity:float in [15.,responsive_gravity]:
		var label:="before" if gravity==15. else "responsive"
		lab.sabre_mode.reset();actor.gravity=gravity;actor.scripted_input=true;await ticks(5)
		var start:float=actor.simulation_clock;var peak:=0.;var apex:=0.;var track:Array[Dictionary]=[]
		actor.requested_jump=true;await ticks(1);actor.requested_jump=false
		for frame in 70:
			var elapsed:float=actor.simulation_clock-start
			track.append({"t":elapsed,"y":actor.position.y,"vy":actor.velocity.y,"phase":actor._jump_stage,"clip":actor.active_clip,"source_time":actor.animation_player.current_animation_position,"camera_y":lab.camera_anchor.y})
			if actor.position.y>peak:peak=actor.position.y;apex=elapsed
			if frame in [5,13,21,31,39]:await shot(label+"_%02d"%frame)
			if actor._grounded:
				trials.append({"profile":label,"gravity":gravity,"up_seconds":apex,"down_seconds":elapsed-apex,"flight_seconds":elapsed,"height":peak,"track":track});break
			await ticks(1)
	actor.gravity=responsive_gravity;lab.sabre_mode.reset();actor.scripted_input=true;actor.requested_direction=Vector2(0,-1);actor.requested_run=true;await ticks(30)
	actor.requested_jump=true;await ticks(1);actor.requested_jump=false
	while not actor._grounded:await ticks(1)
	await ticks(5);await shot("moving_landing_resumed_run")
	if actor.active_clip!="Run" or absf(actor.current_speed-7.)>.01:failures.append("Moving landing failed to release into7-unit Run")
	if trials.size()!=2 or trials[1].flight_seconds>=trials[0].flight_seconds*.7:failures.append("Native responsive ordinary jump did not shorten flight")
	var report:={"failures":failures,"trials":trials,"frames":frames,"renderer":RenderingServer.get_current_rendering_method(),"grass_blocks":lab.grass_field_blocks,"source_clips":actor.source_clip_count,"bones":actor.skeleton.get_bone_count(),"native_md2_physics_recovered":false}
	FileAccess.open(folder.path_join("native-jump.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SABRE_NATIVE_JUMP ",JSON.stringify({"failures":failures,"trials":trials.map(func(t:Dictionary)->Dictionary:return {"profile":t.profile,"flight_seconds":t.flight_seconds,"height":t.height}),"frames":frames.size()}))
	lab.free();await process_frame;quit(0 if failures.is_empty() else 1)
