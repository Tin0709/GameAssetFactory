extends SceneTree
## Source-derived configuration stays external. Test actual full-rig pose seams.
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func error(a:Transform3D,b:Transform3D)->float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize()->void:call_deferred("run")
func run()->void:
	var actor=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
	var a=actor.new();var oracle=actor.new();root.add_child(a);root.add_child(oracle)
	a.set_physics_process(false);oracle.set_physics_process(false)
	a.set_body_stability(false);a.set_locomotion_direction_adapter(false)
	var config:Dictionary=a.runtime_locomotion_profile.combat.handoffs
	check(a.has_method("read_combat_handoffs"),"Optional private montage handoff configuration has a validated reader")
	if a.has_method("read_combat_handoffs"):
		check(not a.call("read_combat_handoffs",config).is_empty(),"Valid external handoff profile is accepted")
		for field:String in ["blend_in_seconds","curve","composite_seam","schema"]:
			var bad:Dictionary=config.duplicate(true);bad[field]=null
			check(a.call("read_combat_handoffs",bad).is_empty(),"Malformed optional field fails closed: "+field)
		for invalid:Variant in [-1.,0.,NAN,INF,true,"bad",3.]:
			var bad:Dictionary=config.duplicate(true);bad.blend_in_seconds=invalid
			check(a.call("read_combat_handoffs",bad).is_empty(),"Invalid handoff seconds rejected: "+str(invalid))
	var trials:Array=[]
	for hz in [30,60,120]:
		for strike in 3:
			a.reset_actor();a._grounded=true;a._animate(.1);a.combo._start_attack(strike);a._animate(0.)
			check(absf(a.source_transition.duration-float(config.blend_in_seconds))<.000001,"Montage entry uses independent wall time at strike%d/%dHz"%[strike+1,hz])
			a._animate(float(config.blend_in_seconds)*.25)
			check(absf(a.source_transition.incoming_weight-.25)<.000001,"Montage entry weight advances linearly in wall time independently of strike rate")
			var w:Dictionary=a.combo.native_windows[strike]
			# Follow the real unqueued attack through its exact segment boundary.
			while a.combo.phase==&"attack":a._animate(minf(1./hz,a.combo.boundary_seconds()))
			a._animate(1./hz)
			check(a.combo.phase==&"recovery","Unqueued strike enters recovery")
			var key:String=a.combo.clip();oracle.review_loop=false;oracle.review(key)
			oracle.animation_player.seek(a.animation_player.current_animation_position,true)
			var worst:=0.;var points:Dictionary={}
			for bone in a.skeleton.get_bone_count():worst=maxf(worst,error(a.skeleton.get_bone_pose(bone),oracle.skeleton.get_bone_pose(bone)))
			for name:String in ["J_Hip","J_L_Foot","J_R_Foot","J_R_Weapon"]:
				var bone:int=a.skeleton.find_bone(name)
				check(bone>=0,"Measured contact/grip/pelvis point exists: "+name)
				if bone>=0:points[name]=a.skeleton.get_bone_global_pose(bone).origin.distance_to(oracle.skeleton.get_bone_global_pose(bone).origin)
			check(worst<.00002,"Continuous composite seam preserves all32 incoming source bones at strike%d/%dHz"%[strike+1,hz])
			trials.append({"hz":hz,"strike":strike+1,"source_seconds":a.animation_player.current_animation_position,"max_local_pose_error":worst,"point_error_metres":points,"handoff_duration":a.source_transition.duration})
			# Moving continuation keeps the leg gait layer while the upper body
			# follows the uninterrupted recovery source. No extra whole-body blend.
			a.reset_actor();a._grounded=true;a.current_speed=7.;a._move_requested=true;a._run_requested=true;a.combo._start_attack(strike)
			while a.combo.phase==&"attack":a._animate(minf(1./hz,a.combo.boundary_seconds()))
			a._animate(1./hz);oracle.review(a.combo.clip());oracle.animation_player.seek(a.animation_player.current_animation_position,true)
			var gait:Array=a.source_gait.compose(a._gait_resume_phase,7.);var moving_error:=0.
			for bone in a.skeleton.get_bone_count():
				var expected:Transform3D=gait[bone] if bone in a.combat_legs.bones else oracle.skeleton.get_bone_pose(bone)
				moving_error=maxf(moving_error,error(a.skeleton.get_bone_pose(bone),expected))
			check(moving_error<.00002 and a.combat_legs.weight==1.,"Moving composite seam preserves source upper body and common-phase leg layer")
	# Opt-out must retain the previous fallback, with exact raw-review timing.
	if a.get("combat_handoffs")!=null:
		a.combat_handoffs={};a.reset_actor();a._grounded=true;a._animate(.1);a.combo._start_attack(0);a._animate(0.)
		check(a.source_transition.duration>0.,"Absent optional settings retain legacy montage entry")
	a.review_loop=false;a.review("Attack1");a._animate(.123)
	check(absf(a.animation_player.current_animation_position-.123)<.000001,"Raw approved source review retains1x timing")
	var report:={"checks":checks,"failures":failures,"trials":trials,"scope":"All-bone composite parity with unchanged imported source, not native full-rig/contact equivalence."}
	var folder:String=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/runtime_locomotion/compiled_logic/behavior")
	DirAccess.make_dir_recursive_absolute(folder);FileAccess.open(folder.path_join("pose-seams.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_COMBAT_HANDOFFS ",JSON.stringify({"checks":checks,"failures":failures}));a.free();oracle.free();quit(0 if failures.is_empty() else 1)
