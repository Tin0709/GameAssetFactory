extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate()
	lab.md2_sabre_prototype_enabled=true;lab.grass_field_blocks=80;root.add_child(lab)
	await physics_frame;await process_frame
	var a=lab.player
	check(a.get("hybrid_motion")!=null,"Selected private hybrid motion is installed on existing Valorie actor")
	if not failures.is_empty():lab.free();quit(1);return
	check(a.using_original_source and a.skeleton.get_bone_count()==32,"Original Valorie32-bone skin preserved")
	check(absf(a.run_speed-7.)<.00001,"Existing7m/s physics preserved")
	for key in ["Attack1","Attack2","Attack3","AirAttack"]:check(not a.clips[key].action.begins_with("hybrid/"),"MD2 combat source remains "+key)
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second=hz;a.reset_actor();a.scripted_input=true
		await ticks(3)
		a.requested_direction=Vector2.UP;a.requested_run=true
		await ticks(hz)
		check(a.current_speed>6.99,"Physical running speed at "+str(hz))
		check(a.hybrid_motion.last_kind=="Run","A&S Run supplies final base pose at "+str(hz))
		check(a.hybrid_motion.phase>0. and a.hybrid_motion.phase<1.,"Continuous hybrid gait phase at "+str(hz))
		a.requested_run=false;await ticks(hz)
		check(a.hybrid_motion.last_kind=="Walk","A&S Walk supplies final base pose at "+str(hz))
		a.requested_jump=true;await ticks(1);a.requested_jump=false
		var peak:float=a.global_position.y;var saw_landing:=false
		for i in hz*2:
			await ticks(1);peak=maxf(peak,a.global_position.y)
			if a._jump_stage=="JumpLanding":saw_landing=true
		check(peak>.9 and saw_landing and a.is_on_floor(),"Collision-owned hybrid jump/landing at "+str(hz))
		check(a.hybrid_motion.landing_samples>int(.5*hz),"Moving bounce is not cut off by old50ms landing release at "+str(hz))
		a.attack(true);await ticks(hz*2);a.attack(false);await ticks(hz)
		check(a.accepted_count>=3,"Native MD2 combo still chains at "+str(hz))
		check(a.skeleton.get_bone_global_pose(a.skeleton.find_bone("J_Head")).is_finite(),"Composed head remains finite at "+str(hz))
		a.requested_direction=Vector2.ZERO;await ticks(hz)
		check(a.current_speed<.001 and a.combo.phase==&"ready","Stops and recovers at "+str(hz))
	print("HYBRID_MOTION ",JSON.stringify({"checks":checks,"failures":failures}));lab.free();quit(0 if failures.is_empty()else 1)
func ticks(count:int)->void:
	for i in count:await physics_frame
	await process_frame
