extends SceneTree
## Native viewport evidence from the same playable lab and real Input actions.
## Off-screen/unfocusable background window; no desktop or editor automation.
const OUTPUT:="res://.validation/md2_sabre_prototype_v001/"
var lab:Node3D
var actor:CharacterBody3D
var mode:Node
var frames:Array[Dictionary]=[]
var output_path:=OUTPUT
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	call_deferred("run")
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
func capture(label:String)->void:
	await RenderingServer.frame_post_draw
	var path:=output_path.path_join(label+".png")
	var image:=root.get_texture().get_image();image.save_png(path)
	frames.append({"name":label,"clip":actor.active_clip,"position":[actor.position.x,actor.position.y,actor.position.z],"accepted":actor.accepted_count,"gates":actor.impact_count,"focus":actor.focus_value,"blink":actor.blink_value,"image":ProjectSettings.globalize_path(path)})
func key(code:int,pressed:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func wait_for_clip(clip:String,limit:int=180)->void:
	for i in limit:
		if actor.active_clip==clip:return
		await ticks(1)
	push_error("Native capture did not reach "+clip);quit(1)
func run()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Engine.physics_ticks_per_second=60
	lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.md2_sabre_prototype_enabled=true;root.add_child(lab);current_scene=lab
	actor=lab.player;mode=lab.sabre_mode
	if actor.using_private_skin:
		output_path=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/godot_native/source_v003" if actor.using_original_source else "reports/prototype_sabre/godot_native")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
	await ticks(12);await capture("00_same_lab_wide_idle")
	lab.camera_size=5.4;lab._camera_initialized=false;await ticks(8);await capture("01_idle")
	Input.action_press("move_right");await ticks(22);await capture("02_walk")
	Input.action_press("sprint");await ticks(18);await capture("03_run")
	mode.reset();await ticks(5);Input.action_press("jump");await ticks(1);Input.action_release("jump");await ticks(10);await capture("04_jump_takeoff")
	await wait_for_clip("JumpAirborne");await ticks(2);await capture("05_jump_airborne")
	await wait_for_clip("JumpLanding");await ticks(3);await capture("06_landing")
	mode.reset();await ticks(5)
	var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true;mode.unhandled_input(right)
	Input.action_press("move_right");await ticks(18);await capture("07_combat_strafe")
	# A controlled +Z facing query isolates anatomical left/right/back while the
	# real movement Input actions and production actor/controller remain active.
	mode.reset();mode.set_physics_process(false);await ticks(4);actor.combat_requested=true;actor.has_aim_point=true;actor.aim_point=Vector3(0,0,20)
	Input.action_press("move_right");await ticks(18);await capture("07a_calibrated_left")
	Input.action_release("move_right");Input.action_press("move_left");await ticks(24);await capture("07b_calibrated_right")
	Input.action_release("move_left");Input.action_press("move_forward");await ticks(24);await capture("07c_calibrated_back")
	Input.action_press("sprint");await ticks(18);await capture("07d_calibrated_back_sprint")
	Input.action_release("move_forward");Input.action_release("sprint");await ticks(2);await capture("07e_braking_run")
	await ticks(14);await capture("07f_settled_idle")
	mode.set_physics_process(true)
	mode.reset();await ticks(5);key(KEY_E,true);await ticks(7);await capture("08_attack1_trail")
	await ticks(31);await capture("09_attack2_trail")
	await ticks(33);await capture("10_attack3_trail");key(KEY_E,false)
	await ticks(31);await capture("11_recovery3")
	mode.reset();lab.camera_size=3.8;lab._camera_initialized=false;actor.expression_mode=2;mode.expression.select(2);await ticks(45);await capture("12_face_focused")
	actor.expression_mode=1;mode.expression.select(1);await ticks(30);actor.force_blink();await ticks(5);await capture("13_face_blink")
	await ticks(12);await capture("14_face_neutral")
	# Show movement -> jump -> held combo in a continuous final playable segment.
	mode.reset();lab.camera_size=6.;lab._camera_initialized=false;actor.expression_mode=0;mode.expression.select(0)
	Input.action_press("move_forward");await ticks(35);Input.action_press("sprint");await ticks(45)
	Input.action_press("jump");await ticks(1);Input.action_release("jump");await ticks(45)
	Input.action_release("move_forward");Input.action_release("sprint");await ticks(15);key(KEY_E,true);await ticks(95);key(KEY_E,false);await ticks(65)
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_video_adapter_api_version(),"appearance":actor.appearance_label,"source_sha256":FileAccess.get_sha256(actor.private_model_path()) if actor.using_private_skin else "","frames":frames,"final_accepted":actor.accepted_count,"final_gates":actor.impact_count}
	FileAccess.open(OUTPUT+"native-captures.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_NATIVE_CAPTURES ",JSON.stringify(report));lab.free()
	for i in 3:await RenderingServer.frame_post_draw
	quit(0)
