extends SceneTree
## Both-lead phase sweeps use final displayed poses and the same inputs in A/B.
var scene: Node
var monitor: PoseMonitor
var checks: Array=[]
var failures: Array=[]
var results: Dictionary={}
var fps:=30
var review_key:=""

class PoseMonitor extends Node:
	var lab: Node
	var key:=""
	var rows: Dictionary={}
	var sequence:=-1
	var previous: Array=[]
	var last_sole: Array=[]
	var last_ids: Array=[]
	var last_support: Array=[]
	var reset_pending:=true
	func _process(_delta: float) -> void:
		var v=lab.actor.visual
		if key=="" or sequence==v.pose_sequence:return
		sequence=v.pose_sequence
		if not rows.has(key):rows[key]={"samples":0,"floor_m":0.,"scale_error":0.,"planted_speed_m_s":0.,"leg_angle_deg":0.,"hip_target_error_m":0.,"correction_clamps":0,"last_clamps":v.correction_clamps,"trajectory":[]}
		var row: Dictionary=rows[key]
		row.samples+=1
		row.correction_clamps+=maxi(0,v.correction_clamps-row.last_clamps);row.last_clamps=v.correction_clamps
		row.hip_target_error_m=maxf(row.hip_target_error_m,absf(v.skeleton.get_bone_pose_position(v.hips).y-v._target_pose(v.hips).origin.y))
		var q: Array=[]
		for i in v.skeleton.get_bone_count():
			row.scale_error=maxf(row.scale_error,(v.skeleton.get_bone_pose_scale(i)-Vector3.ONE).length())
		for side in 2:
			var bone: int=[v.leg_left,v.leg_right][side]
			q.append(v.skeleton.get_bone_pose_rotation(bone))
			row.floor_m=maxf(row.floor_m,-v.last_sole[side].y)
			if not reset_pending and previous.size()==2:
				row.leg_angle_deg=maxf(row.leg_angle_deg,rad_to_deg(q[side].angle_to(previous[side])))
				if v.foot_support[side] and last_support[side] and last_ids[side]==v.contact_ids[side] and not v.settling:
					row.planted_speed_m_s=maxf(row.planted_speed_m_s,v.last_sole[side].distance_to(last_sole[side])/v.pose_delta)
		previous=q;last_sole=v.last_sole.duplicate();last_ids=v.contact_ids.duplicate()
		last_support=[v.foot_support[0] and not v.settling,v.foot_support[1] and not v.settling];reset_pending=false
		row.trajectory.append([lab.actor.position.x,lab.actor.position.y,lab.actor.position.z,v.gait_phase,lab.actor.jump_state,v.gait_run_weight])

func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append({"check":message,"passed":ok})
	if not ok:failures.append(message);push_error(message)
func ticks(seconds: float, label: String) -> void:
	scene.section=label
	var end:=Engine.get_physics_frames()+int(round(seconds*60))
	while Engine.get_physics_frames()<end:await process_frame
func at_phase(target: float) -> void:
	var v=scene.actor.visual
	var limit:=Engine.get_physics_frames()+90
	var tolerance: float=v.gait_frequency/float(fps)*.55+.004
	while absf(wrapf(v.gait_phase-target,-.5,.5))>tolerance and Engine.get_physics_frames()<limit:await process_frame
func fixture(candidate: bool, run_input: bool, key: String) -> void:
	monitor.key="";monitor.reset_pending=true
	scene._button("Reset")
	scene.actor.scripted_input=true
	scene.actor.visual.set_run_recovery(candidate)
	scene.actor.requested_direction=Vector2.DOWN;scene.actor.requested_run=run_input
	await ticks(.85,"Settle fixture")
	monitor.key=key
	review_key=key
