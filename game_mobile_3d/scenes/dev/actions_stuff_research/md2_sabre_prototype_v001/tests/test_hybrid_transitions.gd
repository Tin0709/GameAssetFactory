extends SceneTree
var checks:=0
var failures:Array[String]=[]
var rows:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var Facing=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/smooth_facing.gd")
	for hz in [30,60,120]:
		var helper=Facing.new();var dt:=1./hz;var angle:=0.;var deltas:Array=[]
		for i in hz:
			var next:float=helper.step(angle,PI*.5,dt,100.);deltas.append(next-angle)
			check(next>=angle-.000001 and next<=PI*.5+.000001,"Facing approaches90deg without overshoot "+str(hz));angle=next
		check(absf(angle-PI*.5)<.00001 and float(deltas[0])<float(deltas.max()),"Facing accelerates then settles instead of immediate fixed-rate snap "+str(hz))
		helper.reset(deg_to_rad(170.));angle=deg_to_rad(170.)
		for i in hz:
			var next:float=helper.step(angle,deg_to_rad(-170.),dt,6.);check(absf(next-angle)<=6.*dt+.000001,"Yaw rate bounded across angle wrap "+str(hz));angle=next
		check(absf(wrapf(angle-deg_to_rad(-170.),-PI,PI))<.0001,"Shortest-path wrap settles "+str(hz))
	var a=load("res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/actor.gd").new();root.add_child(a);a.set_physics_process(false)
	check(a.hybrid_motion!=null,"Actual32bone actor has hybrid helper")
	if a.hybrid_motion==null:finish(a);return
	a._grounded=true;a._move_requested=true;a._run_requested=true;a.current_speed=7.;a.velocity=Vector3(0,0,7);a._jump_stage="JumpLanding";a._jump_time=.18
	a.hybrid_motion.run_weight=1.;var torso:Array[Quaternion]=[]
	for phase:float in [0.,.25,.5,.75]:
		a.hybrid_motion.phase=phase;a.hybrid_motion.apply(a,"JumpLanding",0.)
		torso.append(a.skeleton.get_bone_global_pose(a.skeleton.find_bone("J_Shoulders")).basis.get_rotation_quaternion())
	var spread:=0.
	for q in torso:spread=maxf(spread,q.angle_to(torso[0]))
	check(spread>.03,"Moving landing retains live gait torso motion at the SAME contact age, not a static body")
	rows.append({"moving_landing_torso_phase_difference_rad":spread})
	for hz in [30,60,120]:
		a.reset_actor();a._grounded=false;a._move_requested=false;a.current_speed=0.;a.hybrid_motion.keep_shoulders_attached()
		var previous:Dictionary={};var biggest_contact_step:=0.;var dt:=1./hz
		for i in ceili(.8*hz):
			var t:=i*dt;var key:String="JumpTakeoff" if t<.25 else ("JumpAirborne" if t<.5 else "JumpLanding")
			a._jump_stage=key;a._jump_time=t if key=="JumpTakeoff" else (t-.25 if key=="JumpAirborne" else t-.5);a._grounded=t>=.5;a.velocity.y=9.6-38.4*t if t<.5 else 0.
			a.animation_player.play(a.clips[key].action,0.);a.animation_player.seek(a._jump_time,true)
			a.hybrid_motion.apply(a,key,dt);a.hybrid_motion.keep_shoulders_attached()
			var chest:=a.skeleton.find_bone("J_Shoulders");var inv:=a.skeleton.get_bone_global_pose(chest).affine_inverse()
			for side in ["L","R"]:
				var bone:=a.skeleton.find_bone("J_"+side+"_Arm");var q:Quaternion=(inv*a.skeleton.get_bone_global_pose(bone)).basis.get_rotation_quaternion()
				if t>=.5 and t<=.7 and previous.has(side):biggest_contact_step=maxf(biggest_contact_step,Quaternion(previous[side]).angle_to(q))
				previous[side]=q
		check(biggest_contact_step<.65,"Stationary arm contact has no instantaneous close/reopen snap "+str(hz))
		rows.append({"hz":hz,"largest_contact_arm_step_rad":biggest_contact_step})
	finish(a)
func finish(a)->void:
	var report:={"checks":checks,"failures":failures,"measurements":rows};print("HYBRID_TRANSITIONS ",JSON.stringify(report))
	var research:=OS.get_environment("MD2_RESEARCH_ROOT")
	if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
	FileAccess.open(research.path_join("blender/hybrid_godot_v001/transition_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	a.free();quit(0 if failures.is_empty() else 1)
