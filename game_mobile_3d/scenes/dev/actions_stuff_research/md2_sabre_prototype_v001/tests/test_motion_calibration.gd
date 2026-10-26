extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func tick()->void:await physics_frame;await process_frame
func run()->void:
	var floor:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.4,100);collision.shape=box;collision.position.y=-.2;floor.add_child(collision);root.add_child(floor)
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a)
	check(a.using_original_source,"Calibration uses original source profile")
	check(absf(a.walk_speed-2.)<.00001 and absf(a.run_speed-7.)<.00001,"Public table baseline is separate from unchanged source stride references")
	check(absf(a.gravity-38.4)<.00001,"Responsive jump gravity is a declared adapter, not native MD2 data")
	if not failures.is_empty():a.free();floor.free();quit(1);return
	var reports:Array[Dictionary]=[]
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();await tick();await tick();await tick()
		var start:float=a.simulation_clock;var peak:=-1.;var apex:=0.;var flight:=0.
		Input.action_press("jump");await tick();Input.action_release("jump")
		for i in hz*2:
			if a.global_position.y>peak:peak=a.global_position.y;apex=a.simulation_clock-start
			if a.is_on_floor():flight=a.simulation_clock-start;break
			await tick()
		check(absf(peak-1.2)<.012,"Estimated1.2-unit apex retained at "+str(hz))
		check(absf(apex-.25)<=1./hz+.001,"Physical apex follows explicit250ms adapter independently of source Takeoff duration at "+str(hz))
		check(absf(flight-.5)<=2./hz+.001,"Physical flight matches faster500ms adapter at "+str(hz))
		var ground_drift:=0.
		for i in 15:await tick();ground_drift=maxf(ground_drift,absf(a.global_position.y))
		check(ground_drift<.001 and a.is_on_floor(),"Ground contact remains stable after landing at "+str(hz))
		Input.action_press("move_forward")
		for i in 12:await tick()
		var cruise_rate:float=a._playback_speed;var cruise_speed:float=a.current_speed
		Input.action_release("move_forward");Input.action_release("sprint")
		var idle_while_moving:=false;var braking_run:=false;var idle_seen:=false;var idle_position:=Vector3.ZERO;var idle_slide:=0.
		for i in 20:
			await tick()
			if a.current_speed>.1:
				idle_while_moving=idle_while_moving or a.active_clip in ["Idle","CombatReady"]
				braking_run=braking_run or a.active_clip in ["Run","CombatRun"]
			if a.active_clip=="Idle":
				if not idle_seen:idle_position=a.global_position;idle_seen=true
				idle_slide=maxf(idle_slide,a.global_position.distance_to(idle_position))
		check(braking_run and not idle_while_moving and idle_slide<.01,"Run brakes in gait before stationary Idle at "+str(hz))
		reports.append({"hz":hz,"height":peak,"apex_seconds":apex,"flight_seconds":flight,"ground_drift":ground_drift,"run_cruise_rate":cruise_rate,"run_cruise_speed":cruise_speed})
	a.set_physics_process(false);a.reset_actor();a._grounded=true;a._move_requested=true
	a._play("CombatWalk",0.);a.animation_player.seek(float(a.clips.CombatWalk.duration)*.37,true);a.skeleton.force_update_all_bone_transforms()
	var leg:int=a.skeleton.find_bone("J_L_Leg")
	var before:Transform3D=a.skeleton.get_bone_global_pose(leg)
	for key:String in ["CombatStrafeLeft","CombatWalk","CombatStrafeRight","CombatWalk"]:
		a._play(key);a.skeleton.force_update_all_bone_transforms()
		check(absf(a.animation_player.current_animation_position/float(a.clips[key].duration)-.37)<.00001,"Locomotion alias preserves normalized phase: "+key)
		check(a.skeleton.get_bone_global_pose(leg).is_equal_approx(before),"Identical source alias has no leg-pose reset: "+key)
	a._play("Run");check(absf(a.animation_player.current_animation_position/float(a.clips.Run.duration)-.37)<.00001,"Walk-to-Run preserves normalized cycle")
	a.combat_requested=true;a._run_requested=true;a.velocity=Vector3(5.6,0,0);a.visual.rotation.y=0.
	check(a._select_clip()=="CombatRun","Lateral source sprint uses Run cadence rather than Walk alias")
	a._run_requested=false;a.current_speed=2.
	for hz in [30,60]:
		a.resume_gameplay();a.active_clip="";a._play("CombatWalk",0.);var expected:=0.;var worst:=0.
		for i in 24:
			a.velocity=[Vector3(0,0,2),Vector3(2,0,0),Vector3(-2,0,0)][i%3]
			a._animate(1./hz);expected=fposmod(expected+1./hz/float(a.clips.CombatWalk.duration),1.)
			var actual:float=a.animation_player.current_animation_position/float(a.clips[a.active_clip].duration)
			worst=maxf(worst,absf(wrapf(actual-expected,-.5,.5)))
		check(worst<.00001,"Repeated CombatWalk/Strafe classification retains stride phase at "+str(hz))
	a.review("Walk");a._animate(float(a.clips.Walk.duration)*.75)
	check(absf(a.animation_player.current_animation_position/float(a.clips.Walk.duration)-.75)<.00001,"Review remains original1x")
	var report:={"checks":checks,"failures":failures,"physics":reports,"profile":"public table700 baseline; distance/stride cadence adapter; native runtime/jump config unverified"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.validation/md2_sabre_prototype_v001"));FileAccess.open("res://.validation/md2_sabre_prototype_v001/motion-calibration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_MOTION_CALIBRATION ",JSON.stringify(report));a.free();floor.free();quit(0 if failures.is_empty() else 1)
