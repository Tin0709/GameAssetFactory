extends SceneTree
## Native inspection of OUR lab; no native MD2 values inferred from pixels.
var lab:Node3D
var a:CharacterBody3D
var folder:=""
var recording:=false
var records:Array[Dictionary]=[]
var frames:Array[String]=[]
var failures:Array[String]=[]
var previous_position:=Vector3.ZERO
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-16000,-16000));call_deferred("run")
func ticks(n:int)->void:
	for i in n:await physics_frame
	await process_frame
func sample()->void:
	if not recording:return
	var travel:=Vector2(a.position.x-previous_position.x,a.position.z-previous_position.z).length();previous_position=a.position
	var bones:Dictionary={};var rig:Skeleton3D=a.skeleton
	for name:String in ["J_Spine","J_Head"]:
		var bone:=rig.find_bone(name);var skin:Basis=(rig.get_bone_global_pose(bone)*rig.get_bone_global_rest(bone).affine_inverse()).basis
		var up:=skin.y.normalized();bones[name]=[rad_to_deg(atan2(up.x,up.y)),rad_to_deg(atan2(-up.z,up.y))]
	records.append({"x":a.position.x,"z":a.position.z,"speed":a.current_speed,"clip":a.active_clip,"phase":str(a.combo.phase),"travel":travel,"bones":bones})
func shot(label:String)->void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder.path_join(label+".png"));frames.append(label)
func run()->void:
	Engine.physics_ticks_per_second=60;lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab);current_scene=lab;a=lab.player;a.physics_pose_ready.connect(sample)
	folder=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/ground_combat");DirAccess.make_dir_recursive_absolute(folder)
	await ticks(20);var trials:Array[Dictionary]=[]
	for enabled:bool in [false,true]:
		lab.sabre_mode.reset();a.set_body_stability(enabled);await ticks(4);Input.action_press("move_forward");await ticks(30)
		records.clear();recording=true;await ticks(75);recording=false;trials.append({"stability_enabled":enabled,"trace":records.duplicate(true)});await shot("01_raw_run" if not enabled else "02_stable_run")
		Input.action_release("move_forward")
	lab.sabre_mode.reset();a.set_body_stability(true);await ticks(4);Input.action_press("move_forward");await ticks(30)
	var start:Vector3=a.position;previous_position=a.position;records.clear();recording=true
	var press:=InputEventKey.new();press.physical_keycode=KEY_E;press.pressed=true;lab.sabre_mode.unhandled_input(press)
	await ticks(6);await shot("03_held_sabre_no_skate")
	while a.combo.phase!=&"step":await ticks(1)
	await ticks(4);await shot("05_move_between_strikes");await ticks(105);recording=false
	var attack_trace:Array=records.duplicate(true);var drift:=0.;var step_travel:=0.
	for frame:Dictionary in attack_trace:
		if frame.phase=="step":step_travel+=float(frame.travel)
		else:drift+=float(frame.travel)
	if drift>.005 or step_travel<=.1:failures.append("Native strike/move travel ownership")
	var held_net:=Vector2(a.position.x-start.x,a.position.z-start.z).length()
	press.pressed=false;lab.sabre_mode.input(press);await ticks(65);await shot("04_release_resumes_run")
	if a.active_clip!="Run" or absf(a.current_speed-7.)>.01:failures.append("Native movement release")
	Input.action_release("move_forward");await ticks(20)
	var report:={"failures":failures,"frames":frames,"trials":trials,"held_attack_travel":drift,"movement_break_travel":step_travel,"held_input_net_travel":held_net,"attack_trace":attack_trace,"renderer":RenderingServer.get_current_rendering_method(),"grass_blocks":lab.grass_field_blocks,"bones":a.skeleton.get_bone_count(),"clips":a.source_clip_count,"camera":lab.sabre_mode.camera_measurements(),"native_md2_graph_verified":false}
	FileAccess.open(folder.path_join("native-ground-combat.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SABRE_NATIVE_GROUND ",JSON.stringify({"failures":failures,"held_attack_travel":drift,"frames":frames.size()}))
	lab.free();await process_frame;quit(0 if failures.is_empty() else 1)
