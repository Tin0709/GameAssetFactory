extends SceneTree
## Real-time stress inputs; never play the saved Blender 28-second take.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok and not failures.has(label):failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
	var actor=scene.player;var v=actor.visual
	check("direction_snapshot" in v,"Source directional controller must drive this existing scene")
	if not "direction_snapshot" in v:scene.free();quit(1);return
	actor.set_physics_process(false);v.set_process(false);actor.scripted_input=true
	var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
	var dt:=1./fps;var minimum:=INF;var max_step:=0.;var phase:=0.;var phase_start: float=v.direction_snapshot.phase
	var previous: Array[Quaternion]=[];var maximum_scale:=1.;var side_seen:=false;var back_seen:=false
	var raw_time_usec:=0;var samples:=0;var final_source_phase:=0.;var steady_support_samples:=0
	for i in int(24./dt):
		var t:=i*dt;var direction:=Vector2.ZERO
		var run:=t>=10. and t<21.
		if t<3.:direction=Vector2(0,-1)
		elif t<9. or (t>=12. and t<18.):
			var hold:=.2 if fmod(t,6.)<2. else (.1 if fmod(t,6.)<4. else .05)
			direction=[Vector2(0,-1),Vector2(1,0),Vector2(0,1),Vector2(-1,0)][int(t/hold)%4]
		elif t<12. or (t>=18. and t<20.):direction=Vector2(sin(t*TAU),-cos(t*TAU))
		elif t<21.:direction=Vector2(0,-1 if int(t/.15)%2 else 1)
		var desired: Vector2=direction*(actor.run_speed if run else actor.walk_speed)
		var planar:=Vector2(actor.velocity.x,actor.velocity.z).move_toward(desired,(actor.deceleration if direction.is_zero_approx() else actor.acceleration)*dt)
		actor.velocity=Vector3(planar.x,0,planar.y);actor.position+=actor.velocity*dt;actor.current_speed=planar.length()
		var before:=Time.get_ticks_usec()
		v.drive_locomotion(actor.velocity,not direction.is_zero_approx(),dt);v._evaluate(dt)
		raw_time_usec+=Time.get_ticks_usec()-before;samples+=1
		var now: float=v.direction_snapshot.phase
		check(now+1e-10>=phase,"Changing input never resets the shared source clock");phase=now;final_source_phase=now
		var variables: Dictionary=v.direction_snapshot.vars
		side_seen=side_seen or absf(variables["v.mrmeib"])>.1
		back_seen=back_seen or variables["v.cknrcn"]<-.1
		var current: Array[Quaternion]=[]
		for side in 2:
			var bone: int=[v.leg_left,v.leg_right][side]
			var q: Quaternion=v._leg_world_rotation(bone);current.append(q)
			if previous.size()==2:max_step=maxf(max_step,rad_to_deg(q.angle_to(previous[side])))
			minimum=minf(minimum,v._sole_world(bone).y)
			maximum_scale=maxf(maximum_scale,v.skeleton.get_bone_pose_scale(bone).y)
			check(v.skeleton.get_bone_pose_position(bone).is_finite() and q.is_finite(),"No nonfinite directional pose")
			if t>1. and t<2.5 and v.foot_support[side]:steady_support_samples+=1
		previous=current
	check(side_seen and back_seen,"Side/back clips receive real-time direction weights")
	check(final_source_phase>phase_start+10.,"Clock advances over many live-input cycles")
	check(minimum>-.003,"Directional feet stay above ground: "+str(minimum))
	check(max_step<65.,"No extreme displayed leg spin/reset: "+str(max_step))
	check(maximum_scale>1.02,"Directional Run retains authored leg scale")
	check(steady_support_samples>0,"Grounded forward gait retains support contacts")
	check(not v.move_requested and not v.settling,"Release settles naturally into Idle")
	var life: float=v.entity_lifetime;var phase_before_reset: float=v.direction_snapshot.phase
	scene.reset_player();check(v.entity_lifetime==life and v.direction_snapshot.phase==phase_before_reset,"R does not reset source time or phase")
	var report={"fps":fps,"failures":failures,"minimum_foot_y":minimum,"max_world_leg_step_deg":max_step,"maximum_scale":maximum_scale,"final_phase":final_source_phase,"side_and_back_used":side_seen and back_seen,"support_samples":steady_support_samples,"average_pose_and_controller_ms":raw_time_usec/float(samples)/1000.}
	FileAccess.open("user://actions_stuff_direction_gameplay_"+str(fps)+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DIRECTION_GAMEPLAY ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
