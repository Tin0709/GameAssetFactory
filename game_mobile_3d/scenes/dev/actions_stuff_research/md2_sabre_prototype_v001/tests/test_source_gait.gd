extends SceneTree
var failures:Array[String]=[]
var checks:=0
var events:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var script=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
	var a=script.new();var oracle=script.new();root.add_child(a);root.add_child(oracle);a.set_physics_process(false);oracle.set_physics_process(false)
	a.set_body_stability(false);a.set_locomotion_direction_adapter(false);a._grounded=true;a._move_requested=true;a._run_requested=true;a.current_speed=7.
	var config:Dictionary=a.runtime_locomotion_profile.gait_blend
	var period:float=config.normal_period_predicted
	a._gait_cycles_this_tick=0.;a._animate(period)
	check(absf(a._gait_cycles_this_tick-1.)<.00001,"Normal7m/s completes one observed native gait cycle in529.63ms, not346.67ms")
	check(a.get("source_gait")!=null,"Actual source gait composer is active")
	if a.get("source_gait")!=null:
		var helper=a.source_gait
		var state:Dictionary=helper.state(7.)
		check(absf(state.weight-7./9.)<.000001 and state.left=="Walk" and state.right=="Run","Recovered normal input maps to2/9Walk+7/9Run")
		check(absf(state.period-period)<.000001,"Weighted source period agrees with native measured phase")
		# At sample anchors the sampler must match direct AnimationPlayer poses,
		# including source channels optimized away at rest on all32bones.
		for key:String in ["Idle","Walk","Run"]:
			for phase:float in [0.,.083,.371,.613,.937]:
				var poses:Array=helper.sample(key,phase)
				oracle.review_loop=false;oracle.review(key);oracle.animation_player.seek(float(oracle.clips[key].duration)*phase,true)
				var worst:=0.
				for bone in a.skeleton.get_bone_count():
					var expected:Transform3D=oracle.skeleton.get_bone_pose(bone);var actual:Transform3D=poses[bone]
					worst=maxf(worst,maxf(expected.origin.distance_to(actual.origin),maxf(expected.basis.x.distance_to(actual.basis.x),maxf(expected.basis.y.distance_to(actual.basis.y),expected.basis.z.distance_to(actual.basis.z)))))
				if worst>=.00002:
					for bone in a.skeleton.get_bone_count():
						var e:Transform3D=oracle.skeleton.get_bone_pose(bone);var v:Transform3D=poses[bone]
						if e.origin.distance_to(v.origin)>.00002 or e.basis.x.distance_to(v.basis.x)>.00002 or e.basis.y.distance_to(v.basis.y)>.00002 or e.basis.z.distance_to(v.basis.z)>.00002:print("SAMPLER_DIAGNOSTIC ",key," ",phase," ",a.skeleton.get_bone_name(bone)," error=",worst," expected=",e," sampled=",v)
				check(worst<.00002,"All-bone source sampling parity "+key+" phase "+str(phase))
		for hz in [30,60,120]:
			a.reset_actor();a._grounded=true;a._move_requested=true;a._run_requested=true;a.current_speed=7.;a._gait_cycles_this_tick=0.
			for i in hz:a._animate(1./hz)
			check(absf(a._gait_cycles_this_tick-1./period)<.00001,"Cadence remains native across physics rates "+str(hz))
			a.review("Run");a._animate(.123);check(absf(a.animation_player.current_animation_position-.123)<.00001,"Raw1x source review bypasses composer "+str(hz))
		for speed:float in [0.,.02,.2,2.,7.]:
			a.reset_actor();a._grounded=true;a._move_requested=true;a._run_requested=false;a.current_speed=speed
			for i in 18:a._animate(1./120.)
			var reference:Array=helper.compose(a.animation_player.current_animation_position/float(a.clips.Walk.duration),speed)
			var worst:=0.
			for bone in a.skeleton.get_bone_count():
				var e:Transform3D=reference[bone];var v:Transform3D=a.skeleton.get_bone_pose(bone)
				worst=maxf(worst,maxf(e.origin.distance_to(v.origin),maxf(e.basis.x.distance_to(v.basis.x),maxf(e.basis.y.distance_to(v.basis.y),e.basis.z.distance_to(v.basis.z)))))
			check(worst<.00002,"Composed handoff completes on wall time even at low/blocked speed "+str(speed))
		a.source_locomotion_event.connect(func(notify:String,clip:String,source_seconds:float,simulation_seconds:float):events.append({"name":notify,"clip":clip,"source":source_seconds,"at":simulation_seconds}))
		a.reset_actor();a._grounded=true;a._move_requested=true;a._run_requested=true;a.current_speed=7.;a._animate(period)
		var expected:Array=a.runtime_locomotion_profile.locomotion_events[a.clips.Run.source_name].events
		check(events.size()==expected.size(),"Normal blend uses dominant Run notifications once per common cycle")
		for i in mini(events.size(),expected.size()):
			check(events[i].clip=="Run" and absf(events[i].at-float(expected[i].time)/float(a.clips.Run.duration)*period)<.00001,"Native-phase event time follows shared cycle "+str(i))
		a.runtime_locomotion_profile.gait_blend.erase("normal_phase_hz_observed")
		var minimal_report:Variant=a.movement_measurements()
		check(minimal_report is Dictionary and minimal_report.has("speed") and minimal_report.get("native_normal_phase_hz_observed")==null and not minimal_report.get("native_normal_gait_phase_verified",true),"Missing optional observational metadata stays safe and does not claim verification")
	print("SABRE_SOURCE_GAIT ",JSON.stringify({"checks":checks,"failures":failures}));a.free();oracle.free();quit(0 if failures.is_empty() else 1)
