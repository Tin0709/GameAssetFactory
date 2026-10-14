extends SceneTree
var checks: Array=[]
var failures: Array=[]
var scene: Node
var metrics: Dictionary={}
var fps:=30
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
	var path:="res://scenes/dev/SnappyLocomotionTest.tscn"
	check(ResourceLoader.exists(path),"Separate playable Snappy scene exists")
	if not ResourceLoader.exists(path):quit(1);return
	scene=load(path).instantiate();root.add_child(scene);current_scene=scene
	await process_frame
	var actor=scene.actor
	var v=actor.visual
	actor.scripted_input=true
	check(actor.review_pace==1.0,"Original-speed travel/gait and normal Idle")
	check(v.snappy_clips.size()==2 and v.expressive_clips.size()==3,"Both Snappy clips and unchanged approved Expressive library loaded")
	check(not v.animation_player.is_playing() and not v.bounce_enabled,"One pose writer; imported player stopped; no extra procedural bounce")
	check(not actor.has_method("request_jump"),"Locomotion-only test, no other animation work")
	var idle_start: float=v.attention_time
	await ticks(.5,"Idle")
	check(absf(v.attention_time-idle_start-.5)<.06,"Approved Idle continues at1x independently of gait")
	for snappy in [true,false]:
		v.set_snappy(snappy)
		await ticks(.35,"A/B idle")
		for direction in [Vector2.DOWN,Vector2.RIGHT]:
			var start: Vector3=actor.position
			actor.requested_direction=direction
			await ticks(.05,"Input response")
			check(actor.position.distance_to(start)>.001,"Movement responds immediately: style%s"%snappy)
			await ticks(1.1,"Stable Walk %s"%snappy)
			check(absf(actor.current_speed-1.59936)<.03,"Matched Walk travel speed: style%s"%snappy)
			check(v.gait_run_weight<.001,"Full Walk target reached: style%s"%snappy)
			var expected_stride: float=1.59936*.7 if snappy else 1.08
			check(absf(v.gait_frequency-actor.current_speed/expected_stride)<.015,"Walk cadence follows actual travel: style%s"%snappy)
			var phase: float=v.gait_phase
			actor.requested_run=true
			await ticks(.05,"Walk to Run")
			check(fposmod(v.gait_phase-phase,1)<.15,"Walk-Run preserves gait phase")
			await ticks(1.25,"Stable Run %s"%snappy)
			check(absf(actor.current_speed-2.5)<.03,"Matched Run travel speed: style%s"%snappy)
			check(v.gait_run_weight>.999,"Unblended Run reached; not diluted by persistent Walk")
			check(scene.measurements.sections["Stable Run %s"%snappy].latest_body_target_error_m<.003,"Steady body bounce preserves the source target without extra damping")
			expected_stride=2.5*17/30.0 if snappy else 1.54
			check(absf(v.gait_frequency-2.5/expected_stride)<.015,"Run cadence follows actual travel: style%s"%snappy)
			actor.requested_run=false
			await ticks(.7,"Run to Walk")
			actor.requested_direction=Vector2.ZERO
			await ticks(.85,"Stop and replant")
			check(not v.move_requested and not v.settling,"Stop returns to planted Idle without delaying controls")
			check(v.last_sole[0].y<.002 and v.last_sole[1].y<.002,"Both feet planted after stop: %s / %s settling%s phase%s"%[v.last_sole[0],v.last_sole[1],v.settling,v.gait_phase])
	actor.requested_direction=Vector2.DOWN;actor.requested_run=true
	await ticks(.6,"Run before A/B")
	for enabled in [true,false,true,false,true]:
		var phase: float=v.gait_phase
		v.set_snappy(enabled)
		check(v.gait_phase==phase,"A/B never resets gait phase or capsule")
		await ticks(.6,"Moving A/B")
	for direction in [Vector2.UP,Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]:
		actor.requested_direction=direction
		await ticks(.5,"90/180-degree change")
	for i in 12:
		actor.requested_direction=Vector2.RIGHT if i%2==0 else Vector2.LEFT
		await ticks(.10,"Rapid reversals")
	actor.requested_direction=Vector2.ZERO;actor.requested_run=false
	await ticks(1.0,"Final settle")
	for stop_time in [.16,.36]:
		actor.scripted_input=true;actor.requested_direction=Vector2.DOWN
		await ticks(.65,"Reset setup")
		actor.requested_direction=Vector2.ZERO
		await ticks(stop_time,"Reset during replant")
		check(v.settling,"Reset fixture reaches the selected half-replant")
		var selected_style: bool=v.snappy_enabled
		scene._button("Reset")
		check(not v.settling,"Reset cancels old world-space replant targets")
		await ticks(.05,"Reset result")
		check(actor.position.length()<.01 and v.last_sole[0].y<.002 and v.last_sole[1].y<.002,"Reset places capsule and both feet at the origin")
		check(v.snappy_enabled==selected_style,"Reset preserves selected A/B style")
	metrics=scene.measurements
	check(metrics.max_floor_penetration_m<.002,"Feet stay above flat floor within2mm tolerance")
	check(metrics.max_scale_error<.00001,"Rigid block proportions preserved")
	check(metrics.steady_support_speed_m_s<.04,"Steady planted-foot sliding below4cm/s")
	check(metrics.steady_correction_clamps==0,"No contact correction caps reached in steady gait")
	check(metrics.sections["90/180-degree change"].correction_clamps==0,"Directional support stays inside the rigid joint limit")
	check(metrics.sections["Rapid reversals"].correction_clamps==0,"Rapid reversals avoid contact correction caps")
	check(metrics.style_toggles>=6,"A/B exercised during idle and movement")
	check(v.pose_sequence<=Engine.get_process_frames()+20,"Pose evaluated once per rendered physics update")
	var out:="res://.validation/snappy_gameplay_v001"
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/runtime%d.json"%fps,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"measurements":metrics,"telemetry":scene.telemetry,"render_fps":fps,"physics_fps":60,"engine":Engine.get_version_info()},"\t"))
	print("SNAPPY_CHECKS ",checks.size()," FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
