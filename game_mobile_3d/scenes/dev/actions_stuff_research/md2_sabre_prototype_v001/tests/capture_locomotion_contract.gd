extends SceneTree
## Inspect existing full-grass lab gameplay; offline movie is not a benchmark.
var lab:Node3D
var actor:CharacterBody3D
var folder:=""
var trace:Array=[]
var frames:Array=[]
var recording:=false
var failures:Array[String]=[]
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-16000,-16000));call_deferred("run")
func sample()->void:
	if not recording:return
	var m:Dictionary=actor.movement_measurements()
	trace.append({"clock":actor.simulation_clock,"position":[actor.position.x,actor.position.y,actor.position.z],"speed":actor.current_speed,"clip":actor.active_clip,"clip_time":actor.animation_player.current_animation_position,"rate":actor._playback_speed,"combo":str(actor.combo.phase),"sole_height":m.sole_height,"sole_speed":m.sole_speed,"transition_elapsed":m.get("transition_elapsed_seconds"),"transition_duration":m.get("transition_wall_seconds")})
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
func shot(label:String)->void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder.path_join(label+".png"));frames.append(label)
func run()->void:
	Engine.physics_ticks_per_second=60
	lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab);current_scene=lab;actor=lab.player
	folder=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/contract_audit/native")
	DirAccess.make_dir_recursive_absolute(folder)
	actor.physics_pose_ready.connect(sample);await ticks(15);recording=true
	await shot("01_idle")
	Input.action_press("move_forward");await ticks(5);await shot("02_start_run");await ticks(55);await shot("03_cruise_run")
	Input.action_release("move_forward");Input.action_press("move_backward");await ticks(8);await shot("04_reverse_handoff");await ticks(35)
	Input.action_press("sprint");await ticks(15);await shot("05_walk");Input.action_release("sprint");await ticks(20)
	Input.action_release("move_backward");await ticks(20);await shot("06_stop")
	for i in 3:
		Input.action_press("move_forward");await ticks(3);Input.action_release("move_forward");await ticks(12)
	await shot("07_short_taps")
	Input.action_press("move_forward");await ticks(25)
	var key:=InputEventKey.new();key.physical_keycode=KEY_E;key.pressed=true;lab.sabre_mode.unhandled_input(key)
	await ticks(15);await shot("08_planted_attack");await ticks(100);key.pressed=false;lab.sabre_mode.input(key);await ticks(40)
	Input.action_press("jump");await ticks(1);Input.action_release("jump");await ticks(13);await shot("09_jump_unchanged");await ticks(35)
	Input.action_release("move_forward");await ticks(25);await shot("10_landed_idle");recording=false
	if actor.accepted_count<3:failures.append("Held combo did not execute")
	if not actor.is_on_floor() or actor.current_speed>.01:failures.append("End contact/stop")
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"grass_blocks":lab.grass_field_blocks,"bones":actor.skeleton.get_bone_count(),"source_clips":actor.source_clip_count,"frames":frames,"trace":trace,"failures":failures,"camera":lab.sabre_mode.camera_measurements(),"scope":"Our existing lab; controlled inputs, no calibration of MD2 from video. Offline fixed60fps is not performance evidence."}
	FileAccess.open(folder.path_join("native-contract-validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_NATIVE_CONTRACT ",JSON.stringify({"failures":failures,"frames":frames.size(),"samples":trace.size(),"renderer":report.renderer}))
	lab.free();await process_frame;quit(0 if failures.is_empty() else 1)
