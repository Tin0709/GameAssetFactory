extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func error(a:Transform3D,b:Transform3D)->float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize()->void:call_deferred("run")
func run()->void:
	var script=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
	var a=script.new();var oracle=script.new();root.add_child(a);root.add_child(oracle);a.set_physics_process(false);oracle.set_physics_process(false)
	a.set_body_stability(false);a.set_locomotion_direction_adapter(false)
	check(a.combat_legs!=null and a.combat_legs.bones.size()>2,"Only explicit native leg branches and descendants are layered")
	for hz in [30,60,120]:
		for index in 3:
			a.reset_actor();a._grounded=true;a.current_speed=7.;a._move_requested=true;a._run_requested=true;a.combo._start_attack(index)
			var w:Dictionary=a.combo.native_windows[index]
			for i in ceili((float(w.resume)/float(w.rate)+.10)*hz):a._animate(1./hz)
			var key:String=a.active_clip;var source_time:float=a.animation_player.current_animation_position
			oracle.review_loop=false;oracle.review(key);oracle.animation_player.seek(source_time,true)
			var upper_error:=0.;var leg_error:=0.;var pose:Array=a.source_gait.compose(a._gait_resume_phase,7.)
			for bone in a.skeleton.get_bone_count():
				if bone in a.combat_legs.bones:leg_error=maxf(leg_error,error(a.skeleton.get_bone_pose(bone),pose[bone]))
				else:upper_error=maxf(upper_error,error(a.skeleton.get_bone_pose(bone),oracle.skeleton.get_bone_pose(bone)))
			check(upper_error<.00002,"Unchanged source upper body/weapon/face during moving strike%d at%dHz"%[index+1,hz])
			check(leg_error<.00002 and a.combat_legs.weight==1.,"Leg layer equals phase-synchronized gait after bounded handoff%d at%dHz"%[index+1,hz])
			# Review, jump and interruption must discard every prior overlay cache.
			a.review_loop=false;a.review("JumpTakeoff");a._animate(.173);oracle.review("JumpTakeoff");oracle.animation_player.seek(.173,true)
			var worst:=0.
			for bone in a.skeleton.get_bone_count():worst=maxf(worst,error(a.skeleton.get_bone_pose(bone),oracle.skeleton.get_bone_pose(bone)))
			check(worst<.00002 and a.combat_legs.weight==0.,"Review/air clears combat leg transforms including constant channels at%dHz"%hz)
	# Fail closed on bad optional configuration without replacing legacy actions.
	var config:Dictionary=a.runtime_locomotion_profile.combat.duplicate(true);config.windows[1].resume=NAN
	check(not a.combo.configure_native(config) and not a.combo.native_enabled,"Malformed nonfinite event profile cannot enable movement policy")
	config=a.runtime_locomotion_profile.combat.duplicate(true);config.windows[2].attack_source="wrong"
	check(not a.combo.configure_native(config),"Native timing cannot silently bind a different finisher")
	var original_action:String=a.clips.Attack1.action;var original_count:int=a.clips.size()
	config=a.runtime_locomotion_profile.combat.duplicate(true);config.additional_clips[0].semantic="Attack1"
	a._load_private_combat_clips(config)
	check(a.clips.Attack1.action==original_action and a.clips.size()==original_count,"Rejected optional profile cannot overwrite an approved semantic/action")
	print("SABRE_NATIVE_COMBAT_POSE ",JSON.stringify({"checks":checks,"failures":failures}));a.free();oracle.free();quit(0 if failures.is_empty() else 1)
