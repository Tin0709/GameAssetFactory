extends SceneTree
## Inspect OUR lab and original private pose playback, never estimate MD2 parameters from pixels.
var lab:Node3D
var actor:CharacterBody3D
var folder:=""
var frames:Array[Dictionary]=[]
var failures:Array[String]=[]
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_position(Vector2i(-16000,-16000));call_deferred("run")
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
func capture(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
	frames.append({"name":label,"camera":lab.sabre_mode.camera_measurements(),"clip":actor.active_clip,"source_time":actor.animation_player.current_animation_position,"combo_time":actor.combo.time,"play_rate":actor._playback_speed,"y":actor.global_position.y,"velocity_y":actor.velocity.y,"blade_error":actor.marker_tip.global_position.distance_to(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor._weapon_attachment.bone_idx)*actor.marker_tip.transform.origin)})
func run()->void:
	Engine.physics_ticks_per_second=60
	lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(lab);current_scene=lab;actor=lab.player
	folder=actor.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/combat_camera");DirAccess.make_dir_recursive_absolute(folder)
	await ticks(30);await capture("01_launch_camera")
	actor.scripted_input=true;actor.attack(true);await ticks(7);await capture("02_attack1_rate1_2")
	if absf(actor._playback_speed-1.2)>.001:failures.append("Native first attack source rate")
	await ticks(40);await capture("03_attack3_rate1")
	if actor.active_clip!="Attack3" or absf(actor._playback_speed-1.)>.001:failures.append("Native finisher source rate")
	actor.attack(false);await ticks(90);lab.sabre_mode.reset();actor.scripted_input=true;await ticks(4)
	actor.requested_jump=true;await ticks(1);actor.requested_jump=false
	while actor.velocity.y>0.:await ticks(1)
	actor.attack(true);actor.attack(false);await ticks(9);await capture("04_aerial_downward_attack")
	while not actor._grounded:await ticks(1)
	await capture("05_real_floor_contact")
	await ticks(65);await capture("06_recovered_ready")
	# Exercise the UI's actual orbit input, then restore its recorded launch basis.
	var drag:=InputEventMouseButton.new();drag.button_index=MOUSE_BUTTON_MIDDLE;drag.pressed=true;lab.sabre_mode.unhandled_input(drag)
	var motion:=InputEventMouseMotion.new();motion.relative=Vector2(30,25);lab.sabre_mode.unhandled_input(motion);drag.pressed=false;lab.sabre_mode.input(drag);await ticks(5);await capture("07_orbit_diagnostic")
	var reset:=InputEventKey.new();reset.physical_keycode=KEY_F8;reset.pressed=true;lab.sabre_mode.unhandled_input(reset);await ticks(5);await capture("08_f8_camera_restored")
	if absf(lab.azimuth-.66)>.0001 or absf(lab.elevation-.4)>.0001 or absf(lab.camera_size-14.5)>.0001:failures.append("Native camera restore")
	var path:String=lab.sabre_mode.save_measurements();var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved.has("camera"):failures.append("Saved camera measurement provenance")
	var report:={"failures":failures,"frames":frames,"renderer":RenderingServer.get_current_rendering_method(),"grass_blocks":lab.grass_field_blocks,"original_bones":actor.skeleton.get_bone_count(),"original_clips":actor.source_clip_count,"audio_sources":lab.sabre_mode.reference_audio.available_count,"native_md2_camera_verified":false,"source_base_jump_physics_verified":false}
	FileAccess.open(folder.path_join("native-combat-camera.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SABRE_NATIVE_COMBAT_CAMERA ",JSON.stringify({"failures":failures,"frames":frames.size(),"renderer":report.renderer}))
	lab.free();await process_frame;quit(0 if failures.is_empty() else 1)
