extends SceneTree
var checks: Array=[]
var failures: Array=[]
var scene: Node
var fps:=30
var jump_peaks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func ticks(seconds: float, label: String) -> void:
	scene.section=label
	var end:=Engine.get_physics_frames()+int(round(seconds*60))
	while Engine.get_physics_frames()<end:await process_frame
func run() -> void:
	if "--fps60" in OS.get_cmdline_user_args():fps=60
	Engine.physics_ticks_per_second=60
	var path:="res://scenes/dev/SnappyLocomotionFastJumpTest.tscn"
	check(ResourceLoader.exists(path),"Separate fast/jump test preserves native-speed lab")
	if not ResourceLoader.exists(path):quit(1);return
	scene=load(path).instantiate();root.add_child(scene);current_scene=scene
	await process_frame
	var a=scene.actor;var v=a.visual;a.scripted_input=true
	check(a.has_method("request_jump"),"Existing Expressive jump controller reused")
	check(a.review_pace==2.25 and a.walk_motion_speed_scale==1.5 and a.run_motion_speed_scale==1.15,"Exact existing Expressive test pace/scales")
	check(a.jump_height==2.0 and a.jump_flight_speed==2.15,"Exact existing jump height and flight policy")
	check(scene.camera.size==11.25 and scene.camera.rotation_degrees.distance_to(Vector3(-36.315886,36.869898,0))<.01,"Exact existing gameplay camera angle and zoom")
	check(Vector2(scene.camera.position.x-a.position.x,scene.camera.position.z-a.position.z).distance_to(Vector2(12,16))<.01,"Exact existing camera distance and offset")
	for snappy in [true,false]:
		v.set_snappy(snappy);await ticks(.3,"Fast A/B Idle")
		a.requested_direction=Vector2.DOWN;a.requested_run=false
		await ticks(1.2,"Stable fast Walk")
		check(absf(a.current_speed-3.0375)<.04,"Walk matches actual existing test travel speed")
		check(v.gait_run_weight<.001,"Fast Walk does not accidentally select Run")
		a.requested_run=true;await ticks(1.3,"Stable fast Run")
		check(absf(a.current_speed-5.977875)<.04,"Run matches actual existing test travel speed")
		check(v.gait_run_weight>.999,"Fast Run reaches full source target")
		for mode in ["Run","Idle"]:
			if mode=="Idle":a.requested_direction=Vector2.ZERO;a.requested_run=false;await ticks(.9,"Before Idle jump")
			scene.section="%s jump style%s"%[mode,snappy]
			var before: int=a.jump_count;a.request_jump()
			var end:=Engine.get_physics_frames()+150;var peak:=0.0;var air:=false;var land:=false
			while Engine.get_physics_frames()<end:
				await process_frame
				peak=maxf(peak,a.position.y-a.floor_y)
				air=air or a.jump_state=="AIR";land=land or a.jump_state=="LAND"
			jump_peaks.append(peak)
			check(a.jump_count==before+1 and air and land,"%s jump launches and lands once in style%s"%[mode,snappy])
			check(peak>1.85 and peak<2.1,"Physics jump preserves existing2m height")
			check(a.jump_state=="GROUND","Jump recovers to locomotion/Idle")
			if mode=="Idle":check(v.last_sole[0].y<.002 and v.last_sole[1].y<.002,"Idle landing finishes both foot replants")
			scene._button("Reset");a.scripted_input=true
	for d in [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP]:
		a.requested_direction=d;a.requested_run=true;await ticks(.55,"Fast direction changes")
	a.requested_direction=Vector2.ZERO;await ticks(.9,"Fast settle")
	scene._button("Reset");a.scripted_input=true
	a.request_jump();await ticks(.3,"Reset in flight");scene._button("Reset")
	check(a.jump_state=="GROUND" and not v.settling,"Reset cancels jump and world-contact caches")
	var m: Dictionary=scene.measurements
	check(m.max_scale_error<.00001,"Rigid geometry unchanged at fast pace and during jumps")
	check(m.max_floor_penetration_m<.003,"No visible sole floor penetration through jump transitions")
	check(m.sections["Idle jump styletrue"].correction_clamps==0 and m.sections["Idle jump stylefalse"].correction_clamps==0,"Stationary landing/replant stays inside the rigid joint budget")
	check(m.steady_correction_clamps==0,"Fast steady gait stays inside existing contact limit")
	check(m.steady_support_speed_m_s<.05,"Fast steady planted feet remain stable")
	var out:="res://.validation/snappy_gameplay_v001";DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/fast_jump%d.json"%fps,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"measurements":m,"jump_peaks_m":jump_peaks,"render_fps":fps,"physics_fps":60,"telemetry":scene.telemetry},"\t"))
	print("FAST_JUMP_CHECKS ",checks.size()," FAILURES ",failures);quit(0 if failures.is_empty() else 1)
