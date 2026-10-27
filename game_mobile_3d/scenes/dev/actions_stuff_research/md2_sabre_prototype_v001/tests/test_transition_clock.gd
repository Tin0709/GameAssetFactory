extends SceneTree
## Regression: cadence scaling must not also stretch/freeze pose handoff time.
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func error(a:Transform3D,b:Transform3D)->float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize()->void:call_deferred("run")
func run()->void:
	var script=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd")
	var a=script.new();var oracle=script.new();root.add_child(a);root.add_child(oracle)
	a.set_physics_process(false);oracle.set_physics_process(false)
	# Isolate the prior wall-clock handoff regression from gait composition;
	# test_source_gait additionally checks composed handoffs at these speeds.
	a.set_native_gait_enabled(false)
	a.set_body_stability(false);a.set_locomotion_direction_adapter(false)
	var trials:Array=[]
	for hz in [30,60,120]:
		for speed:float in [0.,.02,.2,2.,7.]:
			a.reset_actor();a._grounded=true;a._move_requested=true;a._run_requested=false;a.current_speed=speed
			for i in int(ceil(.15*hz)):a._animate(1./hz)
			oracle.review_loop=false;oracle.review("Walk");oracle.animation_player.play(oracle.clips.Walk.action,0.);oracle.animation_player.advance(0.);oracle.animation_player.seek(a.animation_player.current_animation_position,true);oracle.skeleton.force_update_all_bone_transforms()
			var worst:=0.
			for bone in a.skeleton.get_bone_count():worst=maxf(worst,error(a.skeleton.get_bone_pose(bone),oracle.skeleton.get_bone_pose(bone)))
			check(worst<.0001,"Wall-clock handoff is complete even at low/blocked cadence: "+str(hz)+" Hz, "+str(speed)+" u/s")
			trials.append({"hz":hz,"speed":speed,"raw_pose_error_after_150ms":worst,"source_clock":a.animation_player.current_animation_position})
	# Interruption before a handoff finishes must begin at the current shown pose.
	a.reset_actor();a._grounded=true;a._move_requested=true;a._run_requested=false;a.current_speed=.2;a._animate(1./120.)
	var held:Array[Transform3D]=[]
	for bone in a.skeleton.get_bone_count():held.append(a.skeleton.get_bone_pose(bone))
	a._play("Run")
	var interrupt_error:=0.
	for bone in a.skeleton.get_bone_count():interrupt_error=maxf(interrupt_error,error(held[bone],a.skeleton.get_bone_pose(bone)))
	check(interrupt_error<.0001,"Interrupted handoff preserves its displayed starting pose")
	# All source keys/timing remain independently reviewable at exact1x.
	a.review_loop=false;a.review("Run");a._animate(.123)
	check(absf(a.animation_player.current_animation_position-.123)<.000001,"Raw Run review clock remains1x")
	var report:={"checks":checks,"failures":failures,"trials":trials,"interruption_error":interrupt_error}
	var folder:String=a.private_model_path().get_base_dir().get_base_dir().get_base_dir().path_join("reports/prototype_sabre/movement_measurements/contract_audit")
	DirAccess.make_dir_recursive_absolute(folder);FileAccess.open(folder.path_join("transition-clock.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SABRE_TRANSITION_CLOCK ",JSON.stringify(report));a.free();oracle.free();quit(0 if failures.is_empty() else 1)