func run() -> void:
	if "--fps60" in OS.get_cmdline_user_args():fps=60
	Engine.physics_ticks_per_second=60
	scene=load("res://scenes/dev/SnappyLocomotionFastJumpTest.tscn").instantiate();root.add_child(scene);current_scene=scene
	await process_frame
	monitor=PoseMonitor.new();monitor.lab=scene;monitor.process_priority=200;root.add_child(monitor)
	var a=scene.actor;var v=a.visual
	check(a.jump_height==2. and a.jump_flight_speed==2.15,"Existing jump physics unchanged")
	check(scene.camera.size==11.25,"Existing gameplay camera unchanged")
	check(not v.animation_player.is_playing() and not v.bounce_enabled,"One pose writer; no independent vertical bounce")
	for candidate in [false,true]:
		for index in 16:
			var phase:=index/16.
			var prefix:="%s_phase%02d"%["candidate" if candidate else "baseline",index]
			await fixture(candidate,false,prefix+"_handoff")
			await at_phase(phase)
			var before: Vector3=a.position
			a.requested_run=true
			await ticks(.05,"Walk to Run")
			check(a.position.distance_to(before)>.05,prefix+" immediate Walk→Run movement")
			await ticks(.70,"Stable full Run")
			check(v.gait_run_weight>.999,prefix+" full Run reached")
			await at_phase(phase)
			a.requested_run=false
			await ticks(.70,"Run to Walk")
			check(v.gait_run_weight<.001,prefix+" full Walk reached")
			a.requested_direction=Vector2.ZERO
			await ticks(.75,"Stop and replant")
			check(not v.settling and v.last_sole[0].y<.002 and v.last_sole[1].y<.002,prefix+" stop finishes both foot replants")
			await fixture(candidate,true,prefix+"_reverse")
			await at_phase(phase)
			var old_velocity: Vector3=a.velocity
			a.requested_direction=Vector2.UP
			await ticks(.05,"Reversal input")
			check(a.velocity.dot(Vector3(0,0,-1))>old_velocity.dot(Vector3(0,0,-1))+.1,prefix+" reversal begins decelerating before visual facing")
			await ticks(.65,"Reversal release")
			await fixture(candidate,true,prefix+"_jump")
			await at_phase(phase)
			var start_phase: float=v.gait_phase
			var jumps: int=a.jump_count
			a.request_jump()
			await ticks(.04,"Run jump request")
			check(a.jump_state!="GROUND",prefix+" jump request accepted promptly")
			var end:=Engine.get_physics_frames()+144
			var peak:=0.;var air:=false;var land:=false
			while Engine.get_physics_frames()<end:
				await process_frame
				peak=maxf(peak,a.position.y-a.floor_y);air=air or a.jump_state=="AIR";land=land or a.jump_state=="LAND"
			check(a.jump_count==jumps+1 and air and land and a.jump_state=="GROUND",prefix+" Run→Jump→Landing→Run completes once")
			check(peak>1.85 and peak<2.1,prefix+" unchanged2m jump apex")
			check(v.move_requested and v.gait_run_weight>.999,prefix+" continued input returns to full Run")
			results[prefix]={"requested_phase":phase,"jump_request_phase":start_phase,"peak_m":peak}
		await fixture(candidate,true,("candidate" if candidate else "baseline")+"_steady")
		await ticks(2.,"Stable Run")
		check(absf(a.current_speed-5.977875)<.04,"Original Run travel speed preserved")
		check(absf(v.gait_frequency-a.current_speed/(2.5*17/30.*1.2*sqrt(1.15))*.75)<.001,"Current75% cadence preserved")
	# Exercise live A/B at both support sides without resetting physics or phase.
	monitor.key="live_AB"
	for phase in [.08,.31,.58,.81]:
		await at_phase(phase)
		var old_phase: float=v.gait_phase
		var old_position: Vector3=a.position
		var anchors: Array=v.foot_anchors.duplicate()
		var ids: Array=v.contact_ids.duplicate()
		v.set_run_recovery(not v.run_recovery_enabled)
		check(v.gait_phase==old_phase and a.position==old_position and anchors==v.foot_anchors and ids==v.contact_ids,"Live Run A/B preserves phase, input and support caches")
		await ticks(.4,"Live A/B settle")
	for key in monitor.rows:
		var row: Dictionary=monitor.rows[key]
		check(row.floor_m<.002,key+" no floor penetration")
		check(row.scale_error<.00001,key+" rigid limb scale")
		check(row.planted_speed_m_s<.05,key+" planted sole stays stable")
		if key.begins_with("candidate"):
			var control: Dictionary=monitor.rows[key.replace("candidate","baseline")]
			check(row.leg_angle_deg<=maxf(60.,control.leg_angle_deg+5.),key+" no new leg pop beyond baseline/60degree guard")
			check(row.correction_clamps<=control.correction_clamps,key+" no additional correction clamps")
			if key.ends_with("steady"):check(row.hip_target_error_m<.00001,key+" approved hip rebound preserved")
	var out:="res://.validation/run_snappy_leg_recovery_v001"
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out+"/focused%d.json"%fps,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"phase_results":results,"final_pose_measurements":monitor.rows,"render_fps":fps,"physics_fps":60},"\t"))
	print("RUN_RECOVERY_FOCUSED ",checks.size()," FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
