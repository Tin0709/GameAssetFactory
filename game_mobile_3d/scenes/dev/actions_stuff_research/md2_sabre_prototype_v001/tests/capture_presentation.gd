extends SceneTree
## Our native display continuity probe, not an MD2 video measurement.
## Invoke with --fixed-fps 144; the normal lab cap is120, not this virtual clock.
var lab:Node3D
var a:CharacterBody3D
var mode:Node
var folder:=""
var failures:Array[String]=[]
func _initialize()->void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-16000,-16000));call_deferred("run")
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
func capture(name:String)->void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run()->void:
	Engine.physics_ticks_per_second=60
	lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();lab.md2_sabre_prototype_enabled=true;root.add_child(lab);current_scene=lab
	a=lab.player;mode=lab.sabre_mode
	folder=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/presentation")
	DirAccess.make_dir_recursive_absolute(folder);await ticks(30)
	Input.action_press("move_forward");await ticks(30)
	var p=mode.render_presenter;var previous:Vector3=p.last_uploaded_actor;var physical:Vector3=a.global_position;var last_frame:int=p.presented_frames
	var display_steps:Array[float]=[];var physics_steps:Array[float]=[];var alphas:Array[float]=[]
	var display_speeds:Array[float]=[];var sampled_frame_gaps:Array[int]=[]
	for i in 144:
		await process_frame;await RenderingServer.frame_post_draw
		var gap:int=p.presented_frames-last_frame
		var step:Vector3=p.last_uploaded_actor-previous
		display_steps.append(step.length());physics_steps.append(a.global_position.distance_to(physical));alphas.append(p.render_alpha)
		display_speeds.append(Vector2(step.x,step.z).length()/(float(gap)/144.) if gap>0 else 0.);sampled_frame_gaps.append(gap)
		previous=p.last_uploaded_actor;physical=a.global_position;last_frame=p.presented_frames
	await capture("01_run_native100_smooth")
	var held_display:=0;var held_physics:=0;var display_max:=0.;var physical_max:=0.
	for i in display_steps.size():
		if display_steps[i]<.00001:held_display+=1
		if physics_steps[i]<.00001:held_physics+=1
		display_max=maxf(display_max,display_steps[i]);physical_max=maxf(physical_max,physics_steps[i])
	var speed_error:=0.
	for i in range(2,display_speeds.size()):speed_error=maxf(speed_error,absf(display_speeds[i]-7.))
	if held_display!=0 or held_physics<20 or speed_error>.02:failures.append("Fractional display did not retain smooth7-unit travel across actual presented-frame gaps")
	Input.action_release("move_forward");await ticks(20)
	a.set_physics_process(false);mode.set_physics_process(false);lab.set_process(false);p.prepare(1.)
	lab.camera_size=5.4;lab._camera_initialized=false;lab._update_camera(1./60.,p.display_actor)
	var frozen:Transform3D=a.skeleton.get_bone_global_pose(0)
	mode.set_native_pixels(false);await process_frame;await process_frame;await capture("02_same_pose_medium85")
	var low:float=root.scaling_3d_scale
	mode.set_native_pixels(true);await process_frame;await process_frame;await capture("03_same_pose_native100")
	if a.skeleton.get_bone_global_pose(0)!=frozen:failures.append("Resolution A/B altered skeleton")
	var report:={"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"physics_hz":60,"render_sample_hz":144,"not_a_performance_benchmark":true,"frames":display_steps.size(),"held_display_frames":held_display,"held_physics_frames":held_physics,"maximum_display_step":display_max,"maximum_physics_step":physical_max,"maximum_normalized_display_speed_error":speed_error,"sampled_frame_gaps":sampled_frame_gaps,"display_speeds":display_speeds,"render_alphas":alphas,"display_steps":display_steps,"physics_steps":physics_steps,"viewport_scale":root.scaling_3d_scale,"medium_comparison_scale":low,"taa":root.use_taa,"screen_aa":root.screen_space_aa,"physics_and_animation_unmodified":true,"source_clips":a.source_clip_count,"source_bones":a.skeleton.get_bone_count()}
	FileAccess.open(folder.path_join("native-presentation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SABRE_NATIVE_PRESENTATION ",JSON.stringify({"failures":failures,"held_display":held_display,"held_physics":held_physics,"maximum_display_step":display_max,"maximum_physics_step":physical_max,"scale":root.scaling_3d_scale,"taa":root.use_taa}))
	lab.free();await process_frame;quit(0 if failures.is_empty() else 1)
