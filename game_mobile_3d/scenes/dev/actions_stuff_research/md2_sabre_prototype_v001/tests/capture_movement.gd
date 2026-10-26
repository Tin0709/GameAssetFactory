extends SceneTree
## Native rendering/measurements of OUR existing lab. Never calibrates MD2 from video.
var lab:Node3D
var actor:CharacterBody3D
var mode:Node
var folder:=""
var frames:Array[Dictionary]=[]
var failures:Array[String]=[]
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	call_deferred("run")
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
func capture(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
	frames.append({"name":label,"measurements":actor.movement_measurements()})
func key(code:int,pressed:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func run()->void:
	Engine.physics_ticks_per_second=60
	lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.md2_sabre_prototype_enabled=true;root.add_child(lab);current_scene=lab
	actor=lab.player;mode=lab.sabre_mode
	folder=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/native")
	DirAccess.make_dir_recursive_absolute(folder)
	await ticks(30);await capture("01_idle_same_environment")
	actor.reset_movement_measurements();Input.action_press("move_forward");await ticks(120);await capture("02_normal_run7")
	if absf(actor.current_speed-7.)>.02 or absf(actor._playback_speed-1.25)>.001:failures.append("Native normal pace/cadence")
	Input.action_press("move_right");await ticks(30);await capture("03_diagonal7")
	if absf(actor.current_speed-7.)>.02:failures.append("Native diagonal pace")
	Input.action_press("sprint");await ticks(30);await capture("04_slow_walk2")
	if absf(actor.current_speed-2.)>.02:failures.append("Native slow Walk")
	Input.action_release("sprint");Input.action_release("move_right");await ticks(18)
	var rmb:=InputEventMouseButton.new();rmb.button_index=MOUSE_BUTTON_RIGHT;rmb.pressed=true;mode.unhandled_input(rmb);await ticks(18);await capture("05_ready_movement7")
	key(KEY_E,true);await ticks(12);await capture("06_moving_attack_adapter");await ticks(90);key(KEY_E,false)
	Input.action_release("move_forward");rmb.pressed=false;mode.input(rmb);await ticks(60);await capture("07_stopped_recovery")
	if actor.current_speed>.01:failures.append("Native braking settles")
	Input.action_press("jump");await ticks(1);Input.action_release("jump");await ticks(20);await capture("08_jump_unchanged_adapter");await ticks(65)
	var saved:String=actor.save_movement_measurements()
	if saved.is_empty():failures.append("Private Research measurement export")
	var cadence_trials:Array[Dictionary]=[]
	for reference:float in [7.,5.6]:
		mode.reset();actor.run_stride_speed=reference;await ticks(4);Input.action_press("move_forward");await ticks(30);actor.reset_movement_measurements();await ticks(260)
		var trial:Dictionary=actor.movement_measurements();trial["trial"]="target-normalized1x counterfactual" if reference==7. else "distance/stride adapter"
		Input.action_release("move_forward");await ticks(20);trial["release_stop"]=actor.movement_measurements();cadence_trials.append(trial)
	actor.run_stride_speed=5.6;mode.reset()
	var report:={"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"scene":"res://scenes/dev/ActionsStuffWalkRunTest.tscn","camera_preserved":{"size":lab.camera_size,"azimuth":lab.azimuth,"elevation":lab.elevation},"grass_blocks":lab.grass_field_blocks,"original_clips":actor.source_clip_count,"bones":actor.skeleton.get_bone_count(),"frames":frames,"cadence_trials":cadence_trials,"export":saved,"native_md2_runtime_values_verified":false}
	FileAccess.open(folder.path_join("native-validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SABRE_NATIVE_MOVEMENT ",JSON.stringify({"failures":failures,"renderer":report.renderer,"frames":frames.size(),"export":saved}))
	lab.free();await process_frame;quit(0 if failures.is_empty() else 1)
